# NxQuantum Roadmap

## Phase 0 - Foundation (current)

- [x] Project scaffolding.
- [x] Architecture docs + ADR baseline.
- [x] API and behavior skeletons.
- [x] Feature spec definitions.
- [x] v0.2 feature specification draft.
- [x] v0.2 improvement plan draft.

## Phase 1 - v0.2 P0: Correctness + Runtime Profiles

- [x] Implement deterministic 1-2 qubit state-vector evolution with analytical reference scenarios.
- [x] Implement expectation values for Pauli observables (`:pauli_x`, `:pauli_y`, `:pauli_z`).
- [x] Add property tests for normalization and gate composition (1-2 qubits).
- [x] Stabilize runtime profile contract (`cpu_portable`, `cpu_compiled`, `nvidia_gpu_compiled`, `torch_interop_runtime`).
- [x] Implement deterministic fallback policy (`strict`, `allow_cpu_compiled`).
- [x] Add executable feature scenarios for backend and hybrid-training deterministic behavior.

Milestone A review gate (before Phase 2):

1. Feature scenarios explicitly cover 1-2 qubit deterministic evolution and Pauli expectation references.
2. Property coverage includes both gate-composition invariants and state normalization invariants.
3. Runtime profile/fallback behaviors are covered by executable deterministic scenarios.

## Phase 2 - v0.2 P1: Differentiation, Noise, and Optimization

- [x] Move gate application path into `Nx.Defn` kernels.
- [x] Add gradient modes (`backprop`, `parameter_shift`, optional `adjoint`).
- [x] Add seeded shots and initial noise channels.
- [x] Add deterministic circuit optimization pass pipeline.
- [x] Add benchmark suite and baseline reports.

Milestone B review gate (before Phase 3):

1. Simulator gate application and expectation hot paths execute via explicit `Nx.Defn` kernels.
2. Differentiation modes (`backprop`, `parameter_shift`, `adjoint`) are covered by deterministic acceptance tests.
3. Seeded shot sampling and initial noise channels (depolarizing + amplitude damping) are covered by executable scenarios/tests.
4. Optimization pipeline (`simplify`, `fuse`, `cancel`) preserves expectations and emits deterministic reduction reports.
5. Benchmark suite and baseline report are committed under `bench/` with reproducible run instructions.

## Phase 3 - v0.2 P2: Advanced ML Workflows

- [x] Quantum kernel matrix generation API.
- [x] Axon layer integration polish and end-to-end examples.
- [x] Additional model recipes and tutorials.

Milestone C review gate (before Phase 4):

1. `NxQuantum.Kernels.matrix/2` provides deterministic, seed-aware kernel matrix generation.
2. Kernel matrix workflows are validated by executable feature and unit coverage (shape, symmetry, PSD/reproducibility).
3. Axon integration workflow is documented with end-to-end runnable examples.
4. Additional model recipes/tutorial docs are published and linked from the README.

## Phase 4 - Ecosystem Readiness

- [x] API stabilization.
- [x] HexDocs polish.
- [x] CI/CD and release automation.

Milestone D review gate (before Phase 5):

1. Public stable/experimental API contract is documented and guarded by executable contract tests.
2. HexDocs navigation includes advanced integration/recipe/release guidance.
3. CI validates core quality gates and backend smoke lanes with deterministic environment toggles.
4. Release automation workflow builds package/docs artifacts on tags/manual dispatch.

## Phase 5 - v0.3: Hardware-Ready Primitives and Batch Workflows

- [x] Ship stable `Estimator` and `Sampler` primitives with deterministic typed contracts.
- [x] Add batched PQC execution as a first-class API path.
- [x] Add pluggable mitigation pipeline (readout + ZNE baseline).
- [x] Add topology-aware transpilation interface with deterministic shortest-path routing.
- [x] Add dynamic-circuit IR foundation (validation + metadata) with explicit no-execution boundary.
- [x] Publish v0.3 spec and feature-to-step mappings.

Milestone E review gate (v0.3 foundation):

1. Primitive facades (`Estimator`, `Sampler`) have deterministic typed contracts and API export guards.
2. Batched estimator/sampler APIs are first-class and validated by executable feature and unit tests.
3. Mitigation and transpilation facades are deterministic and feature-covered.
4. Dynamic IR validation and explicit no-execution runtime boundary are implemented in `NxQuantum.DynamicIR`.
5. v0.3 spec includes feature-to-step mapping and aligns with implemented foundation behavior.

## Known Gaps (Post-v0.3 Foundation)

1. Hardware-provider depth is still early (job lifecycle/calibration/provider-specific contracts need expansion).

## Phase 6 - v0.4 P0: Dynamic Execution + Hardware Bridges

- [x] Implement dynamic-circuit runtime execution for supported IR nodes (mid-circuit measurement + feed-forward branches).
- [x] Add provider-facing job lifecycle contracts (`submit`, `poll`, `cancel`, typed result retrieval).
- [x] Add first provider bridge adapter behind ports with deterministic typed error mapping.
- [x] Extend mitigation hooks to accept hardware calibration payload contracts.

Milestone F review gate (before Phase 7):

1. Dynamic IR execution works for the approved v0.4 subset and remains typed/deterministic.
2. Provider bridge integration is behind explicit ports/adapters and has contract tests.
3. Hardware execution and mitigation calibration paths are covered by executable acceptance scenarios.

## Phase 7 - v0.4 P1: Scale and Performance

- [x] Add large-scale simulator fallback path (tensor-network/MPS-oriented strategy).
- [x] Improve batched execution path for `batch >= 32` with deterministic shape/performance contracts.
- [x] Publish cross-profile benchmark matrix (latency, throughput, memory) with reproducible scripts.
- [x] Add regression thresholds for performance-sensitive paths in CI reporting.

Milestone G review gate (before Phase 8):

1. Large-scale simulator fallback is callable through stable facades.
2. Benchmarks show measurable gains for targeted batch/size ranges versus current baseline.
3. Performance reports are reproducible and versioned in-repo.

## Phase 8 - v0.4 P2: Product Positioning vs Python-First Alternatives

- [x] Publish side-by-side workflow docs for identical tasks (estimation, sampling, kernels, transpilation) vs Python-first stacks.
- [x] Add migration playbooks from common Python quantum workflows into Elixir/NxQuantum patterns.
- [x] Provide Livebook-first tutorials and runnable end-to-end recipe packs for ML teams.
- [x] Publish a clear decision matrix: when NxQuantum is the better fit and when Python-first tooling is still preferable.
- [x] Add at least one public case-study style benchmark narrative focused on BEAM integration value.

Milestone H review gate (positioning readiness):

1. Positioning docs make differentiators explicit without hiding current limitations.
2. Migration guides and side-by-side examples are runnable and verified.
3. Public narrative is backed by reproducible data (benchmarks and workflow evidence), not only claims.

## Known Gaps (Post-v0.4 Positioning)

1. Top-3 provider production adapters are not yet implemented end-to-end (`IBM Runtime`, `AWS Braket`, `Azure Quantum`).
2. Provider-specific lifecycle differences (state models, cancellation semantics, calibration/result payloads) are not yet normalized in a public contract.
3. Migration assets still require provider-specific implementation guidance and executable acceptance mapping.

## Phase 9 - v0.5 P0: Production Provider Bridges (IBM Runtime + AWS Braket)

- [x] Finalize provider capability contract (`supports_estimator`, `supports_sampler`, `supports_dynamic`, `supports_cancel_in_running`, `supports_calibration_payload`).
- [x] Implement `NxQuantum.Adapters.Providers.IBMRuntime` behind `NxQuantum.Ports.Provider` with typed lifecycle/error mapping.
- [x] Implement `NxQuantum.Adapters.Providers.AwsBraket` behind `NxQuantum.Ports.Provider` with typed lifecycle/error mapping.
- [x] Add provider credential/config envelope with deterministic redaction and typed configuration diagnostics.
- [x] Add deterministic fixture-backed contract tests for IBM Runtime and AWS Braket lifecycle transitions.
- [x] Publish v0.5 specification and provider implementation playbook:
  - `docs/v0.5-feature-spec.md`
  - `docs/v0.5-provider-implementation-plan.md`
- [x] Add provider architecture ADR set:
  - `docs/adr/0002-provider-capability-contract-v1.md`
  - `docs/adr/0003-ibm-runtime-provider-adapter.md`
  - `docs/adr/0004-aws-braket-provider-adapter.md`
  - `docs/adr/0005-azure-quantum-provider-adapter.md`
  - `docs/adr/0006-opentelemetry-observability-standard.md`

Milestone I review gate (before Phase 10):

1. IBM Runtime and AWS Braket adapters execute `submit`, `poll`, `cancel`, and `fetch_result` through `NxQuantum.ProviderBridge`.
2. Provider-specific statuses/errors are mapped into stable typed NxQuantum contracts.
3. Unsupported capability requests fail fast with typed diagnostics (no silent fallback across providers).
4. Feature/contract tests are reproducible via deterministic fixtures and CI smoke lanes.

## Phase 10 - v0.5 P1: Azure Quantum + Cross-Provider Normalization

- [x] Implement `NxQuantum.Adapters.Providers.AzureQuantum` behind `NxQuantum.Ports.Provider`.
- [x] Normalize target-selection and capability-discovery contract across IBM/AWS/Azure.
- [x] Add provider-specific cancellation/terminal-state policy handling with explicit metadata.
- [x] Normalize calibration/result payload ingestion envelopes across top-3 providers.
- [x] Add cross-provider contract scenarios for typed lifecycle equivalence and portability boundaries.
- [x] Implement OpenTelemetry observability profile support (`high_level`, `granular`, `forensics`) for provider lifecycle traces, logs, and metrics.
- [x] Add deterministic experiment fingerprint and portability-delta telemetry contracts for cross-provider comparability.

Milestone J review gate (before Phase 11):

1. Azure Quantum lifecycle behavior is integrated with typed provider-specific caveat metadata.
2. Capability discovery contract is stable and documented across all top-3 providers.
3. Cross-provider scenario suite validates deterministic typed behavior for equivalent workflows.
4. CI includes provider smoke lanes and deterministic fixture lanes for all top-3 adapters.
5. OpenTelemetry schema/contracts are stable and profile-driven observability behavior is acceptance-covered.

## Phase 11 - v0.5 P2: Migration Packs, Adoption Assets, and Release Hardening

- [x] Publish provider-specific migration packs (Qiskit Runtime -> NxQuantum, Braket workflows -> NxQuantum, Azure workflows -> NxQuantum).
  - `docs/v0.5-migration-packs.md`
- [x] Publish runnable side-by-side tutorials for equivalent workloads on top-3 providers (estimation, sampling, transpilation constraints).
  - `examples/livebook/provider_bridge_side_by_side.livemd`
  - `docs/livebook-tutorials.md`
- [x] Publish benchmark matrix with reproducible scripts and explicit provider caveats.
  - `bench/milestone_k.exs`
  - `docs/v0.5-benchmark-matrix.md`
- [x] Add support-tier policy (`stable`, `beta`, `experimental`) and release-note templates per provider adapter.
  - `docs/v0.5-provider-support-tiers.md`
- [x] Publish observability conventions guide and starter dashboards for top-3 provider workflows.
  - `docs/observability.md`
  - `docs/observability-dashboards.md`
- [x] Complete release-quality gates for v0.5 provider support path.

Milestone K review gate (v0.5 readiness):

1. Top-3 adapters are documented with explicit support tiers, limits, and typed failure contracts.
2. Migration/tutorial assets are executable and traceable to acceptance scenarios.
3. Benchmark and case-study evidence are reproducible and tied to exact runtime/provider profiles.
4. v0.5 release checklist is green (`mix quality`, `mix dialyzer`, docs build, provider smoke lanes).
5. Observability artifacts (traces/logs/metrics conventions + dashboards) are published and validated.

## Known Gaps (Post-v0.5 Provider Foundation)

1. Five provider scenario families are still scaffold-only at step implementation level and need full executable assertion coverage.
2. Provider adapters remain fixture-first and require transport seam hardening for optional live smoke lanes while preserving deterministic defaults.
3. Documentation status notes still contain some stale “pending/planned” wording for already implemented v0.5 paths.

## Phase 12 - v0.6: Contract Completion and Adapter Hardening

- [ ] Harden provider adapter transport seams for optional live smoke lanes while preserving fixture-first deterministic defaults.
- [ ] Convert remaining scaffold-only provider scenario step modules into executable assertion-driven behavior checks.
- [ ] Add targeted unit/property checks for newly completed provider scenario families.
- [ ] Align v0.5/v0.6 docs and release evidence status wording for consistency.
- [ ] Publish v0.6 feature specification:
  - `docs/v0.6-feature-spec.md`

Milestone L/M/N review gate (v0.6 readiness):

1. No scaffold-only provider step modules remain for scoped v0.6 scenarios.
2. Fixture lanes remain deterministic and reproducible across repeated runs.
3. Optional live smoke-lane readiness is validated without public API contract drift.
4. Roadmap/spec/acceptance/release docs are internally consistent for v0.6 status.

## Phase 13 - v0.7: Standalone Production Hardening + External Operations Interoperability

- [ ] Stabilize external operations integration contracts (capability/lifecycle/error envelope versioning + deterministic serialization).
- [ ] Harden observability schema governance and adapter strategy across `high_level`, `granular`, and `forensics`.
- [ ] Publish standalone production and external integration profile guidance with executable examples.
- [ ] Add release evidence checks for contract stability and schema compatibility.
- [ ] Publish v0.7 feature specification:
  - `docs/v0.7-feature-spec.md`

Milestone O/P/Q review gate (v0.7 readiness):

1. Lifecycle/capability/error contracts are versioned, documented, and schema-tested.
2. Observability schema and redaction/cardinality invariants are stable across profiles.
3. Standalone production workflows remain green with no dependency on external orchestration systems.
4. External clients can consume deterministic machine-readable contracts without undocumented parsing behavior.

## Proposed Backlog (Not Scheduled in Roadmap)

1. Migration assurance toolkit proposal remains unscheduled and tracked via:
   - `docs/adr/0007-migration-assurance-toolkit.md`
