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
  selfcheck reference self-checks: dense reference (<=6q), prefix-parity analytic
            identity, f64 consensus, exact-rational sampled counts; or
            --compare-values A B for byte identity of two value files.

Always run as:  .venv-bench/bin/python -I bench/python_alternatives_benchmark.py ...
"""

from __future__ import annotations

import argparse
import hashlib
import json
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


class QiskitLane:
    name = "qiskit"

    def build(self, qubits, gates):
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

    def build(self, qubits, gates):
        import pennylane as qml

        ops = []
        for gate in gates:
            if gate[0] == "cnot":
                ops.append(qml.CNOT(wires=[gate[1], gate[2]]))
            elif gate[0] == "h":
                ops.append(qml.Hadamard(wires=gate[1]))
            else:
                ops.append({"rx": qml.RX, "ry": qml.RY, "rz": qml.RZ}[gate[0]](gate[2], wires=gate[1]))
        return ops

    def runner(self, qubits, observables):
        import pennylane as qml

        device = qml.device("default.qubit", wires=qubits)
        make = {"X": qml.PauliX, "Y": qml.PauliY, "Z": qml.PauliZ}
        measurements = [qml.expval(make[axis](wires=wire)) for axis, wire in observables]

        def run(ops):
            tape = qml.tape.QuantumScript(ops, measurements)
            result = qml.execute([tape], device)[0]
            if len(measurements) == 1 and not isinstance(result, (tuple, list)):
                result = (result,)
            return [float(v) for v in result]

        return run

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

    def build(self, qubits, gates):
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
        simulator = cirq.Simulator() if self.dtype is None else cirq.Simulator(dtype=self.dtype)

        def run(circuit):
            return [float(v.real) for v in simulator.simulate_expectation_values(circuit, observables=obs)]

        return run

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


def max_error(values, refs) -> float:
    worst = 0.0
    for got_row, ref_row in zip(values, refs):
        if len(got_row) != len(ref_row):
            return float("inf")
        for got, ref in zip(got_row, ref_row):
            err = float(abs(Fraction(got) - ref)) if isinstance(ref, Fraction) else abs(got - ref)
            worst = max(worst, err)
    return worst


def verdict(max_err: float, tolerance):
    if tolerance is None:
        return "ungated"
    return "pass" if max_err <= tolerance else "fail"


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
    else:
        runner = lane.runner(prep.qubits, prep.observables)
        built = {}
        tokens = []
        for gates in prep.gate_sets:  # built before the timed loop, one per iteration
            if id(gates) not in built:
                built[id(gates)] = lane.build(prep.qubits, gates)
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
        runner = lane.runner(prep.qubits, [("Z", b)])
        out[f"{a},{b}"] = runner(lane.build(prep.qubits, prep.gate_sets[0] + [("cnot", a, b)]))[0]
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
        row = {
            "scenario": sid, "family": scenario.get("family"), "qubits": prep.qubits, "cache_mode": cache_mode,
            "lane": lane_id, "dtype": lane_cfg["dtype"], "label": scenario.get("lane_labels", {}).get(lane_id),
            "warmup": prep.warmup, "iterations": prep.iterations, "scenario_labels": scenario.get("labels", []),
            "synthetic": scenario.get("synthetic", False),
        }
        if not ok:
            row.update(status="not_run", note=reason)
            rows.append(row)
            continue

        started = time.perf_counter()
        if lane_cfg["framework"] == "nxquantum":
            out = parse_nx(run_nx(args, table, nx_args(args, prep, lane_cfg, "timed" if timed_mode else "values", zz_ref != {})))
            values, times = out["values"], out["times_ms"]
            row["resolved_profile"] = out["bench"].get("resolved_profile")
            row["nx_flags"] = out["bench"].get("flags")
            zz_values = out["zz"]
        else:
            out = run_python_lane(lane_id, prep, timed=lane_cfg.get("timed", True))
            values, times = out["values"], out["times_ms"]
            zz_values = python_zz(lane_id, prep, fixture) if zz_ref else {}
        row["wall_s"] = time.perf_counter() - started

        tolerance = tolerance_for(table, scenario, lane_id)
        err = max_error(values, refs)
        row.update(
            max_err=err, tolerance=tolerance, status=verdict(err, tolerance),
            beyond_kg10_floor=bool(err > 1e-6),
            values=[[repr(v) for v in rowvals] for rowvals in values],
            times_ms=times,
            per_op_ms=(sum(times) / len(times)) if times else None,
        )
        if zz_ref:
            zz_err = max(abs(zz_values[key] - ref) for key, ref in zz_ref.items()) if zz_values else float("inf")
            row["zz"] = {"values": {k: repr(v) for k, v in zz_values.items()}, "max_err": zz_err,
                         "status": verdict(zz_err, tolerance)}
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
    ]
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
        err_state = float(np.max(np.abs(flat - elixir_state)))
        obs = [(axis, w) for axis in ("X", "Y", "Z") for w in range(n)]
        ref_vals = ref_expectations(psi, obs)
        err_obs = max(abs(a - b) for a, b in zip(ref_vals, got["expectations"]))
        detail[name] = max(err_state, err_obs)
        worst = max(worst, detail[name])
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
            err = max(abs(a - b) for a, b in zip(got, expected))
            detail[f"{family}_{n}"] = err
            worst = max(worst, err)
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
            got = lane.runner(n, observables)(lane.build(n, gates))
            err = max(abs(a - b) for a, b in zip(got, ref))
            detail[f"{name}:{lane_id}"] = err
            worst = max(worst, err)
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
            worst = max(worst, err)
    return emit("sampled_counts_exact_rational", "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                rows=len(results)), results


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
    if args.max_qubits is not None:
        ids = [sid for sid in ids if table["scenarios"][sid]["qubits"] <= args.max_qubits]
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

    all_rows, failures = [], 0
    scenarios = select_scenarios(args, table)
    lanes = select_lanes(args, table)

    def report(row, prep):
        nonlocal failures
        status = row["status"]
        if status == "fail":
            failures += 1
        emit(check_name(row), status, max_err=repr(row["max_err"]), tol=row["tolerance"],
             beyond_kg10_floor=row["beyond_kg10_floor"], rows=prep.iterations)
        if "zz" in row:
            zz = row["zz"]
            if zz["status"] == "fail":
                failures += 1
            emit("zz_" + check_name(row)[len("agreement_"):], zz["status"], max_err=repr(zz["max_err"]), tol=row["tolerance"])
        published = "published" if timed_mode and status in ("pass",) else "not_published"
        per_op = row["per_op_ms"]
        print(f"ROW scenario={row['scenario']} cache={row['cache_mode']} lane={row['lane']} per_op_ms="
              f"{'n/a' if per_op is None else format(per_op, '.6f')} timing={published}", flush=True)

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
        worst = max(r["max_err"] for r in sampled_rows)
        bound = table["selfcheck_bounds"]["sampled_counts_exact_rational"]
        status = emit("sampled_counts_exact_rational", "pass" if worst <= bound else "fail", max_err=repr(worst), bound=bound,
                      rows=len(sampled_rows), data="synthetic")
        failures += status == "fail"

    # Cirq c64 publication rule (R5)
    for row in all_rows:
        if row["lane"] == "cirq_c64" and row["status"] != "not_run":
            equiv = [r for r in all_rows if r["lane"] == "cirq_c128_equivalence" and r["scenario"] == row["scenario"]
                     and r["cache_mode"] == row["cache_mode"]]
            row["cirq_publishable"] = bool(equiv) and equiv[0]["status"] == "pass"

    if args.values_out:
        values = {}
        for row in all_rows:
            if row["status"] == "not_run":
                continue
            values[f"{row['scenario']}|{row['cache_mode']}|{row['lane']}"] = {
                "values": row["values"], "zz": row.get("zz", {}).get("values", {})}
        Path(args.values_out).write_text(json.dumps(values, sort_keys=True, separators=(",", ":")) + "\n")

    if out_dir:
        (out_dir / "results.json").write_text(json.dumps({
            "mode": args.mode, "timing_published": bool(timed_mode), "fixture_sha256": fixture_sha,
            "rss_max_kb_self": resource.getrusage(resource.RUSAGE_SELF).ru_maxrss,
            "rows": all_rows}, indent=1) + "\n")
    print(f"SUMMARY rows={len(all_rows)} failures={failures} timing_published={timed_mode}", flush=True)
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
    print(f"SUMMARY selfchecks={len(statuses)} failures={statuses.count('fail')}")
    return 1 if "fail" in statuses else 0


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--mode", choices=["check", "timed", "pretime", "selfcheck"], default="check")
    parser.add_argument("--scenario", action="append", help="scenario id (repeatable); default: all within --max-qubits")
    parser.add_argument("--cache-mode", choices=["hot", "cold", "both"], default="both")
    parser.add_argument("--lanes", type=str, default=None, help="comma list; default: the committed lane order")
    parser.add_argument("--max-qubits", type=int, default=8,
                        help="largest width to run (default 8: this phase runs no wider lanes)")
    parser.add_argument("--check-warmup", type=int, default=1)
    parser.add_argument("--check-iterations", type=int, default=3)
    parser.add_argument("--out-dir", type=str, default=None)
    parser.add_argument("--values-out", type=str, default=None, help="write value columns (no timings) for byte comparison")
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
