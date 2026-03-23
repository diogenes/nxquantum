# Python Alternatives vs NxQuantum Benchmark (2026-03-23)

## Scope

This report captures 3-run means for existing cross-framework scenarios and adds stress scenarios aligned with recent math optimizations:

1. `baseline_2q`
2. `deep_6q`
3. `batch_obs_8q` (new): 8-qubit circuit with 48 Pauli terms (`X/Y/Z` cycle across wires), measuring multi-observable expectation throughput.
4. `state_reuse_8q_xy` (new): fixed 8-qubit state reused across 800 repeated `X/Y` expectation evaluations.
5. `sampled_counts_sparse_terms` (new): expectation from fixed sampled-count distribution with a 48-term diagonal sparse-Pauli sum.

All timings below are `per_op_ms` (lower is better).

## 3-Run Mean Results

### `baseline_2q`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| NxQuantum `cpu_portable` | 0.024738 | 0.000489 |
| NxQuantum `cpu_compiled` | 0.025312 | 0.000287 |
| Qiskit | 0.103014 | 0.000555 |
| PennyLane | 0.401323 | 0.004443 |
| Cirq | 0.340053 | 0.002288 |

### `deep_6q`

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| NxQuantum `cpu_portable` | 0.181695 | 0.000784 |
| NxQuantum `cpu_compiled` | 0.182561 | 0.001533 |
| Qiskit | 0.300359 | 0.001694 |
| PennyLane | 1.144440 | 0.004506 |
| Cirq | 0.896522 | 0.003963 |

### `batch_obs_8q` (new)

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| Qiskit | 0.806868 | 0.006272 |
| NxQuantum `cpu_portable` | 4.056387 | 0.170282 |
| NxQuantum `cpu_compiled` | 4.062437 | 0.025457 |
| Cirq | 4.534520 | 0.092964 |
| PennyLane | 7.517896 | 0.019261 |

### `state_reuse_8q_xy` (new)

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| Qiskit | 0.015754 | 0.000233 |
| Cirq | 0.198626 | 0.003574 |
| PennyLane | 0.204854 | 0.004858 |
| NxQuantum `cpu_compiled` | 0.334593 | 0.004095 |
| NxQuantum `cpu_portable` | 0.337249 | 0.005942 |

### `sampled_counts_sparse_terms` (new)

| Framework lane | Mean ms/op | Std ms/op |
| --- | ---: | ---: |
| PennyLane | 0.081905 | 0.000420 |
| Cirq | 0.082388 | 0.001317 |
| Qiskit | 0.117036 | 0.002539 |
| NxQuantum `cpu_compiled` | 0.142129 | 0.014911 |
| NxQuantum `cpu_portable` | 0.143656 | 0.010735 |

## Delta vs Previous Report (`2026-03-21`)

Reference: `docs/python-alternatives-benchmark-2026-03-21.md`.

1. `baseline_2q`: NxQuantum (`cpu_portable`) improved from `0.032224` to `0.024738` ms/op (`-23.23%`).
2. `deep_6q`: NxQuantum (`cpu_portable`) improved from `0.336410` to `0.181695` ms/op (`-45.99%`).
3. Qiskit also improved modestly (`baseline -9.62%`, `deep -4.38%`), but NxQuantum gained more.
4. NxQuantum remains ahead of Qiskit on baseline (`~4.16x`) and deep (`~1.65x`) scenarios.
5. New `batch_obs_8q` reveals a remaining gap where Qiskit is ahead of NxQuantum by ~`5.03x` on this machine.
6. New `state_reuse_8q_xy` reveals a larger gap: Qiskit is ahead of NxQuantum by ~`21.4x` (`0.337249 / 0.015754`) for this reuse-heavy micro path.
7. New `sampled_counts_sparse_terms` shows a smaller but material gap: NxQuantum is ~`1.23x` slower than Qiskit (`0.143656 / 0.117036`) on this machine.

## Micro-Benchmark: Same 8q State, 800 Iterations

Nx-only old-vs-new kernel path (`PauliExpval` vs dense matrix expectation):

| Metric | Mean ms | Std ms |
| --- | ---: | ---: |
| `X` new path | 186.801 | 17.992 |
| `X` old dense path | 22660.008 | 172.308 |
| `X` speedup (`old/new`) | 122.067x | 11.856 |
| `Y` new path | 299.546 | 16.510 |
| `Y` old dense path | 22541.409 | 71.510 |
| `Y` speedup (`old/new`) | 75.406x | 4.191 |

To avoid interference from the dense run in the same process, isolated new-only timings were also captured:

| Metric | Mean ms | Std ms |
| --- | ---: | ---: |
| `X` new-only | 98.125 | 2.654 |
| `Y` new-only | 189.458 | 10.376 |

Equivalent Qiskit same-state micro (`Statevector` + `Pauli` expectations):

| Metric | Mean ms | Std ms |
| --- | ---: | ---: |
| `X` | 6.210 | 0.080 |
| `Y` | 6.208 | 0.085 |

Interpretation:

1. The Nx bitmask path is massively better than the old dense Nx path.
2. For same-state repeated Pauli expectations, Qiskit remains significantly faster on this machine.
3. This class of benchmark should remain in the suite to prevent regressions and track parity progress.

## Commands Used

```bash
# Existing scenarios (3 runs each)
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario baseline_2q
python bench/python_alternatives_benchmark.py --iterations 500 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario deep_6q

# New cross-framework scenario (3 runs)
python bench/python_alternatives_benchmark.py --iterations 100 --warmup 10 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario batch_obs_8q
python bench/python_alternatives_benchmark.py --iterations 800 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario state_reuse_8q_xy
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario sampled_counts_sparse_terms
```

## Methodology Notes for New Scenarios

1. `state_reuse_8q_xy` intentionally precomputes a fixed state once and benchmarks repeated expectation calls over that same state.
2. `sampled_counts_sparse_terms` uses a fixed 8-bit counts payload and a deterministic 48-term diagonal sparse-Pauli operator.
3. For Qiskit sampled-count reduction, the benchmark uses `qiskit.result.sampled_expectation_value` with a `SparsePauliOp`.
4. PennyLane/Cirq do not expose an equivalent sampled-count expectation helper in this harness, so they use the same reference bitmask reduction routine for this scenario.

Raw outputs used for aggregation are stored under `tmp/bench_runs_2026-03-23/`.

## Post-Optimization Update (Quantum Kernel + Refactor Pass)

Date: 2026-03-23 (same machine class, 3-run means).

This update reflects:

1. `ExpectationPlan` precomputation and reuse for repeated Pauli evaluations.
2. Adaptive `ExecutionStrategy` selectors with chunked parallel execution.
3. `sampled_expval` decomposition into `ParsedCounts`, `MaskLookupCache`, and `CountsReducer`.
4. Compact parsed-count caching and sparse-mask lookup-plan caching.
5. Batch observable fast path improvements (duplicate term reuse, shared `X/Y` overlap reuse, shared `Z` probabilities reuse).

### Before/After (Nx `cpu_portable`)

| Scenario | Before ms/op | After ms/op | Improvement |
| --- | ---: | ---: | ---: |
| `state_reuse_8q_xy` | 0.337249 | 0.061838 | 5.45x faster |
| `sampled_counts_sparse_terms` | 0.143656 | 0.092153 | 1.56x faster |
| `batch_obs_8q` | 4.056387 | 2.282450 | 1.78x faster |

### Qiskit Parity Snapshot (After)

| Scenario | Nx `cpu_portable` ms/op | Qiskit ms/op | Nx vs Qiskit |
| --- | ---: | ---: | ---: |
| `state_reuse_8q_xy` | 0.061838 | 0.015315 | 4.04x slower |
| `sampled_counts_sparse_terms` | 0.092153 | 0.115866 | 20.47% faster |
| `batch_obs_8q` | 2.282450 | 0.770085 | 2.96x slower |

### Acceptance Check

1. `state_reuse_8q_xy` target (`>=4x` improvement): met (`5.45x`).
2. `sampled_counts_sparse_terms` target (within `+/-10%` of Qiskit): met (Nx is faster on this run set).
3. `batch_obs_8q` target (`>=2x` improvement): partially met (`1.78x`, short of target).

### Commands (Update Run)

```bash
python bench/python_alternatives_benchmark.py --iterations 800 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario state_reuse_8q_xy
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario sampled_counts_sparse_terms
python bench/python_alternatives_benchmark.py --iterations 100 --warmup 10 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario batch_obs_8q
```

### Raw Outputs (Update Run)

`tmp/bench_runs_2026-03-23_post_opt_release/`

### Risks and Assumptions

1. `batch_obs_8q` still carries a small-observable-kernel overhead gap versus Qiskit for this 8q/48-term shape.
2. `cpu_compiled` lane resolved to `cpu_portable` in these runs; comparisons above use measured lane outputs as reported by the harness.
3. Further progress on `batch_obs_8q` likely requires an explicit fused multi-term expectation kernel (single tensor program for many terms), rather than incremental per-term orchestration reductions.
