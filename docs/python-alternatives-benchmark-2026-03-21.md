# Python Alternatives vs NxQuantum Benchmark (2026-03-21)

## Goal

Run a real local benchmark on equivalent simulator workloads across:

1. NxQuantum
2. Qiskit
3. PennyLane
4. Cirq

## Workload

Single-circuit expectation benchmark repeated in-process:

1. 2-qubit circuit
2. `H(0)`
3. `CNOT(0, 1)`
4. `RY(0.3)` on qubit 1
5. Expectation of `Z` on qubit 1

Benchmark settings:

1. iterations: `2000`
2. warmup: `100`
3. metric: `per_op_ms` (lower is better)
4. NxQuantum runtime profiles requested: `cpu_portable`, `cpu_compiled`

## Environment

- Host: local macOS arm64 dev machine
- Python: `3.9.6`
- NxQuantum runtime profile: `:cpu_portable`
- Python packages:
  - `qiskit==1.4.5`
  - `pennylane==0.38.0`
  - `cirq-core==1.3.0`

## Commands Used

```bash
python3 -m venv .venv-bench
source .venv-bench/bin/activate
python -m pip install --upgrade pip
python -m pip install 'qiskit>=1.2,<2' 'pennylane>=0.38,<0.40' 'cirq-core>=1.3,<1.5'
python -m pip install 'autoray<0.7'
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled
```

## Latest Raw Result Snapshot (2026-03-21)

| Framework lane | Requested profile | Resolved profile | ms/op |
| --- | --- | --- | ---: |
| NxQuantum | `cpu_portable` | `cpu_portable` | 0.041891 |
| NxQuantum | `cpu_compiled` | `cpu_portable` | 0.041559 |
| Qiskit | n/a | n/a | 0.103706 |
| PennyLane | n/a | n/a | 0.405602 |
| Cirq | n/a | n/a | 0.340328 |

## Previous 3-run Baseline (before optimization pass)

| Run | NxQuantum (ms/op) | Qiskit (ms/op) | PennyLane (ms/op) | Cirq (ms/op) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.072071 | 0.103979 | 0.412436 | 0.340090 |
| 2 | 0.073941 | 0.103735 | 0.401781 | 0.339375 |
| 3 | 0.073600 | 0.103969 | 0.405483 | 0.339976 |

## Notes on Runtime Profile Resolution

1. In this machine run, requesting `cpu_compiled` resolved to `cpu_portable`.
2. The benchmark now reports both requested and resolved runtime profiles for transparency.

## Notes and Caveats

1. This benchmark measures repeated local simulation calls on a small circuit, not remote provider execution.
2. Results are useful for relative local-call overhead on this machine, not universal absolute performance claims.
3. A urllib warning appears due system LibreSSL and does not change measured loop timing.

## Benchmark Harness Files

1. `bench/python_alternatives_benchmark.py`
2. `bench/nxquantum_python_comparison.exs`
3. `bench/nxquantum_parallel_opportunity.exs`
4. `bench/nxquantum_parallel_opportunity_sampler.exs`
