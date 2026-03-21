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
5. Scenarios:
   - `baseline_2q` (existing)
   - `deep_6q` (new, deeper multi-qubit benchmark)

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
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario baseline_2q
python bench/python_alternatives_benchmark.py --iterations 500 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario deep_6q
```

## Latest Raw Result Snapshot (2026-03-21)

| Framework lane | Requested profile | Resolved profile | ms/op |
| --- | --- | --- | ---: |
| NxQuantum | `cpu_portable` | `cpu_portable` | 0.031891 |
| NxQuantum | `cpu_compiled` | `cpu_portable` | 0.032398 |
| Qiskit | n/a | n/a | 0.185847 |
| PennyLane | n/a | n/a | 0.415514 |
| Cirq | n/a | n/a | 0.360620 |

## Previous 3-run Baseline (before optimization pass)

| Run | NxQuantum (ms/op) | Qiskit (ms/op) | PennyLane (ms/op) | Cirq (ms/op) |
| --- | ---: | ---: | ---: | ---: |
| 1 | 0.072071 | 0.103979 | 0.412436 | 0.340090 |
| 2 | 0.073941 | 0.103735 | 0.401781 | 0.339375 |
| 3 | 0.073600 | 0.103969 | 0.405483 | 0.339976 |

## Notes on Runtime Profile Resolution

1. In this machine run, requesting `cpu_compiled` resolved to `cpu_portable`.
2. The benchmark now reports both requested and resolved runtime profiles for transparency.

## Deep 6-Qubit Scenario Snapshot (2026-03-21)

| Framework lane | Requested profile | Resolved profile | ms/op |
| --- | --- | --- | ---: |
| NxQuantum | `cpu_portable` | `cpu_portable` | 0.418688 |
| NxQuantum | `cpu_compiled` | `cpu_portable` | 0.430902 |
| Qiskit | n/a | n/a | 0.449462 |
| PennyLane | n/a | n/a | 1.177525 |
| Cirq | n/a | n/a | 0.920723 |

Deep scenario delta after structured state-vector gate application refactor:

1. NxQuantum (`cpu_portable`) improved from `17.58 ms/op` to `0.57 ms/op` (~31x faster on this machine).
2. Remaining gap vs Qiskit in `deep_6q` is now ~1.8x (down from ~57x previously).
3. Follow-up layout-plan caching pass improved `deep_6q` from `0.567794 ms/op` to a 3-run mean `0.563728 ms/op` (`0.560142..0.570376`, ~0.72%).
4. Pairwise single-qubit kernel + hybrid small-qubit fallback improved `deep_6q` to a direct 3-run mean `0.432341 ms/op` (`0.425218..0.436286`, ~23.3% better than `0.563728`) while preserving `baseline_2q` near `~0.032 ms/op`.
5. Allocation-focused coefficient caching removed per-gate scalar slicing and improved `deep_6q` to a direct 3-run mean `0.408282 ms/op` (`0.401670..0.417186`, ~5.6% better than `0.432341`) while keeping `baseline_2q` stable at `~0.0326 ms/op`.

Interpretation:

1. NxQuantum remains fastest on `baseline_2q` in this environment.
2. For `deep_6q`, NxQuantum is now in the same sub-millisecond class and leads in the latest run snapshot on this machine.
3. Hybrid kernel selection (small-qubit transpose path + deeper-circuit pairwise path) improved deep performance without sacrificing baseline latency.
4. Further gains should prioritize compiled runtime availability and minimizing temporary tensor allocations in pairwise updates.
5. Cross-framework deep-circuit order can vary run-to-run; keep using multi-run means for promotion decisions.

## Notes and Caveats

1. This benchmark measures repeated local simulation calls on a small circuit, not remote provider execution.
2. Results are useful for relative local-call overhead on this machine, not universal absolute performance claims.
3. A urllib warning appears due system LibreSSL and does not change measured loop timing.

## Benchmark Harness Files

1. `bench/python_alternatives_benchmark.py`
2. `bench/nxquantum_python_comparison.exs`
3. `bench/nxquantum_parallel_opportunity.exs`
4. `bench/nxquantum_parallel_opportunity_sampler.exs`
