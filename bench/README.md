# Benchmark Suite

This directory contains deterministic benchmark scenarios for v0.2 milestones.

## Milestone B (P1)

Run:

```bash
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mise exec -- mix run bench/milestone_b.exs
```

Baseline report:

- `bench/milestone_b_baseline.md`

## Milestone G (v0.4 P1)

Run:

```bash
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mise exec -- mix run bench/milestone_g.exs
```

Baseline report:

- `bench/milestone_g_baseline.md`

## Milestone K (v0.5 P2)

Run:

```bash
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mise exec -- mix run bench/milestone_k.exs
```

Reference evidence:

- `docs/provider-benchmark-matrix.md`

## Python Alternatives Comparison

Run NxQuantum against Qiskit, PennyLane, and Cirq on equivalent local workloads:

Python pins: `bench/requirements-python-alternatives.txt` is the exact `pip freeze` of the comparison environment (Python 3.13.16, qiskit 2.6.1, pennylane 0.45.1, cirq-core 1.7.0, numpy 2.5.4 and their transitive closure only), taken from the latest stable PyPI releases on 2026-10-26; pinning makes competitor versions reproducible and recorded with every result. The environment lives outside `mix.exs`, CI and Hex. Always run it as `.venv-bench/bin/python -I`.

```bash
mise exec python@3.13.16 -- python -m venv .venv-bench
.venv-bench/bin/python -I -m pip install -r bench/requirements-python-alternatives.txt
.venv-bench/bin/python -I -m pip freeze | diff - bench/requirements-python-alternatives.txt   # must be empty
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact
python bench/python_alternatives_benchmark.py --iterations 500 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario deep_6q
python bench/python_alternatives_benchmark.py --iterations 100 --warmup 10 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario batch_obs_8q
python bench/python_alternatives_benchmark.py --iterations 800 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario state_reuse_8q_xy
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario sampled_counts_sparse_terms
```

Cache mode lanes for NxQuantum (`--nx-cache-mode hot|cold`, default: `hot`):

```bash
python bench/python_alternatives_benchmark.py --iterations 500 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario deep_6q --nx-cache-mode hot
python bench/python_alternatives_benchmark.py --iterations 500 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario deep_6q --nx-cache-mode cold
python bench/python_alternatives_benchmark.py --iterations 100 --warmup 10 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario batch_obs_8q --nx-cache-mode hot
python bench/python_alternatives_benchmark.py --iterations 100 --warmup 10 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario batch_obs_8q --nx-cache-mode cold
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario sampled_counts_sparse_terms --nx-cache-mode hot
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy require_exact --scenario sampled_counts_sparse_terms --nx-cache-mode cold
```

Sampled sparse-term lane semantics (`sampled_counts_sparse_terms`):

- `nxquantum[cpu_portable]` => scalar reducer lane (`:force_scalar`)
- `nxquantum[cpu_compiled]` => helper/parallel lane (`:force_parallel`)
- This lane mapping is guaranteed under `--nx-profile-resolution-policy require_exact`; with fallback enabled, interpret lanes by `resolved_profile`.

If you intentionally want fallback-lane measurements (requested profile may resolve to a different runtime profile), run with:

```bash
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --nx-profile-resolution-policy allow_fallback
```

NxQuantum benchmark scripts used by the Python harness:

- `bench/nxquantum_python_comparison.exs`

## Numerical Precision Floor (KG-10)

Measures production expectation error against a float64 dense reference over fixed-seed random circuits. Results are documented in `docs/backend-support.md` ("Numerical Precision"):

```bash
MIX_ENV=test mix run bench/numerics_precision_floor.exs
```

## Numerics Digest (H1.6)

`bench/numerics_digest.exs` prints SHA-256 prefixes over a canonical encoding of fixed-seed outputs (optimized ops, expectations, the float64 reference, sampler counts, gradients, the kernel matrix, raw Nx complex primitives). Two runs on the same toolchain and lock must be byte-identical. Compare states by diffing the outputs. Only public APIs are called.

`--env-out <path>` also writes the environment block (date, OS, CPU, toolchain, dependency versions, env flags, git HEAD, default backend) to that file. The environment never goes to stdout.

```bash
MIX_ENV=test mix run bench/numerics_digest.exs --env-out bench/results/<run-date>-<milestone>/<state>/environment.txt > bench/results/<run-date>-<milestone>/<state>/digest_run1.txt
```

## Results Convention

Evidence runs are stored in `bench/results/<first-run-date>-<milestone>/<state>/`. Each state directory holds:

- `digest_run1.txt` and `digest_run2.txt` (two digest runs),
- `precision_run1.txt` and `precision_run2.txt` (two `numerics_precision_floor.exs` runs),
- `environment.txt` (generated with `--env-out`),
- `batch_obs_guard.txt`.

The milestone directory also holds a `SUMMARY.md`. Each state records its own run date in its `environment.txt`; do not assume one date for all states. Example: `bench/results/2026-10-26-h1.6/`.

## Parallel Opportunity Scripts

Estimator and sampler batch/parallel opportunity probes:

```bash
mise exec -- mix run bench/nxquantum_parallel_opportunity.exs 4000
mise exec -- mix run bench/nxquantum_parallel_opportunity_sampler.exs 4000
```

## Estimator Batch Strategy Regression

Deterministic multi-observable estimator strategy benchmark
(shared-state batch strategy vs scalar loop baseline):

```bash
mise exec -- mix run bench/nxquantum_estimator_batch_strategy.exs 2000 48 8
```

Hot/cold guard lanes (`batch_obs_8q`):

```bash
mise exec -- mix run bench/batch_obs_regression_guard.exs
mise exec -- mix run bench/batch_obs_hot_cold_guard.exs
```

## Phase 20 Hybrid Quantum-AI

Evidence limits (2026-10-26): the in-repo rerank datasets (`rq_small_v1`, `rq_medium_v1`) are synthetic, 6- and 8-row hand-authored fixtures; contract and regression smoke checks only; not evidence of rerank quality. Quality and KPI figures (nDCG, MAP, objective gap, `quality_drop`, `memory_bytes_per_vector`, `compression_ratio_vs_fp32`) and all `latency_fallback_impact` metrics emitted by `bench/hybrid_quantum_ai_benchmark.exs` and `bench/hybrid_quantum_ai_baseline.exs` are fixed values written into the scripts: placeholders, not measurements. The rerank lanes of `bench/hybrid_quantum_ai_benchmark.exs` report `dataset_id: "rq_small_v1"` without loading it; the TurboQuant lane loads data only when `--dataset-path` is given (KG-11 in `docs/roadmap.md`). These are internal references, not official benchmark results.

Benchmark/dataset/API contracts:

- `docs/hybrid-quantum-ai-benchmark.md`
- `docs/hybrid-quantum-ai-integration-guide.md`

Benchmark scripts:

- `bench/hybrid_quantum_ai_benchmark.exs`
- `bench/hybrid_quantum_ai_baseline.exs`
- `bench/hybrid_quantum_ai_report.exs`
- `bench/turboquant_rerank_benchmark.exs`

TurboQuant rerank lanes (deterministic fixture-first):

```bash
mise exec -- mix run bench/hybrid_quantum_ai_benchmark.exs rerank_quality_delta_turboquant
mise exec -- mix run bench/turboquant_rerank_benchmark.exs
```

Bring-your-own dataset lanes:

```bash
mise exec -- mix run bench/hybrid_quantum_ai_benchmark.exs rerank_quality_delta_turboquant --dataset-path bench/datasets/rerank/rq_small_v1.csv --query-id q-1 --dataset-id rq_small_v1
mise exec -- mix run bench/turboquant_rerank_benchmark.exs --dataset-path bench/datasets/rerank/rq_medium_v1.csv --query-id q-42 --bit-width 4
```

## Phase 18 High-Value Performance Matrix

Run deterministic high-value simulation scenarios:

```bash
mise exec -- mix run bench/high_value_performance_matrix.exs baseline_2q 200
mise exec -- mix run bench/high_value_performance_matrix.exs deep_6q 200
mise exec -- mix run bench/high_value_performance_matrix.exs state_reuse_8q_xy 200
mise exec -- mix run bench/high_value_performance_matrix.exs batch_obs_8q 200
mise exec -- mix run bench/high_value_performance_matrix.exs sampled_counts_sparse_terms 200
mise exec -- mix run bench/high_value_performance_matrix.exs shot_sweep_param_grid_v1 200
```

Provider lifecycle latency lanes:

```bash
mise exec -- mix run bench/provider_lifecycle_latency_fixture.exs 100
mise exec -- mix run bench/provider_lifecycle_latency_live.exs live_smoke 20
mise exec -- mix run bench/provider_lifecycle_latency_live.exs live 20
```
