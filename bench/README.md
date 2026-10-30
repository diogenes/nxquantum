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
- Agreement is gated per lane (`pass` or `fail`). Only `cirq_c64` (the `cirq.Simulator()` default complex64) is `ungated`, and only on state-based scenarios; its untimed complex128 run `cirq_c128_equivalence` is gated at 1e-6 and decides whether a Cirq row is published. On the sampled scenarios the PennyLane and Cirq rows are float64 Python helpers (no framework API), so `cirq_c64` is gated at 1e-6 there and publishable only when its own status is `pass`. A lane that raises is recorded as `status=error` (with the exception type and message) and the run continues; on a gated lane an error counts as a failure, and an `error` row is never publishable. A failed ZZ check fails its row and withholds the row's timing. Agreement returns `inf` (a fail) for NaN or non-finite values, a missing or extra row, and a short row.
- `"tolerances_confirmed": true` (with the record in `tolerance_confirmation`: reading `tol = max(1e-6, B)`, owner-delegated Lead decision 2026-10-30, physics sign-off) lets timed mode start. If the flag is `false`, timed mode refuses to run; `test/nx_quantum/bench_timed_refusal_test.exs` keeps that guard under test with a temp copy of the table.
- Tolerances for the NxQuantum lanes follow one written formula, `tol = max(1e-6, B rounded up to 2 significant figures)`, `B = (2 kappa G1 + c0) u`, `u = 2^-24` (inputs in `tolerance_formula`, derivation in `tolerances_note`). `test/nx_quantum/bench_tolerance_formula_test.exs` recomputes every family and continuity tolerance from it and asserts it equals the table value. The competitor lanes are gated at 1e-6.
- The four precision disclosures (NxQuantum, Qiskit, PennyLane, Cirq) and the methods line (PennyLane is timed through `qml.execute` on a pre-built tape; no QNode) are stored in the table (`disclosures`) and copied into `environment.txt`. The bracketed part of the Cirq sentence is a placeholder to fill from the run before any Cirq row is published.
- Width families `real_zbatch_<n>q` and `complex_zbatch_<n>q` (n = 4, 8, 12, 16, 20, 24; 8 layers) time a Z batch over every wire. Their structure is written in the table (`families`).
- `bench/scenarios/python_alternatives_fixture.json` (with `.sha256`) holds the angles as integers `k` (angle = k/1024, exact in float32 and float64): one distinct angle set per warmup and timed iteration, drawn with `numpy.random.Generator(PCG64(seed))`, seed = 20261026 + 100 * family_index + qubits. It also holds the prefix-parity analytic circuits and a 6-qubit self-check instance. The prefix-parity angles are deterministic, not drawn: `theta_w = (w+1)/64` (`k = 16(w+1)`) and, for the complex family, `phi_w = 2 theta_w` (`k = 32(w+1)`), which keeps every `|<Z_k>| = |prod_{j<=k} cos(theta_j)|` at or above 0.54 up to 24 qubits so the identity discriminates. Regenerate and verify byte identity:

```bash
.venv-bench/bin/python -I bench/scenarios/generate_python_alternatives_fixture.py
(cd bench/scenarios && shasum -a 256 -c python_alternatives_fixture.sha256)
```

### Running

The harness has four modes. Run Python only as `.venv-bench/bin/python -I` (the script refuses otherwise) and Elixir with the toolchain from `mise.toml` (the harness and the guard tests run plain `mix` from `PATH`; set `NXQ_BENCH_MIX_CMD="mise exec -- mix"` to go through mise, which needs a trusted `mise.toml`).

Correctness first (`--mode check`, default). Every lane runs the real loop with `--check-warmup/--check-iterations` (default 1 and 3) and each timed iteration is compared with its own NumPy complex128 reference. Output is one `CHECK name=... status=pass|fail|ungated|error max_err=...` line per check (`agreement_<lane>_<family>_<n>`, `zz_...`, `reference_consensus_f64_<family>_<n>`, `sampled_counts_exact_rational`) and a final `SUMMARY rows=... failures=... errors=...`. Timings in this mode carry `timing=not_published`. `--max-qubits` defaults to 8 when no `--scenario` is named; naming a scenario runs it at its own width (a deliberate choice, for example `--scenario real_zbatch_20q`).

Every agreement line also carries the discrimination columns: `max_abs_ref` (largest reference value in the row) and `discriminating=k/n` (observables whose reference stays at or above 10 times the row tolerance in every iteration). A row whose references sit near zero checks little, whatever its `max_err`. `baseline_2q` (analytic `<Z_1> = 0`) is continuity-only, and the X5/Y5 references of `state_reuse_8q_xy` are below 1e-16, so that scenario checks the plumbing of the state-reuse lanes, not values.

```bash
.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --mode check --max-qubits 8 --out-dir <dir> --values-out <dir>/values.json
.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --compare-values <run1>/values.json <run2>/values.json   # values_byte_identical_runs
.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --mode selfcheck --max-qubits 8                         # reference checks
```

Self-checks (`--mode selfcheck`): `reference_selfcheck_dense_le6q` (NumPy reference vs `test/support/dense_reference.ex` exported by the `.exs`, at most 1e-12), `reference_selfcheck_prefix_parity` (analytic product of cosines, at most 1e-8, Python only; also emits `min_abs_expected` and fails below 0.5), `reference_consensus_f64` (Qiskit, PennyLane, Cirq complex128 vs the reference, at most 1e-8; consensus is checked at 8 qubits or fewer in selfcheck, and per width in check and timed runs as `reference_consensus_f64_<family>_<n>`), `sampled_counts_exact_rational` (exact `fractions.Fraction` reference over synthetic counts, at most 1e-6), `harness_agreement_negative_cases` (NaN, infinity, a missing, extra or short row and an empty comparison must all be a `fail`).

Timed mode (`--mode timed --cache-mode hot|cold`) refuses to run while `"tolerances_confirmed"` is `false` in the scenario table (it is `true` since 2026-10-30). The timed campaign itself runs only at major releases (see "Major-release timed campaign"). A timing row counts only if its lane passed agreement for that row; `cirq_c64` is ungated and published only where `cirq_c128_equivalence` passes. Release-time helpers: `--mode pins` queries `pip index versions` for qiskit, pennylane, cirq-core and numpy and prints one `pins_current` line per package plus an `all=` summary against `requirements-python-alternatives.txt` (needs network; exit 1 if any pin is not the latest or the index is unreachable). `--mode consensus --results <a/results.json> <b/results.json> ...` computes `reference_consensus_f64_<family>_<n>` (bound 1e-8) across per-invocation `results.json` files, as needed when the campaign runs one lane per invocation, and fails when `qiskit`, `pennylane` or `cirq_c128_equivalence` is missing for a width that has rows. Budget pre-timing (`--mode pretime`) times one untimed iteration per (lane, family, width) and writes `pretime.json` with the 2 h per row and 8 h campaign rule applied; `cpu_compiled` is limited to 16 qubits.

Cache modes. `--cache-mode cold` builds one distinct angle set per iteration (warmup plus timed) before the timed loop in every lane and turns the NxQuantum result caches off (`cache_evolved_state: false`; for sampled counts `cache_parsed_counts: false, cache_mask_lookup_plan: false`); only structure-keyed caches stay warm. `hot` repeats one circuit and is allowed only at 10 qubits or fewer. `state_reuse_8q_xy` is a hot-only micro-benchmark. Each lane simulates the state once, untimed (NxQuantum: public `Estimator.run` with `cache_evolved_state: true`; Qiskit: `Statevector.from_instruction`, then `expectation_value` for X5 and Y5 in the timed region; PennyLane: the complex128 state of `qml.execute` with `qml.state()`; Cirq: `cirq.Simulator().simulate(...).final_state_vector`, with `cirq_c128_equivalence` on `Simulator(dtype=np.complex128)`). The PennyLane and Cirq timed region is the NumPy reference helper `ref_expectations` on that state, not a framework API. `sampled_counts_*` use synthetic counts. The 2 to 8 qubit continuity scenarios use fixed angles (angle-keyed plan memo warm) and are not headline rows.

Thread counts are fixed from the table (BEAM `+S 1:1`, `max_concurrency` 1, `OMP_NUM_THREADS`, `OPENBLAS_NUM_THREADS`, `MKL_NUM_THREADS`, `VECLIB_MAXIMUM_THREADS` all single-threaded for the headline); the harness fails a row if the NxQuantum subprocess reports different scheduler counts. Every row records `cpu_wall_lane_call` (`RUSAGE_SELF` delta for Python lanes, `RUSAGE_CHILDREN` delta for the NxQuantum subprocess, over the whole lane call, so NxQuantum startup is included) and a row above 1.1 is labelled. NxQuantum rows also carry `cpu_wall_timed_loop`: the `:erlang.statistics(:runtime)` delta (process CPU across all OS threads, millisecond resolution, so very short loops quantise to 0) over the `:timer.tc` wall time of the timed loop alone, without startup. Report the two figures separately. The thread settings are written to `environment.txt` together with the `numerics_digest.exs --env-out` fields, Python and framework versions, the `pip freeze` hash, the NumPy BLAS configuration and the fixture sha256.

Known limits of the NxQuantum lane: it calls public facades only (`Circuit`, `Gates`, `Estimator`, `Runtime`). `sampled_counts_sparse_terms` needs the internal `SparsePauli` struct (no public facade), so its NxQuantum lane is not run; `sampled_counts_z_wires_8q` is the public-API sampled lane. The evolution path (RealPauliZ or Complex) is asserted by `test/nx_quantum/bench_evolution_path_test.exs`, not by the bench.

NxQuantum benchmark scripts used by the Python harness:

- `bench/nxquantum_python_comparison.exs`

### Major-release timed campaign

When it runs. The multi-hour timed comparison runs at major releases only (owner decision, 2026-10-30), to confirm nothing regressed. It does not run per milestone or per PR. Between major releases the harness is exercised by `--mode check` and `--mode selfcheck` only; the committed correctness evidence is in `bench/results/2026-10-30-h1.3/` (`SUMMARY.md`). The tolerance reading (`tol = max(1e-6, B)`) was confirmed on 2026-10-30 and is recorded in `tolerance_confirmation` in the scenario table.

Steps, in order. Run Python as `.venv-bench/bin/python -I bench/python_alternatives_benchmark.py ...` with the toolchain from `mise.toml`.

1. `--mode pins`. If any pin is not current, bump `requirements-python-alternatives.txt`, rerun `--mode selfcheck --max-qubits 24` and `--mode check --max-qubits 8`, and get a new physics sign-off before continuing.
2. Confirm the physics sign-off still holds for the pinned versions. The four precision disclosures (NxQuantum, Qiskit, PennyLane, Cirq) and the methods line must still be true of the pinned versions, including the sentences about Cirq's single-precision norm and normalization check, PennyLane's `default.qubit` complex128 default, and the NxQuantum real-gate float64 path.
3. `--mode pretime` with the R4 budget rule: at most 2 h per (lane, family, width) and 8 h for the campaign (`budget` in the table), lanes in the committed `lane_order`, and `nxquantum_cpu_compiled` only at 16 qubits or fewer. A (lane, family, width) whose single-iteration estimate breaks the rule is dropped and recorded in `pretime.json`, not silently shortened.
4. Timed runs: 3 per scenario, one lane per invocation (`--mode timed --cache-mode hot|cold --lanes <lane> --scenario <id> --out-dir ...`). Hot rows only at 10 qubits or fewer.
5. `--mode consensus --results <a/results.json> <b/results.json> ...` across every per-invocation `results.json`. It must pass for every width with rows.
6. Fill the Cirq disclosure placeholder (the bracketed `<filled from the run>` text in `disclosures.cirq`) from the measured rows, such as the 20-qubit complex64 error recorded in `bench/results/2026-10-30-h1.3/cirq_c64_20q_error.txt` and whatever the timed run measures. Report what was measured, not an extrapolation.
7. Write `docs/python-alternatives-benchmark-<date>.md` per the plan: cold headline, hot rows at 10 qubits or fewer, the agreement and discrimination columns, the crossover qubit count per family and competitor, and the limits (single machine, single thread, pinned versions, 3-run spread).
8. Claims audit with `docs-sync`: every number traces to a committed `results.json`, and `grep -rn "<filled from the run>" docs/python-alternatives-benchmark-<date>.md` must show 0 hits in the report. The table placeholder must be filled before any Cirq row is published.

Outputs go to `bench/results/<first-run-date>-<release>/` with `pins.txt`, `selfcheck.txt`, `pretime.json`, one directory per invocation (`results.json`, `values.json`, `environment.txt`, logs), `consensus.txt` and a `SUMMARY.md`. Commit with a clean tree so `environment.txt` shows `git_dirty: false`; write outputs outside the repository during the run (an untracked output directory counts as dirty), and strip absolute paths, usernames and hostnames before committing.

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

## TTFR harness (time to first result)

`bench/ttfr/run.sh` runs the getting-started consumer flow from fresh empty
Mix/Hex/XDG homes and times each step: `mix local.hex`, `mix local.rebar`,
`mix new demo`, writing the deps line, `mix deps.get`, `mix compile`, and
`mix run` of the first-result snippet. The snippet is plain Elixir that
returns its value; the harness evaluates it and inspects the return value.
Success is exit 0 plus the expected value (exit 3 on mismatch). Elixir/OTP must already be installed;
human reading time is not measured. Results are an internal,
environment-specific reference.

```bash
bench/ttfr/run.sh --package-dir /path/to/unpacked/nx_quantum \
  --out bench/results/<date>/ttfr --label run1
```

The default snippet is
`test/fixtures/docs/getting_started_first_result.elixir` and the default
`--expect` is `[0.3623577356338501]`; override with `--snippet` and `--expect`.
Use `--dep '{:nx_quantum, "~> 0.12.0"}'` instead of `--package-dir` for Hex.
Rehearsal: `mix hex.build --unpack -o DIR` with `NXQ_ENABLE_EXLA=0
NXQ_ENABLE_TORCHX=0`. Evidence: `bench/results/2026-10-30-h1.5/ttfr/`.

Post-release step: once 0.12.0 is published, rerun 3 times with
`--dep '{:nx_quantum, "~> 0.12.0"}'`, the default
snippet and `--expect`, then commit the logs and a SUMMARY as the gate 2 evidence (max <= 600 s).
