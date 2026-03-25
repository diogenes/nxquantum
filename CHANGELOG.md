# Changelog

## [0.9.0] - 2026-03-25

### Added

- v0.9 roadmap closure for Phases 19-21 (Quantum AI tool contracts, hybrid benchmark pack, rollout gates) with docs and acceptance coverage.
- Phase A/B/C performance-gap closure plans and evidence docs:
  - `docs/v0.9-phase-a-sampled-scalar-plan.md`
  - `docs/v0.9-phase-b-fused-kernel-runtime-plan.md`
  - `docs/v0.9-phase-c-batch-gap-closure-plan.md`
  - `docs/python-alternatives-benchmark-2026-03-25.md`
- Runtime-profile fused-kernel guard coverage:
  - `test/nx_quantum/batch_fused_kernel_runtime_profile_guard_test.exs`

### Improved

- Sampled sparse-term benchmark lanes now make scalar vs helper strategy behavior explicit in `bench/nxquantum_python_comparison.exs`.
- Deterministic state-vector adapter now reuses bounded evolved-state cache for repeated circuit workloads (small-qubit safety envelope), significantly reducing repeated estimation latency.
- Roadmap Phase 18 closure tracker now includes phase-specific guard/evidence status updates for March 25, 2026.

### References

- [docs/roadmap.md](docs/roadmap.md)
- [docs/v0.9-high-value-performance-matrix.md](docs/v0.9-high-value-performance-matrix.md)
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

- [docs/v0.8-feature-spec.md](docs/v0.8-feature-spec.md)
- [docs/v0.8-provider-live-execution-plan.md](docs/v0.8-provider-live-execution-plan.md)
- [docs/v0.8-provider-capability-matrix.md](docs/v0.8-provider-capability-matrix.md)
- [docs/v0.8-compiler-implementation-plan.md](docs/v0.8-compiler-implementation-plan.md)
- [docs/v0.9-high-value-performance-matrix.md](docs/v0.9-high-value-performance-matrix.md)

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
- [docs/python-alternatives-benchmark-2026-03-23-rerun.md](docs/python-alternatives-benchmark-2026-03-23-rerun.md)
- [docs/v0.7-feature-spec.md](docs/v0.7-feature-spec.md)
- [docs/v0.7-acceptance-criteria.md](docs/v0.7-acceptance-criteria.md)
- [docs/v0.7-feature-to-step-mapping.md](docs/v0.7-feature-to-step-mapping.md)

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

- [docs/v0.5-feature-spec.md](docs/v0.5-feature-spec.md)
- [docs/v0.5-acceptance-criteria.md](docs/v0.5-acceptance-criteria.md)
- [docs/v0.5-provider-implementation-plan.md](docs/v0.5-provider-implementation-plan.md)
- [docs/v0.5-migration-packs.md](docs/v0.5-migration-packs.md)
- [docs/v0.5-benchmark-matrix.md](docs/v0.5-benchmark-matrix.md)
- [docs/v0.5-provider-support-tiers.md](docs/v0.5-provider-support-tiers.md)
