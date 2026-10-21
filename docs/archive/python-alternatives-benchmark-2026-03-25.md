# Python Alternatives vs NxQuantum Benchmark (2026-03-25)

## Scope

Fresh 3-run aggregation from `tmp/bench_runs_2026-03-25_phase_c_final/` for:

1. `baseline_2q`
2. `deep_6q`
3. `batch_obs_8q`
4. `state_reuse_8q_xy`
5. `sampled_counts_sparse_terms`

All timings are `per_op_ms` (lower is better).

## Lane semantics

1. Nx rows use exact runtime-profile resolution (`require_exact`).
2. For `sampled_counts_sparse_terms`:
   - `nxquantum[cpu_portable]` is scalar strategy lane (`sampled_parallel_mode: :force_scalar`).
   - `nxquantum[cpu_compiled]` is helper lane (`sampled_parallel_mode: :force_parallel`).
3. If fallback policy is relaxed (`allow_fallback`), interpret sampled lanes by `resolved_profile` instead of requested profile.

## 3-Run Mean Results

### `baseline_2q`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| nxquantum[cpu_portable] | 0.003687 | 0.000062 |
| nxquantum[cpu_compiled] | 0.003713 | 0.000070 |
| qiskit | 0.103362 | 0.000514 |
| cirq | 0.343231 | 0.003951 |
| pennylane | 0.406082 | 0.000950 |

### `deep_6q`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| nxquantum[cpu_portable] | 0.027408 | 0.000421 |
| nxquantum[cpu_compiled] | 0.027642 | 0.000375 |
| qiskit | 0.297377 | 0.000828 |
| cirq | 0.914840 | 0.012752 |
| pennylane | 1.103325 | 0.005207 |

### `batch_obs_8q`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| nxquantum[cpu_portable] | 0.155327 | 0.000844 |
| qiskit | 0.777838 | 0.002282 |
| nxquantum[cpu_compiled] | 2.024177 | 0.005740 |
| cirq | 4.463835 | 0.037264 |
| pennylane | 7.523154 | 0.021497 |

### `state_reuse_8q_xy`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| nxquantum[cpu_compiled] | 0.001486 | 0.000011 |
| nxquantum[cpu_portable] | 0.001488 | 0.000012 |
| qiskit | 0.015856 | 0.000248 |
| pennylane | 0.196332 | 0.003245 |
| cirq | 0.200716 | 0.002732 |

### `sampled_counts_sparse_terms`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| nxquantum[cpu_portable] (scalar) | 0.013683 | 0.000134 |
| cirq | 0.081622 | 0.000631 |
| pennylane | 0.082206 | 0.000446 |
| nxquantum[cpu_compiled] (helper) | 0.096307 | 0.004429 |
| qiskit | 0.116237 | 0.000907 |

## NxQuantum vs Qiskit Snapshot

| Scenario | NxQuantum best ms/op | Qiskit ms/op | Nx/Qiskit ratio |
| --- | ---: | ---: | ---: |
| baseline_2q | 0.003687 | 0.103362 | 0.036x |
| deep_6q | 0.027408 | 0.297377 | 0.092x |
| batch_obs_8q | 0.155327 | 0.777838 | 0.200x |
| state_reuse_8q_xy | 0.001486 | 0.015856 | 0.094x |
| sampled_counts_sparse_terms | 0.013683 | 0.116237 | 0.118x |

## Requested Threshold Checks

1. `batch_obs_8q`: Nx within 10% of Qiskit first, then beat target.
   - Result: **met** (`0.155327 / 0.777838 = 0.200x`; Nx is ~80.05% faster).
2. `sampled_counts_sparse_terms`: Nx scalar lane faster than helper lane by margin.
   - Result: **met** (`0.013683` vs `0.096307`; scalar lane is ~85.79% faster).

## Commands Used

```bash
for s in baseline_2q deep_6q batch_obs_8q state_reuse_8q_xy sampled_counts_sparse_terms; do
  for r in 1 2 3; do
    .venv-bench/bin/python bench/python_alternatives_benchmark.py \
      --iterations ... --warmup ... \
      --nx-runtime-profiles cpu_portable,cpu_compiled \
      --nx-profile-resolution-policy require_exact \
      --scenario "$s" \
      > tmp/bench_runs_2026-03-25_phase_c_final/${s}_run${r}.txt
  done
done
```
