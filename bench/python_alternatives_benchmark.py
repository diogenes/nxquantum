#!/usr/bin/env python3
"""
Cross-ecosystem local benchmark:
- NxQuantum (via mix script)
- Qiskit
- PennyLane
- Cirq
"""

from __future__ import annotations

import argparse
import subprocess
import time
from pathlib import Path

import numpy as np

OBSERVABLE_CYCLE = ("X", "Y", "Z")


def _qiskit_pauli_label(qubits: int, wire: int, axis: str) -> str:
    # Qiskit Pauli labels are little-endian relative to qubit index.
    chars = ["I"] * qubits
    chars[wire] = axis
    return "".join(chars)[::-1]


def _batch_obs_specs(qubits: int = 8, observable_count: int = 48):
    for index in range(observable_count):
        yield OBSERVABLE_CYCLE[index % len(OBSERVABLE_CYCLE)], index % qubits


def _sampled_counts_sparse_terms_terms(qubits: int = 8, term_count: int = 48):
    # Use a full-cycle multiplier modulo (2^n - 1) to produce deterministic, diverse diagonal masks.
    max_mask = (1 << qubits) - 1

    for index in range(term_count):
        z_mask = ((index * 37) % max_mask) + 1
        magnitude = 0.02 * ((index % 5) + 1)
        coeff = magnitude if index % 2 == 0 else -magnitude
        yield z_mask, coeff


def _sampled_counts_sparse_terms_counts():
    return {
        "00000000": 900,
        "00000011": 420,
        "00011100": 330,
        "00110011": 270,
        "01010101": 510,
        "01100110": 340,
        "10011001": 290,
        "10101010": 470,
        "11000011": 280,
        "11111111": 286,
    }


def _qiskit_pauli_label_from_z_mask(qubits: int, z_mask: int) -> str:
    chars = ["I"] * qubits
    for wire in range(qubits):
        if (z_mask >> wire) & 1:
            chars[wire] = "Z"
    return "".join(chars)[::-1]


def _counts_entries(counts: dict[str, int]):
    entries = []
    shots = 0

    for bitstring, count in counts.items():
        value = int(bitstring, 2)
        entries.append((value, count))
        shots += count

    return entries, float(shots)


def _popcount(value: int) -> int:
    count = 0
    while value:
        value &= value - 1
        count += 1
    return count


def _z_mask_expectation_from_counts(entries, shots: float, z_mask: int) -> float:
    signed_sum = 0.0
    for value, count in entries:
        parity = _popcount(value & z_mask) & 1
        sign = -1.0 if parity else 1.0
        signed_sum += sign * count
    return signed_sum / shots


def _sampled_sparse_sum_from_counts(entries, shots: float, terms) -> float:
    lookup = {}
    total = 0.0

    for z_mask, coeff in terms:
        if z_mask not in lookup:
            lookup[z_mask] = _z_mask_expectation_from_counts(entries, shots, z_mask)
        total += coeff * lookup[z_mask]

    return total


def _wire_mask(qubits: int, wire: int, little_endian: bool = True) -> int:
    bit = wire if little_endian else qubits - 1 - wire
    return 1 << bit


def _exp_pauli_x_from_statevector(statevector: np.ndarray, qubits: int, wire: int, little_endian: bool = True) -> float:
    mask = _wire_mask(qubits, wire, little_endian=little_endian)
    total = 0.0 + 0.0j

    for index, amp in enumerate(statevector):
        total += np.conj(amp) * statevector[index ^ mask]

    return float(np.real(total))


def _exp_pauli_y_from_statevector(statevector: np.ndarray, qubits: int, wire: int, little_endian: bool = True) -> float:
    mask = _wire_mask(qubits, wire, little_endian=little_endian)
    bit = wire if little_endian else qubits - 1 - wire
    total = 0.0 + 0.0j

    for index, amp in enumerate(statevector):
        phase = 1.0j if ((index >> bit) & 1) == 0 else -1.0j
        total += np.conj(amp) * phase * statevector[index ^ mask]

    return float(np.real(total))


def _apply_batch_obs_8q_circuit_qiskit(circuit):
    circuit.h(0)
    circuit.cx(0, 1)
    circuit.cx(1, 2)
    circuit.cx(2, 3)
    circuit.cx(3, 4)
    circuit.cx(4, 5)
    circuit.cx(5, 6)
    circuit.cx(6, 7)
    circuit.ry(0.11, 0)
    circuit.ry(0.22, 1)
    circuit.ry(0.33, 2)
    circuit.ry(0.44, 3)
    circuit.ry(0.55, 4)
    circuit.ry(0.66, 5)
    circuit.ry(0.77, 6)
    circuit.ry(0.88, 7)
    circuit.rx(0.19, 2)
    circuit.rz(0.29, 3)
    circuit.cx(0, 4)
    circuit.cx(2, 6)
    circuit.cx(1, 5)


def _apply_batch_obs_8q_circuit_pennylane(qml):
    qml.Hadamard(wires=0)
    qml.CNOT(wires=[0, 1])
    qml.CNOT(wires=[1, 2])
    qml.CNOT(wires=[2, 3])
    qml.CNOT(wires=[3, 4])
    qml.CNOT(wires=[4, 5])
    qml.CNOT(wires=[5, 6])
    qml.CNOT(wires=[6, 7])
    qml.RY(0.11, wires=0)
    qml.RY(0.22, wires=1)
    qml.RY(0.33, wires=2)
    qml.RY(0.44, wires=3)
    qml.RY(0.55, wires=4)
    qml.RY(0.66, wires=5)
    qml.RY(0.77, wires=6)
    qml.RY(0.88, wires=7)
    qml.RX(0.19, wires=2)
    qml.RZ(0.29, wires=3)
    qml.CNOT(wires=[0, 4])
    qml.CNOT(wires=[2, 6])
    qml.CNOT(wires=[1, 5])


def _apply_batch_obs_8q_circuit_cirq(cirq, q):
    return [
        cirq.H(q[0]),
        cirq.CNOT(q[0], q[1]),
        cirq.CNOT(q[1], q[2]),
        cirq.CNOT(q[2], q[3]),
        cirq.CNOT(q[3], q[4]),
        cirq.CNOT(q[4], q[5]),
        cirq.CNOT(q[5], q[6]),
        cirq.CNOT(q[6], q[7]),
        cirq.ry(0.11)(q[0]),
        cirq.ry(0.22)(q[1]),
        cirq.ry(0.33)(q[2]),
        cirq.ry(0.44)(q[3]),
        cirq.ry(0.55)(q[4]),
        cirq.ry(0.66)(q[5]),
        cirq.ry(0.77)(q[6]),
        cirq.ry(0.88)(q[7]),
        cirq.rx(0.19)(q[2]),
        cirq.rz(0.29)(q[3]),
        cirq.CNOT(q[0], q[4]),
        cirq.CNOT(q[2], q[6]),
        cirq.CNOT(q[1], q[5]),
    ]


def _bench(fn, iterations: int, warmup: int):
    for _ in range(warmup):
        fn()

    start = time.perf_counter()
    value = None
    for _ in range(iterations):
        value = fn()
    elapsed_s = time.perf_counter() - start

    total_ms = elapsed_s * 1000.0
    per_op_ms = total_ms / iterations
    ops_s = iterations / elapsed_s if elapsed_s else float("inf")

    return {
        "total_ms": total_ms,
        "per_op_ms": per_op_ms,
        "ops_s": ops_s,
        "value": value,
    }


def bench_qiskit(iterations: int, warmup: int, scenario: str):
    from qiskit import QuantumCircuit
    from qiskit.quantum_info import Pauli, SparsePauliOp, Statevector
    from qiskit.result import sampled_expectation_value

    if scenario == "state_reuse_8q_xy":
        circuit = QuantumCircuit(8)
        _apply_batch_obs_8q_circuit_qiskit(circuit)
        state = Statevector.from_instruction(circuit)
        pauli_x = Pauli(_qiskit_pauli_label(8, 5, "X"))
        pauli_y = Pauli(_qiskit_pauli_label(8, 5, "Y"))

        def run_once():
            x = float(state.expectation_value(pauli_x).real)
            y = float(state.expectation_value(pauli_y).real)
            return x + y

        return _bench(run_once, iterations, warmup)
    elif scenario == "sampled_counts_sparse_terms":
        counts = _sampled_counts_sparse_terms_counts()
        terms = list(_sampled_counts_sparse_terms_terms())
        labels = [_qiskit_pauli_label_from_z_mask(8, z_mask) for z_mask, _ in terms]
        coeffs = [coeff for _, coeff in terms]
        operator = SparsePauliOp(labels, coeffs=coeffs)

        def run_once():
            return float(sampled_expectation_value(counts, operator))

        return _bench(run_once, iterations, warmup)
    elif scenario == "batch_obs_8q":
        circuit = QuantumCircuit(8)
        _apply_batch_obs_8q_circuit_qiskit(circuit)
        observables = [Pauli(_qiskit_pauli_label(8, wire, axis)) for axis, wire in _batch_obs_specs()]

        def run_once():
            state = Statevector.from_instruction(circuit)
            return float(sum(float(state.expectation_value(obs).real) for obs in observables))

        return _bench(run_once, iterations, warmup)
    elif scenario == "deep_6q":
        circuit = QuantumCircuit(6)
        circuit.h(0)
        circuit.cx(0, 1)
        circuit.cx(1, 2)
        circuit.cx(2, 3)
        circuit.cx(3, 4)
        circuit.cx(4, 5)
        circuit.ry(0.11, 0)
        circuit.ry(0.22, 1)
        circuit.ry(0.33, 2)
        circuit.ry(0.44, 3)
        circuit.ry(0.55, 4)
        circuit.ry(0.66, 5)
        circuit.cx(0, 3)
        circuit.cx(2, 5)
        circuit.cx(1, 4)
        observable = Pauli("ZIIIII")
    else:
        circuit = QuantumCircuit(2)
        circuit.h(0)
        circuit.cx(0, 1)
        circuit.ry(0.3, 1)
        observable = Pauli("IZ")

    def run_once():
        return float(Statevector.from_instruction(circuit).expectation_value(observable).real)

    return _bench(run_once, iterations, warmup)


def bench_pennylane(iterations: int, warmup: int, scenario: str):
    import pennylane as qml

    if scenario == "state_reuse_8q_xy":
        dev = qml.device("default.qubit", wires=8)

        @qml.qnode(dev)
        def circuit():
            _apply_batch_obs_8q_circuit_pennylane(qml)
            return qml.state()

        state = np.asarray(circuit(), dtype=np.complex128)

        def run_once():
            x = _exp_pauli_x_from_statevector(state, 8, 5, little_endian=False)
            y = _exp_pauli_y_from_statevector(state, 8, 5, little_endian=False)
            return x + y
    elif scenario == "sampled_counts_sparse_terms":
        counts = _sampled_counts_sparse_terms_counts()
        terms = list(_sampled_counts_sparse_terms_terms())
        entries, shots = _counts_entries(counts)

        def run_once():
            return _sampled_sparse_sum_from_counts(entries, shots, terms)
    elif scenario == "batch_obs_8q":
        dev = qml.device("default.qubit", wires=8)
        observables = []
        for axis, wire in _batch_obs_specs():
            if axis == "X":
                observables.append(qml.PauliX(wires=wire))
            elif axis == "Y":
                observables.append(qml.PauliY(wires=wire))
            else:
                observables.append(qml.PauliZ(wires=wire))

        @qml.qnode(dev)
        def circuit():
            _apply_batch_obs_8q_circuit_pennylane(qml)
            return tuple(qml.expval(obs) for obs in observables)

        def run_once():
            return float(sum(float(value) for value in circuit()))
    elif scenario == "deep_6q":
        dev = qml.device("default.qubit", wires=6)

        @qml.qnode(dev)
        def circuit():
            qml.Hadamard(wires=0)
            qml.CNOT(wires=[0, 1])
            qml.CNOT(wires=[1, 2])
            qml.CNOT(wires=[2, 3])
            qml.CNOT(wires=[3, 4])
            qml.CNOT(wires=[4, 5])
            qml.RY(0.11, wires=0)
            qml.RY(0.22, wires=1)
            qml.RY(0.33, wires=2)
            qml.RY(0.44, wires=3)
            qml.RY(0.55, wires=4)
            qml.RY(0.66, wires=5)
            qml.CNOT(wires=[0, 3])
            qml.CNOT(wires=[2, 5])
            qml.CNOT(wires=[1, 4])
            return qml.expval(qml.PauliZ(5))

        def run_once():
            return float(circuit())
    else:
        dev = qml.device("default.qubit", wires=2)

        @qml.qnode(dev)
        def circuit(theta):
            qml.Hadamard(wires=0)
            qml.CNOT(wires=[0, 1])
            qml.RY(theta, wires=1)
            return qml.expval(qml.PauliZ(1))

        def run_once():
            return float(circuit(0.3))

    return _bench(run_once, iterations, warmup)


def bench_cirq(iterations: int, warmup: int, scenario: str):
    import cirq

    if scenario == "state_reuse_8q_xy":
        q = cirq.LineQubit.range(8)
        circuit = cirq.Circuit(*_apply_batch_obs_8q_circuit_cirq(cirq, q))
        simulator = cirq.Simulator()
        final_state = simulator.simulate(circuit).final_state_vector
        state = np.asarray(final_state, dtype=np.complex128)

        def run_once():
            x = _exp_pauli_x_from_statevector(state, 8, 5, little_endian=False)
            y = _exp_pauli_y_from_statevector(state, 8, 5, little_endian=False)
            return x + y

        return _bench(run_once, iterations, warmup)
    elif scenario == "sampled_counts_sparse_terms":
        counts = _sampled_counts_sparse_terms_counts()
        terms = list(_sampled_counts_sparse_terms_terms())
        entries, shots = _counts_entries(counts)

        def run_once():
            return _sampled_sparse_sum_from_counts(entries, shots, terms)

        return _bench(run_once, iterations, warmup)
    elif scenario == "batch_obs_8q":
        q = cirq.LineQubit.range(8)
        circuit = cirq.Circuit(*_apply_batch_obs_8q_circuit_cirq(cirq, q))
        observables = []
        for axis, wire in _batch_obs_specs():
            if axis == "X":
                observables.append(cirq.X(q[wire]))
            elif axis == "Y":
                observables.append(cirq.Y(q[wire]))
            else:
                observables.append(cirq.Z(q[wire]))
    elif scenario == "deep_6q":
        q = cirq.LineQubit.range(6)
        circuit = cirq.Circuit(
            cirq.H(q[0]),
            cirq.CNOT(q[0], q[1]),
            cirq.CNOT(q[1], q[2]),
            cirq.CNOT(q[2], q[3]),
            cirq.CNOT(q[3], q[4]),
            cirq.CNOT(q[4], q[5]),
            cirq.ry(0.11)(q[0]),
            cirq.ry(0.22)(q[1]),
            cirq.ry(0.33)(q[2]),
            cirq.ry(0.44)(q[3]),
            cirq.ry(0.55)(q[4]),
            cirq.ry(0.66)(q[5]),
            cirq.CNOT(q[0], q[3]),
            cirq.CNOT(q[2], q[5]),
            cirq.CNOT(q[1], q[4]),
        )
        observable = cirq.Z(q[5])
    else:
        q0, q1 = cirq.LineQubit.range(2)
        circuit = cirq.Circuit(
            cirq.H(q0),
            cirq.CNOT(q0, q1),
            cirq.ry(0.3)(q1),
        )
        observable = cirq.Z(q1)
    simulator = cirq.Simulator()

    def run_once():
        if scenario == "batch_obs_8q":
            values = simulator.simulate_expectation_values(circuit, observables=observables)
            return float(sum(float(value.real) for value in values))

        values = simulator.simulate_expectation_values(circuit, observables=[observable])
        return float(values[0].real)

    return _bench(run_once, iterations, warmup)


def bench_nxquantum(repo_root: Path, iterations: int, runtime_profile: str, scenario: str, cache_mode: str):
    cmd = [
        "mise",
        "exec",
        "--",
        "mix",
        "run",
        "bench/nxquantum_python_comparison.exs",
        str(iterations),
        runtime_profile,
        scenario,
        cache_mode,
    ]

    completed = subprocess.run(
        cmd,
        cwd=repo_root,
        check=True,
        capture_output=True,
        text=True,
    )

    line = None
    for candidate in completed.stdout.splitlines():
        if candidate.startswith("NXQ_BENCH "):
            line = candidate
            break

    if not line:
        raise RuntimeError(f"Could not parse NxQuantum benchmark output. stdout={completed.stdout!r}")

    fields = {}
    for chunk in line.split()[1:]:
        key, value = chunk.split("=", 1)
        fields[key] = value

    return {
        "total_ms": float(fields["total_ms"]),
        "per_op_ms": float(fields["per_op_ms"]),
        "ops_s": float(fields["ops_s"]),
        "value": fields.get("value"),
        "requested_profile": fields.get("runtime_profile"),
        "resolved_profile": fields.get("resolved_profile"),
        "cache_mode": fields.get("cache_mode"),
        "scenario": fields.get("scenario"),
    }


def validate_profile_resolution(result: dict, profile_resolution_policy: str):
    requested_profile = result.get("requested_profile")
    resolved_profile = result.get("resolved_profile")

    if profile_resolution_policy == "require_exact" and requested_profile != resolved_profile:
        raise RuntimeError(
            "NxQuantum runtime profile mismatch: "
            f"requested={requested_profile} resolved={resolved_profile}. "
            "Use --nx-profile-resolution-policy allow_fallback to keep fallback lanes."
        )


def print_table(results):
    print("\nBenchmark results (lower per_op_ms is better):")
    print("framework,total_ms,per_op_ms,ops_s,value,requested_profile,resolved_profile,cache_mode")
    for name, data in results.items():
        print(
            f"{name},{data['total_ms']:.6f},{data['per_op_ms']:.6f},{data['ops_s']:.6f},{data['value']},{data.get('requested_profile','')},{data.get('resolved_profile','')},{data.get('cache_mode','')}"
        )

    fastest = min(results.items(), key=lambda x: x[1]["per_op_ms"])
    print(f"\nFastest by per_op_ms: {fastest[0]} ({fastest[1]['per_op_ms']:.6f} ms/op)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=2000)
    parser.add_argument("--warmup", type=int, default=100)
    parser.add_argument("--nx-runtime-profiles", type=str, default="cpu_portable")
    parser.add_argument(
        "--scenario",
        type=str,
        default="baseline_2q",
        choices=[
            "baseline_2q",
            "deep_6q",
            "batch_obs_8q",
            "state_reuse_8q_xy",
            "sampled_counts_sparse_terms",
        ],
    )
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument(
        "--nx-cache-mode",
        type=str,
        default="hot",
        choices=["hot", "cold"],
        help="NxQuantum cache mode. hot=cache enabled, cold=cache disabled for estimator workloads.",
    )
    parser.add_argument(
        "--nx-profile-resolution-policy",
        type=str,
        default="require_exact",
        choices=["require_exact", "allow_fallback"],
        help=(
            "Controls whether NxQuantum rows are allowed to silently run on fallback profiles. "
            "Use require_exact for apples-to-apples profile comparisons."
        ),
    )
    args = parser.parse_args()

    results = {}
    nx_profiles = [profile.strip() for profile in args.nx_runtime_profiles.split(",") if profile.strip()]

    for profile in nx_profiles:
        result = bench_nxquantum(args.repo_root, args.iterations, profile, args.scenario, args.nx_cache_mode)
        validate_profile_resolution(result, args.nx_profile_resolution_policy)
        results[f"nxquantum[{profile}]"] = result

    results["qiskit"] = bench_qiskit(args.iterations, args.warmup, args.scenario)
    results["pennylane"] = bench_pennylane(args.iterations, args.warmup, args.scenario)
    results["cirq"] = bench_cirq(args.iterations, args.warmup, args.scenario)

    print_table(results)


if __name__ == "__main__":
    main()
