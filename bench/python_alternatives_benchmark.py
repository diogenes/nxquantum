#!/usr/bin/env python3
"""
Cross-framework local benchmark and its correctness checks (H1.3 Track A).

Lanes: NxQuantum (via bench/nxquantum_python_comparison.exs), Qiskit
quantum_info.Statevector, PennyLane default.qubit, cirq.Simulator.

Everything scenario-shaped comes from bench/scenarios/python_alternatives.json
(ids, warmup/iteration counts, tolerances, thread counts, fixed circuits) and
bench/scenarios/python_alternatives_fixture.json (angle sets). Unknown scenario
ids raise.

Modes (--mode):
  check     correctness first: agreement of every lane against the NumPy
            complex128 reference, ZZ pair checks, exact-rational sampled check.
            Timings are produced but flagged as not published.
  timed     same pipeline with the table counts. REFUSES while the table says
            "tolerances_confirmed": false.
  pretime   times ONE untimed iteration per (lane, family, width) and writes it
            (budget rule R4).
  pins      queries `pip index versions` for qiskit, pennylane, cirq-core and numpy and
            compares the latest with the committed pins; prints a pins_current line.
  consensus --results A/results.json B/results.json ...: RF9 per-width f64 consensus
            across per-invocation results files (one lane per invocation); fails when
            qiskit, pennylane or cirq_c128_equivalence is missing for a width with rows.
  selfcheck reference self-checks: dense reference (<=6q), prefix-parity analytic
            identity, f64 consensus, exact-rational sampled counts; or
            --compare-values A B for byte identity of two value files.

Always run as:  .venv-bench/bin/python -I bench/python_alternatives_benchmark.py ...
"""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import platform
import resource
import shlex
import subprocess
import sys
import tempfile
import time
from fractions import Fraction
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TABLE_PATH = ROOT / "bench" / "scenarios" / "python_alternatives.json"
THREAD_VARS = ("OMP_NUM_THREADS", "OPENBLAS_NUM_THREADS", "MKL_NUM_THREADS", "VECLIB_MAXIMUM_THREADS")
NX_SCRIPT = "bench/nxquantum_python_comparison.exs"
REQUIREMENTS = ROOT / "bench" / "requirements-python-alternatives.txt"
PREFIX_PARITY_MIN_ABS = 0.5
DEFAULT_MAX_QUBITS = 8
CPU_WALL_LABEL_ABOVE = 1.1
SAMPLED_HELPER_DTYPE = "float64 Python helper (no framework API)"
INF = float("inf")


def _pin_threads() -> None:
    """Fix BLAS thread counts before NumPy is imported (re-exec once if they differ)."""
    threads = json.loads(TABLE_PATH.read_text())["threads"]
    wanted = {name: str(threads[name]) for name in THREAD_VARS}
    if any(os.environ.get(name) != value for name, value in wanted.items()):
        env = dict(os.environ)
        env.update(wanted)
        os.execve(sys.executable, [sys.executable, "-I", *sys.argv], env)


if __name__ == "__main__":
    if not sys.flags.isolated:
        raise SystemExit("run with `.venv-bench/bin/python -I` (isolated mode is part of the protocol)")
    _pin_threads()

import numpy as np  # noqa: E402  (must follow _pin_threads)

# --------------------------------------------------------------------------------------
# Table, fixture, scenario lookup
# --------------------------------------------------------------------------------------


def load_table() -> dict:
    return json.loads(TABLE_PATH.read_text())


def load_fixture(table: dict):
    data = (ROOT / table["fixture"]["path"]).read_bytes()
    expected = (ROOT / table["fixture"]["sha256_path"]).read_text().split()[0]
    actual = hashlib.sha256(data).hexdigest()
    if actual != expected:
        raise RuntimeError(f"fixture sha256 mismatch: file={actual} committed={expected}")
    return json.loads(data), actual


def scenario_or_raise(table: dict, scenario_id: str) -> dict:
    scenarios = table["scenarios"]
    if scenario_id not in scenarios:
        raise KeyError(f"unknown scenario id {scenario_id!r}; known ids: {sorted(scenarios)}")
    return scenarios[scenario_id]


def tolerance_for(table: dict, scenario: dict, lane: str):
    """Tolerance for (scenario, lane); None means ungated."""
    if "tolerance_ref" in scenario:
        family, width = scenario["tolerance_ref"]
        return table["tolerances"][family][width][lane]
    return scenario["tolerance"][lane]


# --------------------------------------------------------------------------------------
# Circuits (shared structure with the Elixir side; both read the same table/fixture)
# --------------------------------------------------------------------------------------


def brickwork(layer: int, qubits: int):
    return [("cnot", i, i + 1) for i in range(layer % 2, qubits - 1, 2)]


def family_gates(family: str, qubits: int, ks, layers: int, denominator: int = 1024):
    angles = [k / denominator for k in ks]
    gates = []
    if family == "real":
        gates += [("h", w) for w in range(qubits)]
        for layer in range(layers):
            gates += [("ry", w, angles[layer * qubits + w]) for w in range(qubits)]
            gates += brickwork(layer, qubits)
    else:
        for layer in range(layers):
            base = layer * 2 * qubits
            gates += [("rx", w, angles[base + w]) for w in range(qubits)]
            gates += [("rz", w, angles[base + qubits + w]) for w in range(qubits)]
            gates += brickwork(layer, qubits)
    return gates


def prefix_parity_gates(family: str, qubits: int, entry: dict, denominator: int = 1024):
    theta = [k / denominator for k in entry["theta_k"]]
    gates = []
    if family == "real":
        gates += [("ry", w, theta[w]) for w in range(qubits)]
    else:
        phi = [k / denominator for k in entry["phi_k"]]
        gates += [("rx", w, theta[w]) for w in range(qubits)]
        gates += [("rz", w, phi[w]) for w in range(qubits)]
    gates += [("cnot", j, j + 1) for j in range(qubits - 1)]
    return gates


def prefix_parity_expected(entry: dict, denominator: int = 1024):
    out, product = [], 1.0
    for k in entry["theta_k"]:
        product *= float(np.cos(k / denominator))
        out.append(product)
    return out


def observables_for(scenario: dict):
    if scenario["kind"] == "family":
        return [("Z", w) for w in range(scenario["qubits"])]
    return [(axis, wire) for axis, wire in scenario["observables"]]


def sparse_terms(scenario: dict):
    spec = scenario["terms"]
    max_mask = (1 << scenario["qubits"]) - 1
    terms = []
    for index in range(spec["count"]):
        z_mask = ((index * spec["mask_multiplier"]) % max_mask) + 1
        magnitude = spec["magnitude_step"] * ((index % spec["magnitude_cycle"]) + 1)
        terms.append((z_mask, magnitude if index % 2 == 0 else -magnitude))
    return terms


def sampled_masks(scenario: dict):
    """Z masks per reported value for sampled scenarios (wire w -> bit w)."""
    if scenario["kind"] == "sampled_z_wires":
        return [1 << wire for _axis, wire in scenario["observables"]]
    return None


# --------------------------------------------------------------------------------------
# NumPy complex128 reference simulator (wire 0 = most significant bit)
# --------------------------------------------------------------------------------------

_H = np.array([[1, 1], [1, -1]], dtype=np.complex128) / np.sqrt(2.0)
_Y = np.array([[0, -1j], [1j, 0]], dtype=np.complex128)


def _gate_matrix(name: str, angle=None):
    if name == "h":
        return _H
    c, s = np.cos(angle / 2.0), np.sin(angle / 2.0)
    if name == "rx":
        return np.array([[c, -1j * s], [-1j * s, c]], dtype=np.complex128)
    if name == "ry":
        return np.array([[c, -s], [s, c]], dtype=np.complex128)
    if name == "rz":
        return np.array([[np.exp(-1j * angle / 2.0), 0], [0, np.exp(1j * angle / 2.0)]], dtype=np.complex128)
    raise ValueError(f"unsupported gate {name!r}")


def _apply_1q(psi, matrix, wire):
    out = np.tensordot(matrix, psi, axes=([1], [wire]))
    return np.ascontiguousarray(np.moveaxis(out, 0, wire))


def _apply_cnot(psi, control, target):
    out = np.array(psi, copy=True)
    index = [slice(None)] * psi.ndim
    index[control] = 1
    sub = psi[tuple(index)]
    axis = target if target < control else target - 1
    out[tuple(index)] = np.flip(sub, axis=axis)
    return out


def ref_state(qubits: int, gates) -> np.ndarray:
    psi = np.zeros((2,) * qubits, dtype=np.complex128)
    psi[(0,) * qubits] = 1.0
    for gate in gates:
        if gate[0] == "cnot":
            psi = _apply_cnot(psi, gate[1], gate[2])
        elif gate[0] == "h":
            psi = _apply_1q(psi, _H, gate[1])
        else:
            psi = _apply_1q(psi, _gate_matrix(gate[0], gate[2]), gate[1])
    return psi


def ref_expectations(psi: np.ndarray, observables) -> list[float]:
    probs = None
    values = []
    for axis, wire in observables:
        if axis == "Z":
            if probs is None:
                probs = np.abs(psi) ** 2
            values.append(float(np.take(probs, 0, axis=wire).sum() - np.take(probs, 1, axis=wire).sum()))
        elif axis == "X":
            values.append(float(np.vdot(psi, np.flip(psi, axis=wire)).real))
        elif axis == "Y":
            values.append(float(np.vdot(psi, _apply_1q(psi, _Y, wire)).real))
        else:
            raise ValueError(f"unsupported observable {axis!r}")
    return values


def ref_zz(psi: np.ndarray, a: int, b: int) -> float:
    probs = np.abs(psi) ** 2
    table = np.moveaxis(probs, (a, b), (0, 1)).reshape(2, 2, -1).sum(axis=2)
    return float(table[0, 0] - table[0, 1] - table[1, 0] + table[1, 1])


# --------------------------------------------------------------------------------------
# Sampled-counts helpers and exact reference
# --------------------------------------------------------------------------------------


def _popcount(value: int) -> int:
    count = 0
    while value:
        value &= value - 1
        count += 1
    return count


def counts_entries(counts: dict[str, int]):
    entries, shots = [], 0
    for bitstring, count in counts.items():
        entries.append((int(bitstring, 2), count))
        shots += count
    return entries, float(shots)


def z_mask_expectation(entries, shots: float, z_mask: int) -> float:
    signed = 0.0
    for value, count in entries:
        signed += (-1.0 if _popcount(value & z_mask) & 1 else 1.0) * count
    return signed / shots


def sparse_sum(entries, shots, terms) -> float:
    lookup, total = {}, 0.0
    for z_mask, coeff in terms:
        if z_mask not in lookup:
            lookup[z_mask] = z_mask_expectation(entries, shots, z_mask)
        total += coeff * lookup[z_mask]
    return total


def qiskit_label_from_z_mask(qubits: int, z_mask: int) -> str:
    chars = ["I"] * qubits
    for wire in range(qubits):
        if (z_mask >> wire) & 1:
            chars[wire] = "Z"
    return "".join(chars)[::-1]


def exact_sampled_reference(scenario: dict) -> list[Fraction]:
    """Exact rational value(s) for a sampled scenario (floats enter as exact binary fractions)."""
    counts = {int(bits, 2): count for bits, count in scenario["counts"].items()}
    shots = sum(counts.values())

    def mask_value(mask: int) -> Fraction:
        signed = sum((-1 if _popcount(v & mask) & 1 else 1) * c for v, c in counts.items())
        return Fraction(signed, shots)

    if scenario["kind"] == "sampled_sparse":
        total = Fraction(0)
        for mask, coeff in sparse_terms(scenario):
            total += Fraction(coeff) * mask_value(mask)
        return [total]
    return [mask_value(mask) for mask in sampled_masks(scenario)]


# --------------------------------------------------------------------------------------
# Python framework lanes
# --------------------------------------------------------------------------------------


def _qiskit_label(qubits: int, wire: int, axis: str) -> str:
    chars = ["I"] * qubits
    chars[wire] = axis
    return "".join(chars)[::-1]  # Qiskit labels are little-endian


def _state_expectations(qubits, observables):
    """Timed region of the state-reuse scenario for PennyLane and Cirq: the NumPy reference helper
    on an already simulated state (wire 0 is axis 0 in both frameworks)."""
    shape = (2,) * qubits
    return lambda state: ref_expectations(np.asarray(state).reshape(shape), observables)


class QiskitLane:
    name = "qiskit"

    def build(self, qubits, gates, observables=None):
        from qiskit import QuantumCircuit

        circuit = QuantumCircuit(qubits)
        for gate in gates:
            if gate[0] == "cnot":
                circuit.cx(gate[1], gate[2])
            elif gate[0] == "h":
                circuit.h(gate[1])
            else:
                getattr(circuit, gate[0])(gate[2], gate[1])
        return circuit

    def runner(self, qubits, observables):
        from qiskit.quantum_info import Pauli, Statevector

        paulis = [Pauli(_qiskit_label(qubits, wire, axis)) for axis, wire in observables]

        def run(circuit):
            state = Statevector.from_instruction(circuit)
            return [float(state.expectation_value(p).real) for p in paulis]

        return run

    def state_reuse_runner(self, qubits, observables, gate_sets):
        """Statevector.from_instruction once per distinct circuit, untimed; timed: expectation_value per Pauli."""
        from qiskit.quantum_info import Pauli, Statevector

        paulis = [Pauli(_qiskit_label(qubits, wire, axis)) for axis, wire in observables]
        states, tokens = {}, []
        for gates in gate_sets:
            if id(gates) not in states:
                states[id(gates)] = Statevector.from_instruction(self.build(qubits, gates))
            tokens.append(states[id(gates)])
        return (lambda state: [float(state.expectation_value(p).real) for p in paulis]), tokens

    def sampled_runner(self, scenario):
        from qiskit.quantum_info import Pauli, SparsePauliOp
        from qiskit.result import sampled_expectation_value

        counts, qubits = scenario["counts"], scenario["qubits"]
        if scenario["kind"] == "sampled_sparse":
            terms = sparse_terms(scenario)
            operator = SparsePauliOp(
                [qiskit_label_from_z_mask(qubits, m) for m, _ in terms], coeffs=[c for _, c in terms]
            )
            return lambda _tok: [float(sampled_expectation_value(counts, operator))]
        paulis = [Pauli(qiskit_label_from_z_mask(qubits, m)) for m in sampled_masks(scenario)]
        return lambda _tok: [float(sampled_expectation_value(counts, p)) for p in paulis]


class PennyLaneLane:
    name = "pennylane"

    def build(self, qubits, gates, observables=None):
        """A QuantumScript built before the timed loop (no QNode); `observables=None` builds state-only ops."""
        import pennylane as qml

        ops = []
        for gate in gates:
            if gate[0] == "cnot":
                ops.append(qml.CNOT(wires=[gate[1], gate[2]]))
            elif gate[0] == "h":
                ops.append(qml.Hadamard(wires=gate[1]))
            else:
                ops.append({"rx": qml.RX, "ry": qml.RY, "rz": qml.RZ}[gate[0]](gate[2], wires=gate[1]))
        make = {"X": qml.PauliX, "Y": qml.PauliY, "Z": qml.PauliZ}
        measurements = [qml.state()] if observables is None else [
            qml.expval(make[axis](wires=wire)) for axis, wire in observables]
        return qml.tape.QuantumScript(ops, measurements)

    def runner(self, qubits, observables):
        import pennylane as qml

        device = qml.device("default.qubit", wires=qubits)
        single = len(observables) == 1

        def run(tape):
            result = qml.execute([tape], device, cache=False)[0]
            if single and not isinstance(result, (tuple, list)):
                result = (result,)
            return [float(v) for v in result]

        return run

    def state_reuse_runner(self, qubits, observables, gate_sets):
        """State from qml.execute(qml.state()) (complex128) once, untimed; timed: the NumPy helper on it."""
        import pennylane as qml

        device = qml.device("default.qubit", wires=qubits)
        states, tokens = {}, []
        for gates in gate_sets:
            if id(gates) not in states:
                tape = self.build(qubits, gates, None)
                states[id(gates)] = np.asarray(qml.execute([tape], device, cache=False)[0])
            tokens.append(states[id(gates)])
        return _state_expectations(qubits, observables), tokens

    def sampled_runner(self, scenario):
        counts = scenario["counts"]
        if scenario["kind"] == "sampled_sparse":
            terms = sparse_terms(scenario)

            def run(_tok):
                entries, shots = counts_entries(counts)
                return [sparse_sum(entries, shots, terms)]

            return run
        masks = sampled_masks(scenario)

        def run_wires(_tok):
            entries, shots = counts_entries(counts)
            return [z_mask_expectation(entries, shots, m) for m in masks]

        return run_wires


class CirqLane:
    def __init__(self, name="cirq_c64", dtype=None):
        self.name = name
        self.dtype = dtype  # None = cirq.Simulator() default (complex64)

    def _simulator(self):
        import cirq

        return cirq.Simulator() if self.dtype is None else cirq.Simulator(dtype=self.dtype)

    def build(self, qubits, gates, observables=None):
        import cirq

        q = cirq.LineQubit.range(qubits)
        ops = []
        for gate in gates:
            if gate[0] == "cnot":
                ops.append(cirq.CNOT(q[gate[1]], q[gate[2]]))
            elif gate[0] == "h":
                ops.append(cirq.H(q[gate[1]]))
            else:
                ops.append({"rx": cirq.rx, "ry": cirq.ry, "rz": cirq.rz}[gate[0]](gate[2])(q[gate[1]]))
        return cirq.Circuit(ops)

    def runner(self, qubits, observables):
        import cirq

        q = cirq.LineQubit.range(qubits)
        make = {"X": cirq.X, "Y": cirq.Y, "Z": cirq.Z}
        obs = [make[axis](q[wire]) for axis, wire in observables]
        simulator = self._simulator()

        def run(circuit):
            return [float(v.real) for v in simulator.simulate_expectation_values(circuit, observables=obs)]

        return run

    def state_reuse_runner(self, qubits, observables, gate_sets):
        """final_state_vector once per distinct circuit, untimed (dtype of this lane); timed: the NumPy helper."""
        simulator = self._simulator()
        states, tokens = {}, []
        for gates in gate_sets:
            if id(gates) not in states:
                states[id(gates)] = simulator.simulate(self.build(qubits, gates)).final_state_vector
            tokens.append(states[id(gates)])
        return _state_expectations(qubits, observables), tokens

    def sampled_runner(self, scenario):
        return PennyLaneLane().sampled_runner(scenario)  # same pure-Python helper, no framework API


PY_LANES = {
    "qiskit": lambda: QiskitLane(),
    "pennylane": lambda: PennyLaneLane(),
    "cirq_c64": lambda: CirqLane("cirq_c64", None),
    "cirq_c128_equivalence": lambda: CirqLane("cirq_c128_equivalence", np.complex128),
}

# --------------------------------------------------------------------------------------
# Timed loop
# --------------------------------------------------------------------------------------


def time_runner(runner, tokens, warmup: int):
    """Untimed warmup over tokens[:warmup], then per-iteration timing over the rest."""
    for token in tokens[:warmup]:
        runner(token)
    values, times_ms = [], []
    for token in tokens[warmup:]:
        start = time.perf_counter_ns()
        value = runner(token)
        stop = time.perf_counter_ns()
        times_ms.append((stop - start) / 1.0e6)
        values.append(value)
    return values, times_ms


def untimed_values(runner, tokens, warmup: int):
    return [runner(token) for token in tokens[warmup:]]


# --------------------------------------------------------------------------------------
# Scenario preparation
# --------------------------------------------------------------------------------------


class Prepared:
    def __init__(self, sid, scenario, cache_mode, warmup, iterations, gate_sets, observables):
        self.sid = sid
        self.scenario = scenario
        self.kind = scenario["kind"]
        self.qubits = scenario["qubits"]
        self.cache_mode = cache_mode
        self.warmup = warmup
        self.iterations = iterations
        self.gate_sets = gate_sets  # one entry per warmup+timed iteration (None for sampled)
        self.observables = observables

    @property
    def total(self):
        return self.warmup + self.iterations

    @property
    def label(self):
        if self.kind == "family":
            return f"{self.scenario['family']}_{self.qubits}"
        return self.sid


def prepare(table, fixture, sid, cache_mode, warmup=None, iterations=None) -> Prepared:
    scenario = scenario_or_raise(table, sid)
    if cache_mode not in scenario["cache_modes"]:
        raise ValueError(f"scenario {sid} does not allow cache mode {cache_mode!r}; allowed: {scenario['cache_modes']}")
    if cache_mode == "hot" and scenario["qubits"] > 10:
        raise ValueError("hot rows are published only at 10 qubits or fewer (state_vector.ex:101)")

    warmup = scenario["warmup"] if warmup is None else warmup
    iterations = scenario["iterations"] if iterations is None else iterations
    total = warmup + iterations
    kind = scenario["kind"]

    if kind == "family":
        family, qubits = scenario["family"], scenario["qubits"]
        entry = fixture["families"][family]["widths"][str(qubits)]
        if total > entry["sets"]:
            raise ValueError(f"{sid}: need {total} angle sets, fixture has {entry['sets']}")
        if cache_mode == "hot":
            one = family_gates(family, qubits, entry["k"][0], fixture["layers"])
            gate_sets = [one] * total
        else:
            gate_sets = [family_gates(family, qubits, entry["k"][i], fixture["layers"]) for i in range(total)]
    elif kind == "fixed":
        one = [tuple(g) for g in scenario["gates"]]
        gate_sets = [one] * total
    else:
        gate_sets = [None] * total

    observables = None if kind in ("sampled_sparse",) else observables_for(scenario)
    return Prepared(sid, scenario, cache_mode, warmup, iterations, gate_sets, observables)


def reference_values(prep: Prepared):
    """Per timed iteration reference values (floats, or Fractions for sampled scenarios)."""
    if prep.kind.startswith("sampled"):
        exact = exact_sampled_reference(prep.scenario)
        return [exact] * prep.iterations
    cache = {}
    out = []
    for gates in prep.gate_sets[prep.warmup :]:
        key = id(gates)
        if key not in cache:
            cache[key] = ref_expectations(ref_state(prep.qubits, gates), prep.observables)
        out.append(cache[key])
    return out


def abs_error(got, ref) -> float:
    """|got - ref|, or inf if got is not a finite real number (NaN never compares as a pass)."""
    try:
        value = float(got)
    except (TypeError, ValueError):
        return INF
    if not math.isfinite(value):
        return INF
    err = float(abs(Fraction(value) - ref)) if isinstance(ref, Fraction) else abs(value - ref)
    return err if math.isfinite(err) else INF


def worse(current: float, candidate: float) -> float:
    """NaN-safe running maximum: a NaN or infinite candidate makes the result inf."""
    if not math.isfinite(candidate):
        return INF
    return max(current, candidate)


def max_error(values, refs) -> float:
    """Largest |value - reference| over all rows; inf when the two do not agree in shape.

    inf covers a missing or extra row, a row of the wrong length, nothing to compare, and any
    value that is not finite (NaN included), so none of these can pass a gate.
    """
    if len(values) != len(refs) or len(refs) == 0:
        return INF
    worst = 0.0
    for got_row, ref_row in zip(values, refs):
        if len(got_row) != len(ref_row) or len(ref_row) == 0:
            return INF
        for got, ref in zip(got_row, ref_row):
            worst = worse(worst, abs_error(got, ref))
            if worst == INF:
                return INF
    return worst


def vec_error(got, ref) -> float:
    return max_error([list(got)], [list(ref)])


def array_error(got, ref) -> float:
    got, ref = np.asarray(got), np.asarray(ref)
    if got.shape != ref.shape or not np.all(np.isfinite(got)):
        return INF
    return float(np.max(np.abs(got - ref))) if got.size else INF


def verdict(max_err: float, tolerance):
    if tolerance is None:
        return "ungated"
    return "pass" if (math.isfinite(max_err) and max_err <= tolerance) else "fail"


def discrimination(refs, tolerance):
    """(max |ref|, observables whose |ref| stays >= 10 * tolerance in every iteration, observables)."""
    if not refs:
        return None, None, 0
    floats = [[float(v) for v in row] for row in refs]
    count = len(floats[0])
    biggest = max(abs(v) for row in floats for v in row)
    if tolerance is None:
        return biggest, None, count
    strong = sum(1 for j in range(count) if min(abs(row[j]) for row in floats) >= 10.0 * tolerance)
    return biggest, strong, count


# --------------------------------------------------------------------------------------
# NxQuantum lane (subprocess; the .exs prints one line per iteration)
# --------------------------------------------------------------------------------------


def child_env(table: dict) -> dict:
    env = dict(os.environ)
    threads = table["threads"]
    for name in THREAD_VARS:
        env[name] = str(threads[name])
    schedulers = threads["beam_schedulers"]
    env["ELIXIR_ERL_OPTIONS"] = f"+S {schedulers}:{schedulers}"
    return env


def run_nx(args, table, argv_tail):
    cmd = [*shlex.split(args.mix_cmd), "run", NX_SCRIPT, *argv_tail]
    completed = subprocess.run(cmd, cwd=args.repo_root, env=child_env(table), capture_output=True, text=True)
    if completed.returncode != 0:
        raise RuntimeError(f"NxQuantum script failed ({completed.returncode}): {' '.join(cmd)}\n{completed.stdout}\n{completed.stderr}")
    return completed.stdout


def _fields(line: str) -> dict:
    out = {}
    for chunk in line.split()[1:]:
        key, value = chunk.split("=", 1)
        out[key] = value
    return out


def parse_nx(stdout: str) -> dict:
    bench, iters, zz = None, {}, {}
    for line in stdout.splitlines():
        if line.startswith("NXQ_BENCH "):
            bench = _fields(line)
        elif line.startswith("NXQ_ITER "):
            f = _fields(line)
            iters[int(f["i"])] = (float(f["ms"]), [float(v) for v in f["values"].split(",")] if f["values"] else [])
        elif line.startswith("NXQ_ZZ "):
            f = _fields(line)
            zz[f["pair"]] = float(f["value"])
    if bench is None:
        raise RuntimeError(f"could not parse NxQuantum output: {stdout!r}")
    ordered = [iters[i] for i in sorted(iters)]
    return {
        "bench": bench,
        "times_ms": [t for t, _ in ordered],
        "values": [v for _, v in ordered],
        "zz": zz,
    }


def nx_args(args, prep: Prepared, lane_cfg: dict, mode: str, zz: bool):
    tail = [
        "--mode", mode,
        "--scenario", prep.sid,
        "--profile", lane_cfg["runtime_profile"],
        "--cache-mode", prep.cache_mode,
        "--warmup", str(prep.warmup),
        "--iterations", str(prep.iterations),
    ]
    if zz:
        tail.append("--zz")
    return tail


# --------------------------------------------------------------------------------------
# Lane execution for one (scenario, cache mode)
# --------------------------------------------------------------------------------------


def run_python_lane(lane_id: str, prep: Prepared, timed: bool):
    lane = PY_LANES[lane_id]()
    if prep.kind.startswith("sampled"):
        runner = lane.sampled_runner(prep.scenario)
        tokens = [None] * prep.total
    elif prep.scenario.get("state_reuse"):
        runner, tokens = lane.state_reuse_runner(prep.qubits, prep.observables, prep.gate_sets)
    else:
        runner = lane.runner(prep.qubits, prep.observables)
        built = {}
        tokens = []
        for gates in prep.gate_sets:  # built before the timed loop, one per iteration
            if id(gates) not in built:
                built[id(gates)] = lane.build(prep.qubits, gates, prep.observables)
            tokens.append(built[id(gates)])
    if timed:
        values, times = time_runner(runner, tokens, prep.warmup)
    else:
        values, times = untimed_values(runner, tokens, prep.warmup), []
    return {"values": values, "times_ms": times, "lane_obj": lane}


def python_zz(lane_id: str, prep: Prepared, fixture):
    """ZZ via CNOT(a,b) . Z_b . CNOT(a,b) on the first angle set, untimed."""
    if prep.kind != "family":
        return {}
    lane = PY_LANES[lane_id]()
    entry = fixture["families"][prep.scenario["family"]]["widths"][str(prep.qubits)]
    out = {}
    for a, b in entry["zz_pairs"]:
        observables = [("Z", b)]
        runner = lane.runner(prep.qubits, observables)
        out[f"{a},{b}"] = runner(lane.build(prep.qubits, prep.gate_sets[0] + [("cnot", a, b)], observables))[0]
    return out


def zz_reference(prep: Prepared, fixture):
    if prep.kind != "family":
        return {}
    entry = fixture["families"][prep.scenario["family"]]["widths"][str(prep.qubits)]
    psi = ref_state(prep.qubits, prep.gate_sets[0])
    return {f"{a},{b}": ref_zz(psi, a, b) for a, b in entry["zz_pairs"]}


def lane_enabled_for(table, lane_id, prep: Prepared, timed_mode: bool):
    lane_cfg = table["lanes"][lane_id]
    scenario = prep.scenario
    if lane_cfg["framework"] == "nxquantum" and scenario.get("nx_public_api") is False:
        return False, "not run (no public facade; Known Gap)"
    limit = lane_cfg.get("max_timed_qubits")
    if timed_mode and limit is not None and prep.qubits > limit:
        return False, lane_cfg.get("above_limit_note", "not run (lane limit)")
    return True, None


def cpu_seconds(who) -> float:
    usage = resource.getrusage(who)
    return usage.ru_utime + usage.ru_stime


def one_line(text: str, limit: int = 300) -> str:
    flat = " ".join(str(text).split())
    return flat if len(flat) <= limit else flat[: limit - 3] + "..."


def execute_lane(args, table, fixture, lane_id, lane_cfg, prep, zz_ref, timed_mode):
    """Run one lane on one prepared scenario. Returns values, times, zz values, extra row fields."""
    if lane_cfg["framework"] == "nxquantum":
        tail = nx_args(args, prep, lane_cfg, "timed" if timed_mode else "values", zz_ref != {})
        out = parse_nx(run_nx(args, table, tail))
        threads = table["threads"]
        seen = {k: out["bench"].get(k) for k in ("schedulers", "max_concurrency", "dirty_cpu_schedulers")}
        want = {"schedulers": str(threads["beam_schedulers"]), "max_concurrency": str(threads["max_concurrency"]),
                "dirty_cpu_schedulers": str(threads["beam_schedulers"])}
        if seen != want:
            raise RuntimeError(f"NxQuantum ran with {seen}, the table wants {want}")
        bench = out["bench"]
        extra = {"resolved_profile": bench.get("resolved_profile"), "nx_flags": bench.get("flags"),
                 "timed_loop_cpu_ms": float(bench["timed_loop_cpu_ms"]),
                 "timed_loop_wall_ms": float(bench["timed_loop_wall_ms"]),
                 "cpu_wall_timed_loop": float(bench["timed_loop_cpu_wall"])}
        return out["values"], out["times_ms"], out["zz"], extra
    out = run_python_lane(lane_id, prep, timed=lane_cfg.get("timed", True))
    zz_values = python_zz(lane_id, prep, fixture) if zz_ref else {}
    return out["values"], out["times_ms"], zz_values, {}


def execute_scenario(args, table, fixture, sid, cache_mode, lanes, timed_mode, check_counts, report):
    scenario = scenario_or_raise(table, sid)
    warmup = iterations = None
    if check_counts:
        warmup, iterations = args.check_warmup, args.check_iterations
    prep = prepare(table, fixture, sid, cache_mode, warmup, iterations)
    refs = reference_values(prep)
    zz_ref = zz_reference(prep, fixture)

    rows = []
    for lane_id in lanes:
        lane_cfg = table["lanes"][lane_id]
        if not lane_cfg.get("timed", True) and prep.kind.startswith("sampled"):
            continue
        if lane_id == "cirq_c128_equivalence" and prep.kind.startswith("sampled"):
            continue
        ok, reason = lane_enabled_for(table, lane_id, prep, timed_mode)
        dtype = lane_cfg["dtype"]
        if prep.kind.startswith("sampled") and lane_id in ("pennylane", "cirq_c64"):
            dtype = SAMPLED_HELPER_DTYPE  # pure-Python counts helper, not a framework API
        row = {
            "scenario": sid, "family": scenario.get("family"), "qubits": prep.qubits, "cache_mode": cache_mode,
            "lane": lane_id, "dtype": dtype, "label": scenario.get("lane_labels", {}).get(lane_id),
            "warmup": prep.warmup, "iterations": prep.iterations, "scenario_labels": scenario.get("labels", []),
            "synthetic": scenario.get("synthetic", False),
        }
        if not ok:
            row.update(status="not_run", note=reason)
            rows.append(row)
            continue

        tolerance = tolerance_for(table, scenario, lane_id)
        who = resource.RUSAGE_CHILDREN if lane_cfg["framework"] == "nxquantum" else resource.RUSAGE_SELF
        cpu_before, started = cpu_seconds(who), time.perf_counter()
        try:
            values, times, zz_values, extra = execute_lane(args, table, fixture, lane_id, lane_cfg, prep, zz_ref, timed_mode)
            error = None
        except Exception as exc:  # noqa: BLE001  (a lane failure is a row result, not a crash)
            values, times, zz_values, extra = [], [], {}, {}
            error = f"{type(exc).__name__}: {one_line(exc)}"
        wall = time.perf_counter() - started
        cpu = cpu_seconds(who) - cpu_before
        row.update(extra)
        row["wall_s"] = wall
        row["cpu_s"] = cpu
        row["cpu_wall"] = (cpu / wall) if wall > 0 else None  # whole lane call (subprocess incl. startup for NxQuantum)
        row.setdefault("cpu_wall_timed_loop", None)  # NxQuantum rows only: timed loop, no startup
        row["cpu_wall_label"] = (
            f"cpu/wall above {CPU_WALL_LABEL_ABOVE} (not single-threaded)"
            if row["cpu_wall"] is not None and row["cpu_wall"] > CPU_WALL_LABEL_ABOVE else None)
        discrim_tol = tolerance if tolerance is not None else tolerance_for(table, scenario, "cirq_c128_equivalence")
        biggest, strong, count = discrimination(refs, discrim_tol)
        row.update(max_abs_ref=biggest, n_discriminating=strong, n_observables=count, discrimination_tolerance=discrim_tol)

        if error is not None:
            row.update(status="error", error=error, max_err=INF, tolerance=tolerance, beyond_kg10_floor=None,
                       values=[], times_ms=[], per_op_ms=None, gated=tolerance is not None)
            rows.append(row)
            report(row, prep)
            continue

        err = max_error(values, refs)
        status = verdict(err, tolerance)
        row.update(
            max_err=err, tolerance=tolerance, status=status, gated=tolerance is not None,
            beyond_kg10_floor=bool(err > 1e-6 or not math.isfinite(err)),
            values=[[repr(v) for v in rowvals] for rowvals in values],
            times_ms=times,
            per_op_ms=(sum(times) / len(times)) if times else None,
        )
        if zz_ref:
            zz_err = INF
            if zz_values and set(zz_values) == set(zz_ref):
                zz_err = 0.0
                for key, ref in zz_ref.items():
                    zz_err = worse(zz_err, abs_error(zz_values[key], ref))
            zz_status = verdict(zz_err, tolerance)
            row["zz"] = {"values": {k: repr(v) for k, v in zz_values.items()}, "max_err": zz_err, "status": zz_status}
            if zz_status == "fail" and row["status"] == "pass":
                # RF7: a failed ZZ check fails the whole row and withholds its timing
                row["status"] = "fail"
                row["fail_reason"] = "zz"
        if row["status"] == "fail":
            row.update(per_op_ms=None, times_ms=[], timing_withheld=True)
        rows.append(row)
        report(row, prep)
    return rows


def check_name(row, prep_mode=None):
    label = f"{row['family']}_{row['qubits']}" if row.get("family") else row["scenario"]
    return f"agreement_{row['lane']}_{label}" + ("_hot" if row["cache_mode"] == "hot" else "")


# --------------------------------------------------------------------------------------
# Environment block
# --------------------------------------------------------------------------------------


def pip_freeze() -> str:
    return subprocess.run([sys.executable, "-I", "-m", "pip", "freeze"], capture_output=True, text=True, check=True).stdout


def environment_lines(args, table, fixture_sha, mode):
    freeze = pip_freeze()
    committed = REQUIREMENTS.read_text()
    config = np.show_config(mode="dicts")
    blas = config.get("Build Dependencies", {}).get("blas", {})
    lines = [
        f"harness_mode: {mode}",
        f"python: {platform.python_version()} ({sys.executable})",
        f"python_flags_isolated: {bool(sys.flags.isolated)}",
        f"pip_freeze_sha256: {hashlib.sha256(freeze.encode()).hexdigest()}",
        f"pip_freeze_matches_committed: {freeze == committed}",
        f"numpy: {np.__version__}",
        f"blas: {json.dumps(blas, sort_keys=True)}",
        f"numpy_config_machine: {json.dumps(config.get('Machine Information', {}), sort_keys=True)}",
        f"fixture_sha256: {fixture_sha}",
        f"table_sha256: {hashlib.sha256(TABLE_PATH.read_bytes()).hexdigest()}",
        f"tolerances_confirmed: {table['tolerances_confirmed']}",
        "thread_counts: " + json.dumps({**{n: os.environ.get(n) for n in THREAD_VARS},
                                         "beam_schedulers": table["threads"]["beam_schedulers"],
                                         "max_concurrency": table["threads"]["max_concurrency"]}, sort_keys=True),
        "lane_dtypes: " + json.dumps({k: v["dtype"] for k, v in table["lanes"].items()}, sort_keys=True),
        f"nxquantum_child_elixir_erl_options: {child_env(table)['ELIXIR_ERL_OPTIONS']}",
        f"cpu_wall_lane_call: per row, RUSAGE_SELF delta for Python lanes and RUSAGE_CHILDREN delta for the NxQuantum "
        f"subprocess over the whole lane call (VM startup and compile included for NxQuantum); rows above {CPU_WALL_LABEL_ABOVE} are labelled",
        "cpu_wall_timed_loop: NxQuantum rows only; :erlang.statistics(:runtime) delta (process CPU across all OS threads, "
        "ms resolution) over the :timer.tc wall time of the timed loop alone (no startup)",
    ]
    for lane, text in table["disclosures"].items():
        if lane != "methods":
            lines.append(f"disclosure_{lane}: {text}")
    lines += [f"methods: {text}" for text in table["disclosures"]["methods"]]
    for pkg in ("qiskit", "pennylane", "cirq"):
        try:
            module = __import__(pkg)
            lines.append(f"{pkg}: {module.__version__}")
        except Exception as exc:  # noqa: BLE001
            lines.append(f"{pkg}: unavailable ({exc})")
    return lines


def write_environment(args, table, fixture_sha, mode, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    path = out_dir / "environment.txt"
    run_nx(args, table, ["--mode", "env", "--env-out", str(path)])
    with path.open("a") as handle:
        handle.write("\n".join(environment_lines(args, table, fixture_sha, mode)) + "\n")
    return path


# --------------------------------------------------------------------------------------
# Self-checks
# --------------------------------------------------------------------------------------


def emit(name, status, **fields):
    detail = " ".join(f"{k}={v}" for k, v in fields.items())
    print(f"CHECK name={name} status={status} {detail}".rstrip(), flush=True)
    return status


def dense_cases(table, fixture):
    cases = {}
    for family in ("real", "complex"):
        for width in ("4", "6"):
            entry = fixture["families"][family]["widths"][width]
            cases[f"{family}_{width}_set0"] = (int(width), family_gates(family, int(width), entry["k"][0], fixture["layers"]))
    for sid in ("baseline_2q", "deep_6q"):
        sc = table["scenarios"][sid]
        cases[sid] = (sc["qubits"], [tuple(g) for g in sc["gates"]])
    return cases


def selfcheck_dense(args, table, fixture):
    cases = dense_cases(table, fixture)
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp) / "dense.json"
        run_nx(args, table, ["--mode", "dense_export", "--out", str(out), "--cases", ",".join(cases)])
        exported = json.loads(out.read_text())
    worst, detail = 0.0, {}
    for name, (n, gates) in cases.items():
        psi = ref_state(n, gates)
        flat = psi.reshape(-1)
        got = exported[name]
        elixir_state = np.array(got["re"]) + 1j * np.array(got["im"])
        err_state = array_error(elixir_state, flat)
        obs = [(axis, w) for axis in ("X", "Y", "Z") for w in range(n)]
        ref_vals = ref_expectations(psi, obs)
        err_obs = vec_error(got["expectations"], ref_vals)
        detail[name] = worse(err_state, err_obs)
        worst = worse(worst, detail[name])
    bound = table["selfcheck_bounds"]["reference_selfcheck_dense_le6q"]
    return emit("reference_selfcheck_dense_le6q", "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                cases=",".join(cases)), detail


def selfcheck_prefix_parity(table, fixture, max_qubits):
    worst, detail = 0.0, {}
    min_abs = float("inf")
    for family in ("real", "complex"):
        for width, entry in fixture["prefix_parity"][family].items():
            n = int(width)
            if n > max_qubits:
                continue
            psi = ref_state(n, prefix_parity_gates(family, n, entry))
            got = ref_expectations(psi, [("Z", k) for k in range(n)])
            expected = prefix_parity_expected(entry)
            err = vec_error(got, expected)
            detail[f"{family}_{n}"] = err
            worst = worse(worst, err)
            min_abs = min(min_abs, min(abs(v) for v in expected))
    bound = table["selfcheck_bounds"]["reference_selfcheck_prefix_parity"]
    # The identity only discriminates while |expected| stays well away from 0.
    discriminates = min_abs >= PREFIX_PARITY_MIN_ABS
    ok = worst <= bound and discriminates
    return emit("reference_selfcheck_prefix_parity", "pass" if ok else "fail", max_err=repr(worst), bound=bound,
                min_abs_expected=repr(min_abs), min_abs_bound=PREFIX_PARITY_MIN_ABS, widths_max=max_qubits), detail


def selfcheck_consensus(table, fixture, max_qubits):
    """Qiskit, PennyLane and Cirq (complex128) against the NumPy reference at <= 1e-8."""
    bound = table["selfcheck_bounds"]["reference_consensus_f64"]
    cases = []
    for family in ("real", "complex"):
        for width in ("4", "8"):
            n = int(width)
            if n <= max_qubits:
                entry = fixture["families"][family]["widths"][width]
                cases.append((f"{family}_{n}_set0", n, family_gates(family, n, entry["k"][0], fixture["layers"]),
                              [("Z", w) for w in range(n)]))
                pp = fixture["prefix_parity"][family][width]
                cases.append((f"prefix_{family}_{n}", n, prefix_parity_gates(family, n, pp), [("Z", w) for w in range(n)]))
    for sid in ("deep_6q", "batch_obs_8q", "state_reuse_8q_xy"):
        sc = table["scenarios"][sid]
        if sc["qubits"] <= max_qubits:
            cases.append((sid, sc["qubits"], [tuple(g) for g in sc["gates"]], observables_for(sc)))
    worst, detail = 0.0, {}
    for name, n, gates, observables in cases:
        ref = ref_expectations(ref_state(n, gates), observables)
        for lane_id in ("qiskit", "pennylane", "cirq_c128_equivalence"):
            lane = PY_LANES[lane_id]()
            got = lane.runner(n, observables)(lane.build(n, gates, observables))
            err = vec_error(got, ref)
            detail[f"{name}:{lane_id}"] = err
            worst = worse(worst, err)
    return emit("reference_consensus_f64", "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                cases=len(cases), lanes="qiskit,pennylane,cirq_c128_equivalence"), detail


def selfcheck_sampled(args, table, nx=True):
    results, worst = {}, 0.0
    bound = table["selfcheck_bounds"]["sampled_counts_exact_rational"]
    for sid, scenario in table["scenarios"].items():
        if not scenario["kind"].startswith("sampled"):
            continue
        prep = prepare(table, None, sid, "cold", warmup=0, iterations=1)
        refs = reference_values(prep)
        lanes = ["qiskit", "pennylane", "cirq_c64"] + (["nxquantum_cpu_portable", "nxquantum_cpu_compiled"] if nx else [])
        for lane_id in lanes:
            cfg = table["lanes"][lane_id]
            ok, _ = lane_enabled_for(table, lane_id, prep, False)
            if not ok:
                continue
            if cfg["framework"] == "nxquantum":
                values = parse_nx(run_nx(args, table, nx_args(args, prep, cfg, "values", False)))["values"]
            else:
                values = run_python_lane(lane_id, prep, timed=False)["values"]
            err = max_error(values, refs)
            results[f"{sid}:{lane_id}"] = err
            worst = worse(worst, err)
    return emit("sampled_counts_exact_rational", "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                rows=len(results)), results


def selfcheck_agreement_negatives():
    """RF8: the agreement gate must fail on NaN, inf, a missing or extra row and a short row.

    Each case is built to be wrong; the check passes only if every one of them is a verdict of fail
    and the matching positive controls still pass."""
    nan = float("nan")
    tol = 1e-6
    refs = [[0.25, -0.5], [0.125, 0.75]]
    good = [[0.25, -0.5], [0.125, 0.75]]
    negatives = {
        "nan_value": max_error([[nan, -0.5], [0.125, 0.75]], refs),
        "nan_in_last_row": max_error([[0.25, -0.5], [0.125, nan]], refs),
        "inf_value": max_error([[0.25, -0.5], [0.125, INF]], refs),
        "missing_row": max_error(good[:1], refs),
        "extra_row": max_error(good + [[0.0, 0.0]], refs),
        "short_row": max_error([[0.25], [0.125, 0.75]], refs),
        "no_rows": max_error([], []),
        "non_numeric": max_error([[None, -0.5], [0.125, 0.75]], refs),
        "nan_vs_exact_fraction": max_error([[nan]], [[Fraction(1, 4)]]),
        "nan_vector": vec_error([0.0, nan], [0.0, 0.0]),
        "nan_array": array_error(np.array([0.0, nan]), np.array([0.0, 0.0])),
        "array_shape": array_error(np.zeros(3), np.zeros(4)),
    }
    positives = {
        "exact": max_error(good, refs),
        "within_tolerance": max_error([[0.25 + 5e-7, -0.5], [0.125, 0.75]], refs),
        "fraction": max_error([[0.25]], [[Fraction(1, 4)]]),
    }
    verdicts = {name: verdict(err, tol) for name, err in negatives.items()}
    controls = {name: verdict(err, tol) for name, err in positives.items()}
    running = worse(0.0, nan)
    ok = (all(v == "fail" for v in verdicts.values()) and all(v == "pass" for v in controls.values())
          and running == INF and verdict(nan, tol) == "fail" and verdict(nan, None) == "ungated")
    return emit("harness_agreement_negative_cases", "pass" if ok else "fail",
                gate_verdicts=",".join(f"{k}:{v}" for k, v in verdicts.items()),
                controls=",".join(f"{k}:{v}" for k, v in controls.items()), nan_safe_running_max=running)


def compare_values(path_a: str, path_b: str):
    a, b = Path(path_a).read_bytes(), Path(path_b).read_bytes()
    same = a == b
    return emit("values_byte_identical_runs", "pass" if same else "fail",
                sha256_a=hashlib.sha256(a).hexdigest(), sha256_b=hashlib.sha256(b).hexdigest(), bytes=len(a))


# --------------------------------------------------------------------------------------
# Modes
# --------------------------------------------------------------------------------------


def select_scenarios(args, table):
    ids = args.scenario or [sid for sid, sc in table["scenarios"].items()]
    for sid in ids:
        scenario_or_raise(table, sid)
    # The default width cap protects an unqualified run; naming a scenario is a deliberate choice.
    cap = args.max_qubits if args.max_qubits is not None else (None if args.scenario else DEFAULT_MAX_QUBITS)
    if cap is not None:
        ids = [sid for sid in ids if table["scenarios"][sid]["qubits"] <= cap]
    return ids


def select_lanes(args, table):
    names = args.lanes.split(",") if args.lanes else [l for l in table["lane_order"]]
    for name in names:
        if name not in table["lanes"]:
            raise KeyError(f"unknown lane {name!r}; known: {sorted(table['lanes'])}")
    if "cirq_c64" in names and "cirq_c128_equivalence" not in names:
        names.insert(names.index("cirq_c64") + 1, "cirq_c128_equivalence")
    return names


def modes_for(args, scenario):
    wanted = ["hot", "cold"] if args.cache_mode == "both" else [args.cache_mode]
    chosen = [m for m in wanted if m in scenario["cache_modes"]]
    if args.cache_mode != "both" and not chosen:
        raise ValueError(f"cache mode {args.cache_mode!r} not allowed for this scenario; allowed {scenario['cache_modes']}")
    return chosen


CONSENSUS_LANES = ("qiskit", "pennylane", "cirq_c128_equivalence")


def consensus_rows(table, rows) -> int:
    """RF9: per (family, width) max error of the qiskit, pennylane and cirq_c128_equivalence rows, bound 1e-8.

    Emitted only when all three lanes produced a row for that width. Returns the number of failures."""
    bound = table["selfcheck_bounds"]["reference_consensus_f64"]
    groups: dict = {}
    for row in rows:
        if row["status"] == "not_run" or row["lane"] not in CONSENSUS_LANES or not row.get("family"):
            continue
        groups.setdefault((row["family"], row["qubits"]), {}).setdefault(row["lane"], []).append(row["max_err"])
    failed = 0
    for (family, qubits), by_lane in sorted(groups.items(), key=lambda kv: (kv[0][0], kv[0][1])):
        if set(by_lane) != set(CONSENSUS_LANES):
            continue
        worst = 0.0
        for errs in by_lane.values():
            for err in errs:
                worst = worse(worst, err)
        status = emit(f"reference_consensus_f64_{family}_{qubits}", "pass" if worst <= bound else "fail",
                      max_err=repr(worst), bound=bound, lanes=",".join(CONSENSUS_LANES))
        failed += status == "fail"
    return failed


def consensus_across(table, rows):
    """Strict RF9 variant for merged per-invocation rows: fail when any of the three lanes is missing for a width."""
    bound = table["selfcheck_bounds"]["reference_consensus_f64"]
    groups: dict = {}
    for row in rows:
        if row.get("status") == "not_run" or row.get("lane") not in CONSENSUS_LANES or not row.get("family"):
            continue
        groups.setdefault((row["family"], row["qubits"]), {}).setdefault(row["lane"], []).append(row["max_err"])
    failed = 0
    for (family, qubits), by_lane in sorted(groups.items()):
        name = f"reference_consensus_f64_{family}_{qubits}"
        missing = [lane for lane in CONSENSUS_LANES if lane not in by_lane]
        if missing:
            emit(name, "fail", reason="missing lane rows", missing=",".join(missing), bound=bound)
            failed += 1
            continue
        worst = 0.0
        for errs in by_lane.values():
            for err in errs:
                worst = worse(worst, err)
        status = emit(name, "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                      lanes=",".join(CONSENSUS_LANES))
        failed += status == "fail"
    if not groups:
        emit("reference_consensus_f64", "fail", reason="no family rows for the consensus lanes in the given files")
        failed += 1
    return failed


def run_consensus(args, table):
    if not args.results:
        raise SystemExit("--mode consensus needs --results <results.json ...>")
    rows = []
    for path in args.results:
        rows.extend(json.loads(Path(path).read_text())["rows"])
    failures = consensus_across(table, rows)
    print(f"SUMMARY consensus_files={len(args.results)} rows={len(rows)} failures={failures}")
    return 1 if failures else 0


PIN_PACKAGES = ("qiskit", "pennylane", "cirq-core", "numpy")


def committed_pins() -> dict:
    pins = {}
    for line in REQUIREMENTS.read_text().splitlines():
        name, _, version = line.partition("==")
        if name in PIN_PACKAGES:
            pins[name] = version
    return pins


def latest_on_index(package: str) -> str:
    proc = subprocess.run([sys.executable, "-I", "-m", "pip", "index", "versions", package],
                          capture_output=True, text=True, check=False)
    for line in proc.stdout.splitlines():
        if line.strip().startswith("LATEST:"):
            return line.split(":", 1)[1].strip()
    raise RuntimeError(f"could not read the latest {package} version: {one_line(proc.stderr or proc.stdout)}")


def run_pins():
    pins, current = committed_pins(), True
    for package in PIN_PACKAGES:
        try:
            latest = latest_on_index(package)
        except Exception as exc:  # noqa: BLE001  (an unreachable index is reported, never assumed current)
            latest = f"unavailable ({one_line(exc)})"
        same = pins.get(package) == latest
        current = current and same
        print(f"pins_current package={package} pinned={pins.get(package)} latest={latest} current={same}", flush=True)
    print(f"pins_current all={current} date_utc={time.strftime('%Y-%m-%d', time.gmtime())}")
    return 0 if current else 1


def run_checks_or_timed(args, table, fixture, fixture_sha, timed_mode):
    if timed_mode and not table["tolerances_confirmed"]:
        raise SystemExit(
            "REFUSED: timed mode needs \"tolerances_confirmed\": true in bench/scenarios/python_alternatives.json "
            "(owner confirmation R3 and physics sign-off). Use --mode check for correctness runs."
        )
    if timed_mode and args.cache_mode == "both":
        raise SystemExit("REFUSED: timed mode needs an explicit --cache-mode hot|cold")
    out_dir = Path(args.out_dir) if args.out_dir else None
    if out_dir:
        write_environment(args, table, fixture_sha, args.mode, out_dir)

    all_rows, failures, errors = [], 0, 0
    scenarios = select_scenarios(args, table)
    lanes = select_lanes(args, table)

    def report(row, prep):
        nonlocal failures, errors
        status = row["status"]
        name = check_name(row)
        if status == "error":
            errors += 1
            failures += 1 if row["gated"] else 0
            emit(name, "error", error=json.dumps(row["error"]), gated=row["gated"], tol=row["tolerance"])
        else:
            failures += status == "fail"
            emit(name, status, max_err=repr(row["max_err"]), tol=row["tolerance"],
                 beyond_kg10_floor=row["beyond_kg10_floor"], rows=prep.iterations, discrim_tol=row["discrimination_tolerance"],
                 **{"max_abs_ref": repr(row["max_abs_ref"]), "discriminating": f"{row['n_discriminating']}/{row['n_observables']}"})
        if "zz" in row:
            zz = row["zz"]
            emit("zz_" + name[len("agreement_"):], zz["status"], max_err=repr(zz["max_err"]), tol=row["tolerance"])
        published = "published" if timed_mode and status == "pass" else "not_published"
        per_op = row["per_op_ms"]
        cpu_wall = row["cpu_wall"]
        loop = row.get("cpu_wall_timed_loop")
        label = f" LABEL={row['cpu_wall_label']!r}" if row["cpu_wall_label"] else ""
        print(f"ROW scenario={row['scenario']} cache={row['cache_mode']} lane={row['lane']} per_op_ms="
              f"{'n/a' if per_op is None else format(per_op, '.6f')} timing={published} "
              f"cpu_wall_lane_call={'n/a' if cpu_wall is None else format(cpu_wall, '.3f')} "
              f"cpu_wall_timed_loop={'n/a' if loop is None else format(loop, '.3f')}{label}", flush=True)

    for sid in scenarios:
        scenario = table["scenarios"][sid]
        for cache_mode in modes_for(args, scenario):
            rows = execute_scenario(args, table, fixture, sid, cache_mode, lanes, timed_mode, not timed_mode, report)
            for row in rows:
                if row["status"] == "not_run":
                    print(f"ROW scenario={sid} cache={cache_mode} lane={row['lane']} {row['note']}", flush=True)
            all_rows.extend(rows)

    # exact-rational sampled check for rows produced in this run
    sampled_rows = [r for r in all_rows if r["scenario"] in table["scenarios"]
                    and table["scenarios"][r["scenario"]]["kind"].startswith("sampled") and r["status"] != "not_run"]
    if sampled_rows:
        worst = 0.0
        for r in sampled_rows:
            worst = worse(worst, r["max_err"])
        bound = table["selfcheck_bounds"]["sampled_counts_exact_rational"]
        status = emit("sampled_counts_exact_rational", "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                      rows=len(sampled_rows), data="synthetic")
        failures += status == "fail"

    # RF9: per-width consensus of the three complex128/float64 reference lanes
    failures += consensus_rows(table, all_rows)

    # Publication: a row is publishable iff its own status is pass, except the ungated state-based cirq_c64
    # rows (R5), which also need their untimed complex128 run to pass. Sampled kinds are never ungated.
    for row in all_rows:
        if row["status"] == "not_run":
            continue
        sampled = table["scenarios"][row["scenario"]]["kind"].startswith("sampled")
        has_timing = bool(row.get("times_ms"))
        if row["lane"] == "cirq_c64" and not sampled:
            equiv = [r for r in all_rows if r["lane"] == "cirq_c128_equivalence" and r["scenario"] == row["scenario"]
                     and r["cache_mode"] == row["cache_mode"]]
            row["cirq_publishable"] = bool(equiv) and equiv[0]["status"] == "pass" and row["status"] == "ungated"
            row["publishable"] = row["cirq_publishable"] and has_timing
        else:
            row["publishable"] = row["status"] == "pass" and has_timing
        if timed_mode and row["lane"] == "cirq_c64" and not sampled:
            print(f"PUBLISH scenario={row['scenario']} cache={row['cache_mode']} lane=cirq_c64 "
                  f"publishable={row['publishable']}", flush=True)

    if args.values_out:
        values = {}
        for row in all_rows:
            if row["status"] == "not_run":
                continue
            values[f"{row['scenario']}|{row['cache_mode']}|{row['lane']}"] = {
                "values": row["values"], "zz": row.get("zz", {}).get("values", {}),
                **({"error": row["error"]} if row["status"] == "error" else {})}
        Path(args.values_out).write_text(json.dumps(values, sort_keys=True, separators=(",", ":")) + "\n")

    if out_dir:
        (out_dir / "results.json").write_text(json.dumps({
            "mode": args.mode, "timing_published": bool(timed_mode), "fixture_sha256": fixture_sha,
            "rss_max_kb_self": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            "rows": all_rows}, indent=1) + "\n")
    print(f"SUMMARY rows={len(all_rows)} failures={failures} errors={errors} timing_published={timed_mode}", flush=True)
    return 1 if failures else 0


def run_pretime(args, table, fixture, fixture_sha):
    if args.cache_mode == "hot":
        raise SystemExit("pretime measures cold iterations only")
    out_dir = Path(args.out_dir) if args.out_dir else None
    scenarios = sorted((sid for sid in select_scenarios(args, table) if table["scenarios"][sid]["kind"] == "family"),
                       key=lambda s: (table["scenarios"][s]["qubits"], table["scenarios"][s]["family"]))
    lanes = [l for l in select_lanes(args, table) if l != "cirq_c128_equivalence"]
    budget = table["budget"]
    cumulative_h, rows = 0.0, []
    for sid in scenarios:  # widths ascending
        scenario = table["scenarios"][sid]
        prep = prepare(table, fixture, sid, "cold", warmup=0, iterations=1)
        for lane_id in [l for l in table["lane_order"] if l in lanes]:  # committed lane order
            cfg = table["lanes"][lane_id]
            ok, reason = lane_enabled_for(table, lane_id, prep, True)
            row = {"scenario": sid, "family": scenario["family"], "qubits": prep.qubits, "lane": lane_id}
            if not ok:
                row.update(status=reason)
            else:
                if cfg["framework"] == "nxquantum":
                    out = parse_nx(run_nx(args, table, nx_args(args, prep, cfg, "pretime", False)))
                    t_ms = out["times_ms"][0]
                else:
                    t_ms = run_python_lane(lane_id, prep, timed=True)["times_ms"][0]
                projected_h = t_ms * (scenario["warmup"] + scenario["iterations"]) * budget["runs"] / 3.6e6
                row.update(single_iteration_ms=t_ms, sample="one untimed iteration, single sample",
                           projected_hours=projected_h)
                if projected_h > budget["per_lane_width_hours"]:
                    row["status"] = "not run (budget)"
                elif cumulative_h + projected_h > budget["campaign_hours"]:
                    row["status"] = "not run (budget)"
                else:
                    cumulative_h += projected_h
                    row["status"] = "scheduled"
            rows.append(row)
            print("PRETIME " + json.dumps(row, sort_keys=True), flush=True)
    if out_dir:
        out_dir.mkdir(parents=True, exist_ok=True)
        write_environment(args, table, fixture_sha, "pretime", out_dir)
        (out_dir / "pretime.json").write_text(json.dumps({"rows": rows, "cumulative_projected_hours": cumulative_h}, indent=1) + "\n")
    print(f"SUMMARY pretime_rows={len(rows)} cumulative_projected_hours={cumulative_h:.6f}")
    return 0


def run_selfcheck(args, table, fixture, fixture_sha):
    if args.compare_values:
        return 0 if compare_values(*args.compare_values) == "pass" else 1
    statuses = []
    cap = args.max_qubits if args.max_qubits is not None else 24
    status, _ = selfcheck_dense(args, table, fixture)
    statuses.append(status)
    status, _ = selfcheck_prefix_parity(table, fixture, cap)
    statuses.append(status)
    status, _ = selfcheck_consensus(table, fixture, min(cap, 8))
    statuses.append(status)
    status, _ = selfcheck_sampled(args, table)
    statuses.append(status)
    statuses.append(selfcheck_agreement_negatives())
    print(f"SUMMARY selfchecks={len(statuses)} failures={statuses.count('fail')}")
    return 1 if "fail" in statuses else 0


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=["check", "timed", "pretime", "selfcheck", "pins", "consensus"], default="check")
    parser.add_argument("--scenario", action="append", help="scenario id (repeatable); default: all within --max-qubits")
    parser.add_argument("--cache-mode", choices=["hot", "cold", "both"], default="both")
    parser.add_argument("--lanes", type=str, default=None, help="comma list; default: the committed lane order")
    parser.add_argument("--max-qubits", type=int, default=None,
                        help="largest width to run (default 8 when no --scenario is named; this phase runs no wider "
                             "lanes unless a scenario is named explicitly)")
    parser.add_argument("--check-warmup", type=int, default=1)
    parser.add_argument("--check-iterations", type=int, default=3)
    parser.add_argument("--out-dir", type=str, default=None)
    parser.add_argument("--values-out", type=str, default=None, help="write value columns (no timings) for byte comparison")
    parser.add_argument("--results", nargs="+", default=None, metavar="RESULTS_JSON",
                        help="--mode consensus: per-invocation results.json files to merge")
    parser.add_argument("--compare-values", nargs=2, metavar=("A", "B"), default=None)
    parser.add_argument("--repo-root", type=Path, default=ROOT)
    parser.add_argument("--mix-cmd", type=str, default=os.environ.get("NXQ_BENCH_MIX_CMD", "mise exec -- mix"))
    return parser


def main() -> int:
    if not sys.flags.isolated:
        raise SystemExit("run with `.venv-bench/bin/python -I` (isolated mode is part of the protocol)")
    args = build_parser().parse_args()
    table = load_table()
    if args.compare_values:
        return 0 if compare_values(*args.compare_values) == "pass" else 1
    if args.mode == "pins":
        return run_pins()
    if args.mode == "consensus":
        return run_consensus(args, table)
    fixture, fixture_sha = load_fixture(table)
    print(f"FIXTURE sha256={fixture_sha} seeds=20261026+100*family_index+qubits "
          f"lanes={json.dumps({k: v['dtype'] for k, v in table['lanes'].items()}, sort_keys=True)}", flush=True)
    if args.mode == "selfcheck":
        return run_selfcheck(args, table, fixture, fixture_sha)
    if args.mode == "pretime":
        return run_pretime(args, table, fixture, fixture_sha)
    return run_checks_or_timed(args, table, fixture, fixture_sha, args.mode == "timed")


if __name__ == "__main__":
    raise SystemExit(main())
