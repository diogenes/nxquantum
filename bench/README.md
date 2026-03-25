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

- `docs/v0.5-benchmark-matrix.md`

## Python Alternatives Comparison

Run NxQuantum against Qiskit, PennyLane, and Cirq on equivalent local workloads:

```bash
python3 -m venv .venv-bench
source .venv-bench/bin/activate
python -m pip install --upgrade pip
python -m pip install 'qiskit>=1.2,<2' 'pennylane>=0.38,<0.40' 'cirq-core>=1.3,<1.5'
python -m pip install 'autoray<0.7'
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

## Phase 20 Hybrid Quantum-AI (Planned)

Implementation-ready benchmark/dataset/API contracts:

- `docs/v1.0-hybrid-quantum-ai-benchmark.md`
- `docs/v1.0-hybrid-quantum-ai-integration-guide.md`

Planned benchmark scripts:

- `bench/hybrid_quantum_ai_benchmark.exs`
- `bench/hybrid_quantum_ai_baseline.exs`
- `bench/hybrid_quantum_ai_report.exs`

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
