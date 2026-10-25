# Changelog

## [Unreleased]

### Added

- External envelope golden snapshots for every core provider (job, result, error) under `test/fixtures/contracts/envelopes/`, with a byte-level snapshot test.
- `NxQuantum.ProviderBridge.Serialization.from_external_map/1`: decodes stored `v1` job, result, and error envelopes; typed errors for unknown versions, types, states, codes, and operations.
- Round-trip and rehydrate-and-poll contract tests (`test/nx_quantum/contracts/envelope_decode_test.exs`).
- Envelope compatibility policy in `docs/api-stability.md`.
- Compiler semantic-equivalence property suites (H1.4): gate-identity catalogue, random circuits up to 6 qubits over three fixed seed sets, and routing equivalence. The oracle is an independent dense reference (`test/support/dense_reference.ex`).
- QFT reference test: the circuit matches the analytic DFT in float64 and `Nx.ifft` within a measured bound.
- `logical_to_physical_map` key in the `Transpiler` report: the final logical-to-physical wire map after routing (`nil` when no routing ran).

### Changed

- The single-precision numerics floor is documented in `docs/backend-support.md` ("Numerical Precision"). Decision recorded in roadmap KG-10: precision stays `complex64`, and the output dtype of `Circuit.expectation/2` is unchanged. Measured error against a float64 reference is at most 4.5e-7 over up to 6 qubits and depth 200 (`bench/numerics_precision_floor.exs`).

### Fixed

- `Transpiler.run/2` with `mode: :insert_swaps` now routes correctly. The CNOT is rewritten onto the routed coupled edge, and later gates follow the updated layout. Before, the output could keep a CNOT on an uncoupled edge, and gates after a routed interaction used stale wires. Callers that inspected the SWAP-prepend ordering or the original CNOT wires will see different operations. Use `report.logical_to_physical_map` to map observables onto physical wires.
- `NxQuantum.Compiler.optimize/2` with the `simplify` pass no longer raises on batched (non-scalar) rotation angles. A batched rotation is removed only when every angle is negligible.

- Deterministic job ids and observability fingerprints are now hashed with `:erlang.term_to_binary(_, [:deterministic])`. Map encoding order is no longer left to the VM. Job ids and fingerprint values for the same input may differ from 0.11.0.

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
