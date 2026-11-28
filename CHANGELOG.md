# Changelog

## [Unreleased]

Planned as 0.12.0. Not yet on Hex; 0.11.0 is the latest release.

### Toolchain

- CI, release, and the mise pin move to the latest patch releases: Elixir 1.20.5 / OTP 29.1.3 (from 1.20.4 / 29.1.2). The supported floor stays Elixir 1.19.1 / OTP 28.1. Nx stays at 1.0.0, which is the latest release of the dependency.

### Upgrading from 0.11.0

- Dependency currency (H1.6 PR-A, `api change`: the runtime dependency floor moved). Migration note:
  - What changed:
    - Runtime dependency `nx ~> 0.10` is now `nx ~> 1.0`.
    - Optional backends are `exla ~> 1.0` and `torchx ~> 1.0`. Env gating (`NXQ_ENABLE_EXLA`, `NXQ_ENABLE_TORCHX`) is unchanged.
    - The optional `axon` dependency is dropped. NxQuantum never called Axon; `docs/axon-integration.md` uses plain Nx. Axon users declare `axon` in their own `mix.exs`.
    - `complex` 1.x comes in through `nx` (was 0.6).
    - The Elixir requirement stays `~> 1.19`.
  - What did not change:
    - No NxQuantum function, type, option, error, or envelope changed. Envelope snapshots were not regenerated.
    - On the default `Nx.BinaryBackend`, the numerics digests and the precision table are bit-identical before and after, measured on one host (`bench/results/2026-10-26-h1.6/SUMMARY.md`). This bit-identity claim covers BinaryBackend only. EXLA and Torchx are covered by the tolerance-based tests, not by bit-identity.
  - A consumer on Nx 0.x fails at dependency resolution, not at runtime. With `{:nx_quantum, "~> 0.11"}` and `nx` held at 0.x, `mix deps.update` stays on 0.11.0. Requiring the next release fails version solving on `nx`.
  - To migrate: bump `nx` (and `exla` / `torchx`, if used) to `~> 1.0`, then run `mix deps.update nx exla torchx complex nx_quantum`. Fix your own code for the Nx 1.0 removals listed in the [Nx changelog](https://hexdocs.pm/nx/changelog.html). NxQuantum used none of them.
  - To stay on Nx 0.x: pin `{:nx_quantum, "~> 0.11.0"}`. No 0.11.x maintenance line is promised.
- Job ids and observability fingerprints are now hashed with `:erlang.term_to_binary(_, [:deterministic])`, so map encoding order is no longer left to the VM. Values for the same input may differ from 0.11.0. They are not guaranteed stable across OTP releases and may change across OTP majors; checked on OTP 28.1 and 29.1.2.
- `Transpiler.run/2` with `mode: :insert_swaps` produces different operations than 0.11.0 (see Fixed). Callers that inspected the SWAP-prepend ordering or the original CNOT wires are affected.
- The rerank dataset CSV reader (`dataset_path` input) now rejects paths outside the allowed roots (see Security).

### Security

- The rerank dataset CSV reader now accepts a `dataset_path` only under `bench/datasets` (resolved against the working directory) or `System.tmp_dir!/0`. Before, no path restriction applied: any readable path, for example `../../etc/passwd`, could be opened as a dataset. Paths in sibling directories that share a prefix with an allowed root (for example `bench/datasets_private/`) are also rejected. Other paths return `{:error, %{code: :ai_tool_invalid_request, field: :dataset_path, message: "unauthorized dataset path"}}`. Tests: `test/nx_quantum/ai/dataset_traversal_test.exs`.
- Migration: Hex consumers have no `bench/datasets`. Put the CSV under `bench/datasets` in the working directory, or under `System.tmp_dir!/0`.

### Added

- Option-key validation at `Estimator.run/2`, `Estimator.expectation_result/2`, and `Sampler.run/2` (KG-25 phase 1, `api change`). An unknown top-level key, such as `seeed: 7`, still returns the result it returned before, logs one `Logger.warning`, and adds `metadata.unknown_options` to results that have metadata. Rule and allow-list: `docs/api-stability.md` (Option Validation) and `lib/nx_quantum/option_keys.ex`. Phase 2 (typed error) follows in a later minor with a migration note.
- Noise channel domain types (H2.5, experimental, no executor yet): `NxQuantum.Noise.Channel` builds Kraus channels (depolarizing, amplitude damping, phase damping, Pauli, bit flip, phase flip, and generic `kraus/1`) with parameter and Kraus-completeness checks, and `NxQuantum.Noise.Model` maps gate names and qubits to channels. Tests: `test/nx_quantum/noise/`. The scalar `noise:` option is unchanged.
- `NxQuantum.Circuit.to_qasm/2`: OpenQASM 3 export over the `stdgates.inc` subset, with typed `:unsupported_qasm_construct` errors for anything outside it. Import is not included. Tests: `test/nx_quantum/interop/open_qasm3_test.exs`.
  - Slice 1 of H2.8: export only; round-trip, corpus agreement and typed-error gates are open.
  - api change (additive, experimental). Angles print the widened f32 value (for example `0.10000000149011612`), which is deterministic but not the user's decimal.
- External envelope golden snapshots for every core provider (job, result, error) under `test/fixtures/contracts/envelopes/`, with a byte-level snapshot test. A shape or meaning change requires a `schema_version` bump; compatibility policy in `docs/api-stability.md`.
- `NxQuantum.ProviderBridge.Serialization.from_external_map/1`: decodes stored `v1` job, result, and error envelopes; typed errors for unknown versions, types, states, codes, and operations. Round-trip and rehydrate-and-poll contract tests: `test/nx_quantum/contracts/envelope_decode_test.exs`.
- Compiler semantic-equivalence property suites (H1.4): gate-identity catalogue, random circuits up to 6 qubits over three fixed seed sets, and routing equivalence. The oracle is an independent dense reference (`test/support/dense_reference.ex`).
- QFT reference test: the circuit matches the analytic DFT in float64 and `Nx.ifft` within a measured bound.
- `logical_to_physical_map` key in the `Transpiler` report: the final logical-to-physical wire map after routing (`nil` when no routing ran).
- Livebooks (fixture and simulator lanes only): two new notebooks (supervised service, researcher reproducibility) and a reworked provider-bridge side-by-side notebook. `test/nx_quantum/livebooks_test.exs` (`mix test.livebooks`) evaluates all five notebooks twice and compares checkpoints to goldens. The surfaces they use beyond the stable tier stay experimental. The notebooks use a repository-relative setup cell until the Hex release.
- Experimental API tier in `docs/api-stability.md`, listing what the notebooks use beyond the stable tier.
- Time-to-first-result harness (`bench/ttfr/run.sh`) that checks the documented install flow from fresh directories. It is an onboarding check, not a speed benchmark.
- `Estimator.run/2` results carry `metadata.simulation` (experimental, additive) with `method`, `evolution_path` (`:real_pauli_z`, `:complex`, or `nil` when the state came from the evolved-state cache), `state_backend` (a neutral label: `:portable`, `:compiled`, `:other`, or `:mixed`), and `expectation_path` (`:fused_single_wire` or `:generic`). The simulator port reports these facts through its return value (`expectation_with_simulation/2`, `expectations_with_simulation/3`). Closes KG-20 once merged. Documented in `docs/backend-support.md` "Evolution Path Metadata". Tests: `test/nx_quantum/estimator_test.exs`.
- Mitigation passes `{:zne_richardson, scales:, values:, std_errors:}` (exact polynomial extrapolation of the supplied values) and `{:zne_poly_ls, scales:, values:, degree:, std_errors:}` (least-squares polynomial of degree below the point count, default 1). Both append `extrapolated_value` and, when `std_errors` are given, a linearly propagated `std_error` to the mitigation trace, and return typed `:invalid_mitigation_input` errors for too few points, duplicate scales (scales closer than 1.0e-9 count as duplicates), and degree at or above the point count. The `std_error` assumes independent per-point errors and an unweighted fit. Experimental; tests: `test/nx_quantum/mitigation/zne_extrapolation_test.exs`.
- H2.7 slice 1: extrapolation math only; no noisy-reference suite yet; H2.7 milestone stays open. `zne_poly_ls` refuses a least-squares fit whose Gram matrix condition number exceeds a tentative 1e16 with a typed `:ill_conditioned` error (new reason on an experimental pass). The threshold is not yet measured; tracked as H2.7 risk R1 in `docs/roadmap.md`.

### Changed

- AI tool result envelope: api change (schema v1 to v2 for success envelopes; error envelope stays v1). `schema_version` is now `"v2"` for success results (KG-12). The bundled `quantum-kernel reranking` / `quantum_kernel_rerank.v1` and `constrained optimization helper` handlers computed classically but reported `execution.mode: :quantum`; they now report `execution.mode: :classical` with `provider: :none` and `target: :none`. `:classical_fallback` is unchanged. Migration note:
  - What changed: a successful bundled call returns `mode: :classical` where 0.11.0 returned `:quantum`. The `status` is still `:ok`.
  - Consumers that treat `execution.mode == :quantum` as evidence of quantum execution must stop doing so. A `:quantum` result from the bundled handlers no longer exists.
  - Consumers that match on `schema_version: "v1"` for AI results must accept `"v2"`. Error envelopes keep `"v1"`.
  - Tool names and request envelopes are unchanged. `docs/quantum-ai-tool-contracts.md` no longer names `constrained_optimize.v1` / `constrained_optimize.ex`; the real names are `constrained optimization helper` and `lib/nx_quantum/ai/tool_runner.ex`.
- README, getting-started, and positioning lead with deterministic quantum execution on BEAM (decision D1); hybrid quantum-AI is presented as an application of it. "Deterministic" is scoped to simulator and fixture lanes. Cross-framework speed claims are removed from the README (owner decision 2026-10-30). The Hex package description is updated (`mix.exs`).
- The case study (`docs/case-study-beam-integration.md`) is an illustrative pattern, not a user report, and reports no performance figures.
- Rerank dataset manifests under `bench/datasets/rerank/` carry `provenance: synthetic`; the guard test (`test/nx_quantum/hybrid_quantum_ai_benchmark_guard_test.exs`) checks it, and the docs label these datasets synthetic (roadmap KG-5).
- The single-precision numerics floor is documented in `docs/backend-support.md` ("Numerical Precision"). Decision recorded in roadmap KG-10: precision stays `complex64`, and the output dtype of `Circuit.expectation/2` is unchanged. Measured error against a float64 reference is at most 4.5e-7 over up to 6 qubits and depth 200 (`bench/numerics_precision_floor.exs`).
- Cross-framework benchmark harness rebuilt: pinned Python environment, one scenario table, correctness gates, defined cold mode. No timings are published; the timed comparison runs at major releases (owner decision 2026-10-30). The 2026-03-25 report is a historical internal reference with superseded methodology.
- Documentation consolidated, with history under `docs/archive/` (roadmap KG-8). Known Gaps KG-11..29 are documented in `docs/roadmap.md`.
- Lead message refined to "Deterministic quantum simulation and execution on BEAM" (decision PD-1, refining D1), including the Hex package description. A documentation map (`docs/README.md`) and grouped HexDocs sidebar replace the flat docs lists; the `docs/decision-matrix.md` pointer stub is removed (merged into `docs/product-positioning.md` on 2026-10-30).
- The Estimator `noise:` option is documented as a scalar model, not a noise channel (roadmap KG-30). Behaviour is unchanged.
- Roadmap: Horizon 2 restructured into an engine track (H2.4 engine v2 with opt-in float64, H2.8 OpenQASM 3, H2.5 noise channels and deterministic trajectories) and a differentiator track (H2.1 re-scoped as a deterministic ensemble executor, H2.7 mitigation v2, H2.6 Pauli propagation, H2.9 Hamiltonian simulation and SQD/SKQD); H1.7 claims and option hygiene added; H2.2 circuit cutting parked; ADR 0013 (simulation-method port) proposed. Planning only; no code change.
- Toolchain currency (H1.6 PR-B). Development and CI move to Elixir 1.20.4 / OTP 29.1.2 (`mise.toml`, `.github/workflows/ci.yml`, `.github/workflows/release.yml`). The supported floor stays `elixir: "~> 1.19"` on OTP 28, tested by a new CI floor job (Elixir 1.19.1 / OTP 28.1, optional backends off). No public API change. Two clauses the 1.20 type checker proves unreachable were removed (`ProviderBridge.Serialization.stringify_value/1` for `Nx.Tensor`, `Observability.Schema.validate_redaction/1` catch-all); behavior is unchanged. BinaryBackend numerics and envelope snapshots are byte-identical on OTP 29 (`bench/results/2026-10-26-h1.6/SUMMARY.md`).
- CI and internal: the release workflow now builds docs in the dev env (`ex_doc` is not available in prod).
- Internal: a single-use private function in `NxQuantum.Circuit` was inlined, and wire deduplication in the fused single-wire Pauli expectation path was rewritten as an equivalent `Enum.uniq_by`. No user-visible change intended; no performance claim.

### Removed

- The optional `axon` dependency. See the migration note under "Upgrading from 0.11.0".

### Fixed

- `Transpiler.run/2` with `mode: :insert_swaps` now routes correctly. The CNOT is rewritten onto the routed coupled edge, and later gates follow the updated layout. Before, the output could keep a CNOT on an uncoupled edge, and gates after a routed interaction used stale wires. Callers that inspected the SWAP-prepend ordering or the original CNOT wires will see different operations. Use `report.logical_to_physical_map` to map observables onto physical wires.
- `NxQuantum.Compiler.optimize/2` with the `simplify` pass no longer raises on batched (non-scalar) rotation angles. A batched rotation is removed only when every angle is negligible.
- Evolved-state cache eviction follows a monotonic insertion sequence instead of millisecond timestamps, so the eviction order no longer depends on timestamp ties. Simulation results are unchanged.
- The state-vector structure cache (CNOT permutations, observable masks, compiled plans) is capped by bytes as well as by its 4096-entry count (KG-17). The byte budget is `Application.get_env(:nx_quantum, :state_vector_structure_cache_max_bytes)`, default 512 MiB. Entries over the budget are not retained. When the byte budget needs room, the oldest entries (by insertion order) are evicted first. When the 4096-entry count is reached, one entry is removed by `:ets.first`, which follows hash order on the `:set` table and is not necessarily the oldest. Simulation results are unchanged, and a 24-qubit CNOT permutation (about 128 MiB) is no longer kept without limit. On the cache-miss path, the CI benchmark (`bench/results/kg17-2026-11-26.txt`) measured a +2.2% median delta (+1962.9 ms, 20 qubits, fixed seed); the eviction path, which this benchmark does not reach, is unmeasured.

### References

- `docs/roadmap.md`, `docs/api-stability.md`, `docs/getting-started.md`

## [0.11.0] - 2026-03-29

### Added

- Roadmap Phase 22/23 implementation closure under the `0.x` versioning track (`v0.10` + `v0.11` roadmap labels).
- TurboQuant-inspired deterministic rerank compression path with versioned tool-name compatibility:
  - `quantum-kernel reranking`
  - `quantum_kernel_rerank.v1`
- CSV dataset onboarding for rerank workflows with typed validation (`--dataset-path`, `--query-id`).
- AI rollout gate KPI checks for TurboQuant production promotion decisions.

### Improved

- Benchmark/evidence coverage for TurboQuant rerank lanes (quality, latency, memory) across hybrid benchmark scripts and guard lanes.
- User/operator guidance for benchmark integration and rollout playbooks aligned to hybrid quantum-AI contracts.

### References

- [docs/roadmap.md](docs/roadmap.md)
- [docs/hybrid-quantum-ai-benchmark.md](docs/hybrid-quantum-ai-benchmark.md)
- [docs/hybrid-quantum-ai-integration-guide.md](docs/hybrid-quantum-ai-integration-guide.md)
- [docs/turboquant-rerank-guide.md](docs/turboquant-rerank-guide.md)

## [0.9.1] - 2026-03-29

### Added

- Runtime auto-selection support for estimator paths (`runtime_profile: :auto`) with deterministic lane-selection reasons in result metadata.
- Hot/cold cache-mode benchmark harness lanes and blocking/non-blocking guard semantics for `batch_obs_8q`.

### Improved

- Compiled fused-kernel cost profile via reusable per-wire compiled scaffolding while preserving numeric parity and eligibility/fallback behavior.
- Evolved-state cache policy with byte-aware cap + TTL + deterministic oldest-first eviction for repeated state-vector workloads.
- Estimator strategy observability metadata coverage and CI guard tightening for hot-lane performance protection.

### References

- [docs/roadmap.md](docs/roadmap.md)
- [docs/performance-matrix.md](docs/performance-matrix.md)
- [docs/archive/v0.9-phase-a-sampled-scalar-plan.md](docs/archive/v0.9-phase-a-sampled-scalar-plan.md)
- [docs/archive/v0.9-phase-b-fused-kernel-runtime-plan.md](docs/archive/v0.9-phase-b-fused-kernel-runtime-plan.md)
- [docs/archive/v0.9-phase-c-batch-gap-closure-plan.md](docs/archive/v0.9-phase-c-batch-gap-closure-plan.md)

## [0.9.0] - 2026-03-25

### Added

- v0.9 roadmap closure for Phases 19-21 (Quantum AI tool contracts, hybrid benchmark pack, rollout gates) with docs and acceptance coverage.
- Phase A/B/C performance-gap closure plans and evidence docs:
  - `docs/archive/v0.9-phase-a-sampled-scalar-plan.md`
  - `docs/archive/v0.9-phase-b-fused-kernel-runtime-plan.md`
  - `docs/archive/v0.9-phase-c-batch-gap-closure-plan.md`
  - `docs/python-alternatives-benchmark-2026-03-25.md`
- Runtime-profile fused-kernel guard coverage:
  - `test/nx_quantum/batch_fused_kernel_runtime_profile_guard_test.exs`

### Improved

- Sampled sparse-term benchmark lanes now make scalar vs helper strategy behavior explicit in `bench/nxquantum_python_comparison.exs`.
- Deterministic state-vector adapter now reuses bounded evolved-state cache for repeated circuit workloads (small-qubit safety envelope), significantly reducing repeated estimation latency.
- Roadmap Phase 18 closure tracker now includes phase-specific guard/evidence status updates for March 25, 2026.

### References

- [docs/roadmap.md](docs/roadmap.md)
- [docs/performance-matrix.md](docs/performance-matrix.md)
- [docs/python-alternatives-benchmark-2026-03-25.md](docs/python-alternatives-benchmark-2026-03-25.md)

## [0.8.0] - 2026-03-24

### Added

- Provider transport contract now includes explicit `:live` mode with deterministic envelope parity (`schema_version`, `request_id`, `correlation_id`, `idempotency_key`).
- Live transport adapter seam for provider lifecycle operations and replay fixture capture tooling for deterministic regression lanes.
- Compiler target contract (`NxQuantum.Compiler.Target`) and additive `compile/2` diagnostics contract with optimization/routing/scheduling/cost-profile reporting.
- Observability metadata policy and troubleshooting bundle export contract for machine-consumable incident evidence.
- High-value performance matrix scripts, deterministic dataset manifests, and CI guard tests for scenario and provider-lifecycle latency coverage.

### Improved

- Provider bridge envelope contracts include versioned `request_id` serialization across job/result/error payloads.
- Feature-step coverage now includes Phase 18 matrix scenarios `baseline_2q` and `deep_6q`.
- HexDocs extras include v0.8 and v0.9 milestone evidence docs.

### References

- [docs/archive/v0.8-feature-spec.md](docs/archive/v0.8-feature-spec.md)
- [docs/archive/v0.8-provider-live-execution-plan.md](docs/archive/v0.8-provider-live-execution-plan.md)
- [docs/provider-support-catalog.md](docs/provider-support-catalog.md)
- [docs/archive/v0.8-compiler-implementation-plan.md](docs/archive/v0.8-compiler-implementation-plan.md)
- [docs/performance-matrix.md](docs/performance-matrix.md)

## [0.7.0] - 2026-03-23

### Added

- Versioned provider envelope serialization helpers for external operations interoperability (`schema_version`, deterministic correlation/idempotency context).
- Observability schema governance validation for profile-stable span/metric/log contracts.
- Standalone production and external integration profile guide with release-evidence checks.
- Fresh cross-framework benchmark rerun report for NxQuantum vs Qiskit/PennyLane/Cirq.

### Improved

- Provider lifecycle envelopes now carry explicit contract-version metadata in deterministic form.
- Release evidence workflow now includes dedicated contract/schema benchmark and validation lanes.

### References

- [docs/standalone-integration-profiles.md](docs/standalone-integration-profiles.md)
- [docs/archive/python-alternatives-benchmark-2026-03-23-rerun.md](docs/archive/python-alternatives-benchmark-2026-03-23-rerun.md)
- [docs/archive/v0.7-feature-spec.md](docs/archive/v0.7-feature-spec.md)
- [docs/archive/v0.7-acceptance-criteria.md](docs/archive/v0.7-acceptance-criteria.md)
- [docs/archive/v0.7-feature-to-step-mapping.md](docs/archive/v0.7-feature-to-step-mapping.md)

## [0.5.0] - 2026-03-22

### Added

- Top-3 provider bridges for `IBM Runtime`, `AWS Braket`, and `Azure Quantum` with typed lifecycle contracts.
- Cross-provider capability preflight and normalized error taxonomy.
- OpenTelemetry observability profiles (`high_level`, `granular`, `forensics`) plus deterministic fingerprint and portability telemetry contracts.
- Provider migration packs, support tiers, and reproducible provider benchmark matrix for v0.5 release evidence.

### Improved

- State-vector execution planning and hot-path performance, including real-only fast path for compatible `:pauli_z` workflows.
- Deep-circuit benchmark latency (`deep_6q`) with new planning and evolution optimizations.

### Docs

- v0.5 feature spec, acceptance criteria, provider implementation plan, migration packs, benchmark matrix, and observability guides finalized.

### References

- [docs/archive/v0.5-feature-spec.md](docs/archive/v0.5-feature-spec.md)
- [docs/archive/v0.5-acceptance-criteria.md](docs/archive/v0.5-acceptance-criteria.md)
- [docs/archive/v0.5-provider-implementation-plan.md](docs/archive/v0.5-provider-implementation-plan.md)
- [docs/migration-packs.md](docs/migration-packs.md)
- [docs/provider-benchmark-matrix.md](docs/provider-benchmark-matrix.md)
- [docs/provider-support-catalog.md](docs/provider-support-catalog.md)
