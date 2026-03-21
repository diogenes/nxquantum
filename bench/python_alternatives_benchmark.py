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


def bench_qiskit(iterations: int, warmup: int):
    from qiskit import QuantumCircuit
    from qiskit.quantum_info import Pauli, Statevector

    circuit = QuantumCircuit(2)
    circuit.h(0)
    circuit.cx(0, 1)
    circuit.ry(0.3, 1)

    pauli_z_q1 = Pauli("IZ")

    def run_once():
        return float(Statevector.from_instruction(circuit).expectation_value(pauli_z_q1).real)

    return _bench(run_once, iterations, warmup)


def bench_pennylane(iterations: int, warmup: int):
    import pennylane as qml

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


def bench_cirq(iterations: int, warmup: int):
    import cirq

    q0, q1 = cirq.LineQubit.range(2)
    circuit = cirq.Circuit(
        cirq.H(q0),
        cirq.CNOT(q0, q1),
        cirq.ry(0.3)(q1),
    )
    observable = cirq.Z(q1)
    simulator = cirq.Simulator()

    def run_once():
        values = simulator.simulate_expectation_values(circuit, observables=[observable])
        return float(values[0].real)

    return _bench(run_once, iterations, warmup)


def bench_nxquantum(repo_root: Path, iterations: int, runtime_profile: str):
    cmd = [
        "mise",
        "exec",
        "--",
        "mix",
        "run",
        "bench/nxquantum_python_comparison.exs",
        str(iterations),
        runtime_profile,
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
    }


def print_table(results):
    print("\nBenchmark results (lower per_op_ms is better):")
    print("framework,total_ms,per_op_ms,ops_s,value,requested_profile,resolved_profile")
    for name, data in results.items():
        print(
            f"{name},{data['total_ms']:.6f},{data['per_op_ms']:.6f},{data['ops_s']:.6f},{data['value']},{data.get('requested_profile','')},{data.get('resolved_profile','')}"
        )

    fastest = min(results.items(), key=lambda x: x[1]["per_op_ms"])
    print(f"\nFastest by per_op_ms: {fastest[0]} ({fastest[1]['per_op_ms']:.6f} ms/op)")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--iterations", type=int, default=2000)
    parser.add_argument("--warmup", type=int, default=100)
    parser.add_argument("--nx-runtime-profiles", type=str, default="cpu_portable")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    results = {}
    nx_profiles = [profile.strip() for profile in args.nx_runtime_profiles.split(",") if profile.strip()]

    for profile in nx_profiles:
        results[f"nxquantum[{profile}]"] = bench_nxquantum(args.repo_root, args.iterations, profile)

    results["qiskit"] = bench_qiskit(args.iterations, args.warmup)
    results["pennylane"] = bench_pennylane(args.iterations, args.warmup)
    results["cirq"] = bench_cirq(args.iterations, args.warmup)

    print_table(results)


if __name__ == "__main__":
    main()
