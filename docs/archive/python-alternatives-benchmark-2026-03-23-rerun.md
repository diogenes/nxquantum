# Python Alternatives vs NxQuantum Benchmark (2026-03-23 Rerun)

## Scope

This report is a fresh 3-run aggregation from `tmp/bench_runs_2026-03-23_rerun/` for:
1. `baseline_2q`
2. `deep_6q`
3. `batch_obs_8q`
4. `state_reuse_8q_xy`
5. `sampled_counts_sparse_terms`

All timings are `per_op_ms` (lower is better).

## 3-Run Mean Results

### `baseline_2q`

| Framework lane | Mean ms/op | Std ms/op | Delta vs prior 2026-03-23 |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.020549 | 0.000273 | -16.93% |
| nxquantum[cpu_compiled] | 0.021589 | 0.000471 | -14.71% |
| qiskit | 0.101962 | 0.001068 | -1.02% |
| cirq | 0.338464 | 0.002757 | -0.47% |
| pennylane | 0.401617 | 0.003258 | +0.07% |

### `deep_6q`

| Framework lane | Mean ms/op | Std ms/op | Delta vs prior 2026-03-23 |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_compiled] | 0.174725 | 0.005026 | -4.29% |
| nxquantum[cpu_portable] | 0.175535 | 0.004133 | -3.39% |
| qiskit | 0.298657 | 0.000111 | -0.57% |
| cirq | 0.899298 | 0.012708 | +0.31% |
| pennylane | 1.125887 | 0.025928 | -1.62% |

### `batch_obs_8q`

| Framework lane | Mean ms/op | Std ms/op | Delta vs prior 2026-03-23 |
| --- | ---: | ---: | ---: |
| qiskit | 0.774400 | 0.005591 | -4.02% |
| nxquantum[cpu_compiled] | 1.552247 | 0.015490 | -61.79% |
| nxquantum[cpu_portable] | 1.573503 | 0.029564 | -61.21% |
| cirq | 4.673144 | 0.443031 | +3.06% |
| pennylane | 7.507932 | 0.079076 | -0.13% |

### `state_reuse_8q_xy`

| Framework lane | Mean ms/op | Std ms/op | Delta vs prior 2026-03-23 |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.001494 | 0.000008 | -99.56% |
| nxquantum[cpu_compiled] | 0.001515 | 0.000024 | -99.55% |
| qiskit | 0.015629 | 0.000183 | -0.79% |
| cirq | 0.195407 | 0.002325 | -1.62% |
| pennylane | 0.207452 | 0.011115 | +1.27% |

### `sampled_counts_sparse_terms`

| Framework lane | Mean ms/op | Std ms/op | Delta vs prior 2026-03-23 |
| --- | ---: | ---: | ---: |
| cirq | 0.081135 | 0.000312 | -1.52% |
| pennylane | 0.082464 | 0.000952 | +0.68% |
| nxquantum[cpu_portable] | 0.091866 | 0.000818 | -36.05% |
| nxquantum[cpu_compiled] | 0.092710 | 0.002382 | -34.77% |
| qiskit | 0.115184 | 0.001595 | -1.58% |

## Fastest Lane Per Scenario

| Scenario | Fastest lane | Mean ms/op |
| --- | --- | ---: |
| baseline_2q | nxquantum[cpu_portable] | 0.020549 |
| deep_6q | nxquantum[cpu_compiled] | 0.174725 |
| batch_obs_8q | qiskit | 0.774400 |
| state_reuse_8q_xy | nxquantum[cpu_portable] | 0.001494 |
| sampled_counts_sparse_terms | cirq | 0.081135 |

## NxQuantum vs Qiskit Snapshot (This Rerun)

| Scenario | NxQuantum best ms/op | Qiskit ms/op | Nx/Qiskit ratio |
| --- | ---: | ---: | ---: |
| baseline_2q | 0.020549 | 0.101962 | 0.202x |
| deep_6q | 0.174725 | 0.298657 | 0.585x |
| batch_obs_8q | 1.552247 | 0.774400 | 2.004x |
| state_reuse_8q_xy | 0.001494 | 0.015629 | 0.096x |
| sampled_counts_sparse_terms | 0.091866 | 0.115184 | 0.798x |

## Runtime-Profile Resolution Notes

1. `baseline_2q`: `requested=cpu_compiled resolved=cpu_portable`
1. `deep_6q`: `requested=cpu_compiled resolved=cpu_portable`
1. `batch_obs_8q`: `requested=cpu_compiled resolved=cpu_portable`
1. `state_reuse_8q_xy`: `requested=cpu_compiled resolved=cpu_portable`
1. `sampled_counts_sparse_terms`: `requested=cpu_compiled resolved=cpu_portable`

## Commands Used

```bash
for s in baseline_2q deep_6q batch_obs_8q state_reuse_8q_xy sampled_counts_sparse_terms; do
  for r in 1 2 3; do
    # scenario-specific iterations/warmup from docs
    .venv-bench/bin/python bench/python_alternatives_benchmark.py ... --scenario "$s" > tmp/bench_runs_2026-03-23_rerun/${s}_run${r}.txt
  done
done
```

