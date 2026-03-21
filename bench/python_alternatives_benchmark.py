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


def bench_qiskit(iterations: int, warmup: int, scenario: str):
    from qiskit import QuantumCircuit
    from qiskit.quantum_info import Pauli, Statevector

    if scenario == "deep_6q":
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

    if scenario == "deep_6q":
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

    if scenario == "deep_6q":
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
        values = simulator.simulate_expectation_values(circuit, observables=[observable])
        return float(values[0].real)

    return _bench(run_once, iterations, warmup)


def bench_nxquantum(repo_root: Path, iterations: int, runtime_profile: str, scenario: str):
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
        "scenario": fields.get("scenario"),
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
    parser.add_argument("--scenario", type=str, default="baseline_2q", choices=["baseline_2q", "deep_6q"])
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()

    results = {}
    nx_profiles = [profile.strip() for profile in args.nx_runtime_profiles.split(",") if profile.strip()]

    for profile in nx_profiles:
        results[f"nxquantum[{profile}]"] = bench_nxquantum(args.repo_root, args.iterations, profile, args.scenario)

    results["qiskit"] = bench_qiskit(args.iterations, args.warmup, args.scenario)
    results["pennylane"] = bench_pennylane(args.iterations, args.warmup, args.scenario)
    results["cirq"] = bench_cirq(args.iterations, args.warmup, args.scenario)

    print_table(results)


if __name__ == "__main__":
    main()
