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

Run NxQuantum against Qiskit, PennyLane, and Cirq on equivalent local workloads.

### Environment

Python pins: `bench/requirements-python-alternatives.txt` is the exact `pip freeze` of the comparison environment (Python 3.13.16, qiskit 2.6.1, pennylane 0.45.1, cirq-core 1.7.0, numpy 2.5.4 and their transitive closure only; `pennylane-lightning` arrives as a pennylane requirement and no lightning lane is run), taken from the latest stable PyPI releases on 2026-10-26; pinning makes competitor versions reproducible and recorded with every result. The environment lives outside `mix.exs`, CI and Hex. Always run it as `.venv-bench/bin/python -I`.

```bash
mise exec python@3.13.16 -- python -m venv .venv-bench
.venv-bench/bin/python -I -m pip install -r bench/requirements-python-alternatives.txt
.venv-bench/bin/python -I -m pip freeze | diff - bench/requirements-python-alternatives.txt   # must be empty
```

### Scenario table and fixture (H1.3)

- `bench/scenarios/python_alternatives.json` is the single source of scenario ids, warmup and iteration counts, lane agreement states, tolerances, thread counts and the fixed-angle circuits. Both `bench/python_alternatives_benchmark.py` and `bench/nxquantum_python_comparison.exs` read it with stdlib JSON; an unknown scenario id raises in both.
- Agreement is gated per lane (`pass` or `fail`); only `cirq_c64` (the `cirq.Simulator()` default complex64) is `ungated`, and its untimed complex128 run `cirq_c128_equivalence` is gated at 1e-6.
- `"tolerances_confirmed": false` means timed mode refuses to run. The flag flips only after the owner confirms the tolerance reading and the physics seat signs off, in a separate commit.
- Width families `real_zbatch_<n>q` and `complex_zbatch_<n>q` (n = 4, 8, 12, 16, 20, 24; 8 layers) time a Z batch over every wire. Their structure is written in the table (`families`).
- `bench/scenarios/python_alternatives_fixture.json` (with `.sha256`) holds the angles as integers `k` (angle = k/1024, exact in float32 and float64): one distinct angle set per warmup and timed iteration, drawn with `numpy.random.Generator(PCG64(seed))`, seed = 20261026 + 100 * family_index + qubits. It also holds the prefix-parity analytic circuits and a 6-qubit self-check instance. Regenerate and verify byte identity:

```bash
.venv-bench/bin/python -I bench/scenarios/generate_python_alternatives_fixture.py
(cd bench/scenarios && shasum -a 256 -c python_alternatives_fixture.sha256)
```

### Running

The harness has four modes. Run Python only as `.venv-bench/bin/python -I` (the script refuses otherwise) and Elixir with the toolchain from `mise.toml` (`NXQ_BENCH_MIX_CMD="mix"` replaces the default `mise exec -- mix` when the shell already resolves the pinned toolchain).

Correctness first (`--mode check`, default). Every lane runs the real loop with `--check-warmup/--check-iterations` (default 1 and 3) and each timed iteration is compared with its own NumPy complex128 reference. Output is one `CHECK name=... status=pass|fail|ungated max_err=...` line per check (`agreement_<lane>_<family>_<n>`, `zz_...`, `sampled_counts_exact_rational`). Timings in this mode carry `timing=not_published`. `--max-qubits` defaults to 8; wider widths are only for a deliberate campaign.

```bash
.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --mode check --max-qubits 8 --out-dir <dir> --values-out <dir>/values.json
.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --compare-values <run1>/values.json <run2>/values.json   # values_byte_identical_runs
.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --mode selfcheck --max-qubits 8                         # reference checks
```

Self-checks (`--mode selfcheck`): `reference_selfcheck_dense_le6q` (NumPy reference vs `test/support/dense_reference.ex` exported by the `.exs`, at most 1e-12), `reference_selfcheck_prefix_parity` (analytic product of cosines, at most 1e-8, Python only), `reference_consensus_f64` (Qiskit, PennyLane, Cirq complex128 vs the reference, at most 1e-8), `sampled_counts_exact_rational` (exact `fractions.Fraction` reference over synthetic counts, at most 1e-6).

Timed mode (`--mode timed --cache-mode hot|cold`) refuses to run while `"tolerances_confirmed"` is `false` in the scenario table. Only a campaign with confirmed tolerances may use it. A timing row counts only if its lane passed agreement for that row; `cirq_c64` is ungated and published only where `cirq_c128_equivalence` passes. Budget pre-timing (`--mode pretime`) times one untimed iteration per (lane, family, width) and writes `pretime.json` with the 2 h per row and 8 h campaign rule applied; `cpu_compiled` is limited to 16 qubits.

Cache modes. `--cache-mode cold` builds one distinct angle set per iteration (warmup plus timed) before the timed loop in every lane and turns the NxQuantum result caches off (`cache_evolved_state: false`; for sampled counts `cache_parsed_counts: false, cache_mask_lookup_plan: false`); only structure-keyed caches stay warm. `hot` repeats one circuit and is allowed only at 10 qubits or fewer. `state_reuse_8q_xy` is a hot-only micro-benchmark (PennyLane and Cirq rows are Python helpers, not framework APIs). `sampled_counts_*` use synthetic counts. The 2 to 8 qubit continuity scenarios use fixed angles (angle-keyed plan memo warm) and are not headline rows.

Thread counts are fixed from the table (BEAM `+S`, `max_concurrency`, `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS`, `VECLIB_MAXIMUM_THREADS`) and written to `environment.txt` together with the `numerics_digest.exs --env-out` fields, Python and framework versions, the `pip freeze` hash, the NumPy BLAS configuration and the fixture sha256.

Known limits of the NxQuantum lane: it calls public facades only (`Circuit`, `Gates`, `Estimator`, `Runtime`). `sampled_counts_sparse_terms` needs the internal `SparsePauli` struct (no public facade), so its NxQuantum lane is not run; `sampled_counts_z_wires_8q` is the public-API sampled lane. The evolution path (RealPauliZ or Complex) is asserted by `test/nx_quantum/bench_cache_mode_guard_test.exs`, not by the bench.

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
