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
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled
python bench/python_alternatives_benchmark.py --iterations 500 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario deep_6q
python bench/python_alternatives_benchmark.py --iterations 100 --warmup 10 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario batch_obs_8q
python bench/python_alternatives_benchmark.py --iterations 800 --warmup 50 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario state_reuse_8q_xy
python bench/python_alternatives_benchmark.py --iterations 2000 --warmup 100 --nx-runtime-profiles cpu_portable,cpu_compiled --scenario sampled_counts_sparse_terms
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

## Phase 20 Hybrid Quantum-AI (Planned)

Implementation-ready benchmark/dataset/API contracts:

- `docs/v1.0-hybrid-quantum-ai-benchmark.md`
- `docs/v1.0-hybrid-quantum-ai-integration-guide.md`

Planned benchmark scripts:

- `bench/hybrid_quantum_ai_benchmark.exs`
- `bench/hybrid_quantum_ai_baseline.exs`
- `bench/hybrid_quantum_ai_report.exs`
