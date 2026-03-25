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

1. v0.5 post-foundation gaps were addressed in Phase 12 (v0.6) contract completion and adapter hardening.

## Phase 12 - v0.6: Contract Completion and Adapter Hardening

- [x] Harden provider adapter transport seams for optional live smoke lanes while preserving fixture-first deterministic defaults.
- [x] Convert remaining scaffold-only provider scenario step modules into executable assertion-driven behavior checks.
- [x] Add targeted unit/property checks for newly completed provider scenario families.
- [x] Align v0.5/v0.6 docs and release evidence status wording for consistency.
- [x] Publish v0.6 feature specification:
  - `docs/v0.6-feature-spec.md`
- [x] Publish v0.6 acceptance criteria and feature-to-step execution mapping:
  - `docs/v0.6-acceptance-criteria.md`
  - `docs/v0.6-feature-to-step-mapping.md`

Milestone L/M/N review gate (v0.6 readiness):

1. No scaffold-only provider step modules remain for scoped v0.6 scenarios.
2. Fixture lanes remain deterministic and reproducible across repeated runs.
3. Optional live smoke-lane readiness is validated without public API contract drift.
4. Roadmap/spec/acceptance/release docs are internally consistent for v0.6 status.

## Phase 13 - v0.7: Standalone Production Hardening + External Operations Interoperability

- [x] Stabilize external operations integration contracts (capability/lifecycle/error envelope versioning + deterministic serialization).
- [x] Harden observability schema governance and adapter strategy across `high_level`, `granular`, and `forensics`.
- [x] Publish standalone production and external integration profile guidance with executable examples.
- [x] Add release evidence checks for contract stability and schema compatibility.
- [x] Publish v0.7 feature specification:
  - `docs/v0.7-feature-spec.md`
- [x] Publish v0.7 acceptance criteria and feature-to-step execution mapping:
  - `docs/v0.7-acceptance-criteria.md`
  - `docs/v0.7-feature-to-step-mapping.md`

Milestone O/P/Q review gate (v0.7 readiness):

1. Lifecycle/capability/error contracts are versioned, documented, and schema-tested.
2. Observability schema and redaction/cardinality invariants are stable across profiles.
3. Standalone production workflows remain green with no dependency on external orchestration systems.
4. External clients can consume deterministic machine-readable contracts without undocumented parsing behavior.

## Known Gaps (Post-v0.7 Standalone Hardening)

1. Provider adapters remain fixture-first in practice; true remote execution on cloud hardware targets is not yet delivered behind the same typed contracts.
2. Compilation/transpilation depth is still limited versus Python-first stacks for device-aware optimization and routing strategy breadth.
3. Observability contracts are stable but troubleshooting depth (custom attributes, poll-phase diagnostics, retry/correlation detail) remains shallow for incident forensics.
4. High-value cross-ecosystem performance evidence is still concentrated on simulator micro paths and does not yet cover full provider-lifecycle and production-like Q/ML rollout scenarios.

## Phase 14 - v0.8 P0: Live Provider Execution (Top-3) Behind Stable Contracts

Goal:

1. Deliver real cloud provider execution while preserving deterministic fixture parity and typed lifecycle contracts.

Implementation deliverables:

1. Implement real transport execution paths for `IBM Runtime`, `AWS Braket`, and `Azure Quantum` adapters while preserving fixture-first defaults.
2. Add explicit transport mode contract (`fixture`, `live_smoke`, `live`) where `live_smoke` is readiness/contract-path validation and `live` is remote lifecycle execution, with typed failure semantics.
3. Support actual remote lifecycle transitions (`submit`, `poll`, `cancel`, `fetch_result`) with provider-authenticated SDK/API calls.
4. Add typed provider calibration/job metadata ingestion for live runs (queue context, provider job ids, terminal diagnostics).
5. Add replay fixture capture tooling from live runs for deterministic regression lanes.
6. Publish v0.8 provider execution spec and implementation plan:
   - `docs/v0.8-feature-spec.md`
   - `docs/v0.8-provider-live-execution-plan.md`
7. Publish explicit capability status matrix for real hardware vs simulator execution paths:
   - `docs/v0.8-provider-capability-matrix.md`

Milestone R review gate (before Phase 15):

1. Live-mode adapter paths execute remote tasks and return normalized typed envelopes.
2. Fixture and live lanes share identical public contract shape (`schema_version`, `correlation_id`, `idempotency_key`).
3. Provider-specific live failures map into stable typed NxQuantum error codes and metadata.
4. CI keeps deterministic fixture gates mandatory and adds optional credentialed live verification lanes.

## Phase 15 - v0.8 P1: Compilation and Transpilation Value Upgrade

Goal:

1. Deliver production-credible compiler/transpiler capabilities with deterministic diagnostics and measurable routing/optimization value.

Implementation deliverables:

1. Expand compiler/transpiler strategy set beyond deterministic shortest-path baseline (layout/routing/cost-model profiles).
2. Add target-aware optimization profiles for depth-sensitive, latency-sensitive, and calibration-aware execution policies.
3. Add deterministic compilation diagnostics for strategy decisions (selected heuristic, rejected alternatives, topology pressure indicators).
4. Add provider-aware transpilation policy adapters that remain behind stable ports and explicit capability checks.
5. Publish side-by-side compilation value narratives versus Qiskit/Cirq workflows (without parity theater).
6. Add acceptance and property tests for semantic equivalence under new strategy profiles.
7. Publish detailed compiler implementation and multi-agent handoff plan:
   - `docs/v0.8-compiler-implementation-plan.md`

Milestone S review gate (before Phase 16):

1. New compilation profiles are selectable via stable public API contracts.
2. Routing/optimization strategy decisions are reproducibly reported in machine-readable diagnostics.
3. Scenario coverage includes topology-constrained circuits and confirms semantic preservation under all supported modes.
4. Documentation clearly states where NxQuantum compiler value is stronger, equivalent, or currently behind alternatives.

## Phase 16 - v0.8 P2: Observability and Troubleshooting 2.0

Goal:

1. Make provider and hybrid execution troubleshooting production-grade through richer deterministic observability contracts.

Implementation deliverables:

1. Add safe custom span/log attribute injection API with schema-governed allowlists and redaction enforcement.
2. Expand lifecycle diagnostics to include poll-cycle summaries, retry metadata, terminal provider payload summaries, and queue/execution phase attribution.
3. Add troubleshooting bundles for Q/ML engineers (single-run correlated trace/log/metric export with deterministic contract versioning).
4. Add explicit support for user-provided correlation metadata propagation across provider bridge operations.
5. Publish incident playbooks and updated dashboards for live-provider troubleshooting.
6. Add acceptance tests for custom-attribute policy, cardinality guardrails, and redaction invariants.

Milestone T review gate (before Phase 17):

1. Users can add approved custom observability attributes without breaking schema/cardinality constraints.
2. Troubleshooting output includes enough lifecycle context to isolate queue, execution, cancellation, and result-normalization failures.
3. Redaction and sensitive-field protections remain deterministic under custom metadata paths.
4. Observability adapter substitution still preserves lifecycle contract shape and deterministic behavior.

## Phase 17 - v0.9 P0: Migration Assurance Toolkit (ADR 0007)

Goal:

1. Provide deterministic migration decision tooling for shadow-mode and promotion workflows.

Implementation deliverables:

1. Implement `NxQuantum.Migration.Manifest` for deterministic canonical workflow manifests and fingerprints.
2. Implement `NxQuantum.Migration.Compare` with tolerance-budgeted output comparison contracts.
3. Implement `NxQuantum.Migration.Gates` for CI-friendly promotion decisions.
4. Implement `NxQuantum.Migration.Report` machine-readable export with explicit schema versioning.
5. Add acceptance/property tests for manifest determinism, comparison correctness, and gate stability.
6. Publish migration assurance docs and CI integration examples:
   - `docs/v0.9-migration-assurance.md`

Milestone U review gate (before Phase 18):

1. Migration assurance APIs are additive and public-contract stable.
2. Identical workflow inputs produce stable manifest/comparison/decision outputs.
3. Tolerance gates support shadow-mode promotion decisions with typed failure reasons.
4. Migration artifacts map cleanly to existing provider lifecycle and observability contracts.

## Phase 18 - v0.9 P1: High-Value Performance Matrix for Q/ML Engineering Workloads

Goal:

1. Anchor performance claims in reproducible high-value workloads that match real Q/ML engineering decisions.

Implementation deliverables:

1. Establish benchmark tiers aligned to production-value use cases:
   - repeated expectation on reused states,
   - multi-observable batch estimation on medium qubit counts,
   - sparse sampled-count expectation reduction,
   - shot-heavy sampler throughput under batched parameter sweeps,
   - provider-lifecycle latency under fixture and live lanes.
2. Consolidate simulation-focused high-value scenarios into one deterministic harness:
   - `bench/high_value_performance_matrix.exs`
   - required scenario IDs:
     - `state_reuse_8q_xy`
     - `batch_obs_8q`
     - `sampled_counts_sparse_terms`
     - `shot_sweep_param_grid_v1`
3. Add explicit shot-heavy parameter sweep scenario contracts and datasets:
   - `bench/datasets/perf/shot_sweep_param_grid_v1.jsonl`
   - `bench/datasets/perf/shot_sweep_param_grid_v1.manifest.json`
   - include fixed shot tiers (`256`, `1024`, `4096`) and fixed parameter grid metadata.
4. Split provider-lifecycle latency benchmarking into explicit lanes and scripts:
   - fixture lane:
     - `bench/provider_lifecycle_latency_fixture.exs` (can absorb/replace current `bench/milestone_k.exs`)
   - live-smoke/live lanes:
     - `bench/provider_lifecycle_latency_live.exs`
   - required lifecycle phases:
     - `submit`, `poll`, `cancel`, `fetch_result`.
5. Add deterministic dataset/manifests for all Phase 18 scenarios:
   - `bench/datasets/perf/state_reuse_8q_xy_v1.manifest.json`
   - `bench/datasets/perf/batch_obs_8q_v1.manifest.json`
   - `bench/datasets/perf/sampled_counts_sparse_terms_v1.manifest.json`
   - manifest fields must include `dataset_id`, `schema_version`, `seed`, and `sha256`.
6. Add explicit parity/position targets versus Qiskit/Cirq on prioritized scenarios with version-pinned reproducibility.
7. Add CI regression guards for high-value scenarios (not only micro synthetic baselines):
   - `test/nx_quantum/high_value_performance_guard_test.exs`
   - `test/nx_quantum/provider_lifecycle_latency_guard_test.exs`
8. Publish periodic benchmark reports and positioning summaries:
   - `docs/python-alternatives-benchmark-YYYY-MM-DD.md`
   - `docs/v0.9-high-value-performance-matrix.md`
   - `docs/case-study-beam-integration.md` (updated)

Scenario closure tracker (as of March 25, 2026):

1. `[x]` repeated expectation on reused states (`state_reuse_8q_xy`) exists in python-comparison harness.
2. `[x]` multi-observable batch estimation (`batch_obs_8q`) exists with regression guard.
3. `[x]` sampled-count sparse reductions (`sampled_counts_sparse_terms`) exists in python-comparison harness.
4. `[x]` shot-heavy parameter sweep formal dataset + matrix scenario + CI guard is implemented.
5. `[x]` provider lifecycle live-lane latency (`submit/poll/cancel/fetch_result`) benchmark script and release evidence lane are implemented.
6. `[x]` sampled small-workload strategy guard is implemented (`test/nx_quantum/sampled_small_workload_strategy_guard_test.exs`).
7. `[x]` batch fused-kernel runtime-profile guard is implemented (`test/nx_quantum/batch_fused_kernel_runtime_profile_guard_test.exs`).
8. `[x]` bounded deterministic evolved-state cache is implemented for repeated state-vector workloads (`lib/nx_quantum/adapters/simulators/state_vector.ex`).
9. `[x]` latest 3-run matrix evidence is published (`docs/python-alternatives-benchmark-2026-03-25.md`) with requested threshold checks marked as met.

Milestone V review gate (v0.9 readiness):

1. Benchmark suite covers both simulator and provider-lifecycle workloads that reflect real Q/ML engineering tasks.
2. Performance targets are explicit per scenario and tied to release gates.
3. Reported comparisons are reproducible, version-pinned, and caveat-labeled.
4. Roadmap/README/positioning docs consistently reflect measured strengths and remaining performance gaps.

## Roadmap Scope Policy (Near-Term Execution Only)

1. Roadmap entries must be short-to-medium horizon and have a clear implementation path.
2. Long-horizon exploratory vision remains documented separately in:
   - `docs/quantum-llm-vision.md`

## Milestone Template Policy (Required for All Unfinished Phases)

Every unfinished roadmap phase (currently Phase 14 onward) must include:

1. `Goal` section (explicit business/engineering outcome).
2. `Implementation deliverables` section (concrete modules/files/features/tests/docs).
3. Review gate with deterministic evidence criteria.

## Phase 19 - v0.9 P2: Quantum AI Tool Interface Contracts

Goal:

1. Ship a production-safe `NxQuantum.AI` tool-call contract layer so BEAM services/agents can invoke quantum workflows through deterministic typed envelopes.

Implementation deliverables:

1. Implement AI contract modules and facades:
   - `lib/nx_quantum/ai.ex`
   - `lib/nx_quantum/ai/request.ex`
   - `lib/nx_quantum/ai/result.ex`
   - `lib/nx_quantum/ai/tool_runner.ex`
2. Define stable tool-call envelopes (`request`, `result`, `error`, `trace metadata`) and versioned serialization contract.
3. Implement first two tool handlers with deterministic fallback behavior:
   - quantum-kernel reranking request path,
   - constrained optimization helper request path.
4. Add acceptance/contract coverage:
   - `features/quantum_ai_tool_contracts.feature`
   - `test/features/steps/quantum_ai_tool_contracts_steps.ex`
   - `test/nx_quantum/ai/tool_contract_test.exs`
5. Add transport architecture contract for sync and async integration:
   - `docs/adr/0011-ai-tool-transport-sync-async-contract.md`
   - `lib/nx_quantum/ports/ai_tool_transport.ex`
   - `lib/nx_quantum/adapters/ai_tool_transport/mcp_json_rpc_sync.ex`
   - `lib/nx_quantum/adapters/ai_tool_transport/cloud_events_async.ex`
6. Publish docs and runnable examples:
   - `docs/v0.9-quantum-ai-tool-contracts.md`

Implementation status checklist (as of March 25, 2026):

1. `[x]` AI contract modules and facade are implemented (`NxQuantum.AI`, request/result envelopes, tool runner).
2. `[x]` Stable envelope contract with versioned `schema_version`, typed result/error/fallback shape, and trace/correlation metadata is implemented.
3. `[x]` First two deterministic tool handlers are implemented (`quantum-kernel reranking`, `constrained optimization helper`) with explicit fallback policy behavior.
4. `[x]` Acceptance/contract coverage is implemented:
   - `features/quantum_ai_tool_contracts.feature`
   - `test/features/steps/quantum_ai_tool_contracts_steps.ex`
   - `test/nx_quantum/ai/tool_contract_test.exs`
5. `[x]` Sync/async transport architecture contract is implemented behind ports/adapters:
   - `docs/adr/0011-ai-tool-transport-sync-async-contract.md`
   - `lib/nx_quantum/ports/ai_tool_transport.ex`
   - `lib/nx_quantum/adapters/ai_tool_transport/mcp_json_rpc_sync.ex`
   - `lib/nx_quantum/adapters/ai_tool_transport/cloud_events_async.ex`
6. `[x]` v0.9 tool contract documentation is published (`docs/v0.9-quantum-ai-tool-contracts.md`).

Milestone W review gate (before Phase 20):

1. AI-tool contract envelopes are additive, versioned, and machine-consumable.
2. Deterministic fallback behavior is explicit and acceptance-covered.
3. Integration consumers can parse typed responses without provider-specific coupling.
4. Sync and async transport paths are both defined behind stable ports/adapters.
5. Docs/examples are executable and aligned with public APIs.

## Phase 20 - v0.9 P3: Hybrid Quantum AI Evaluation and Benchmark Pack

Goal:

1. Add a reproducible benchmark/evaluation pack that measures where hybrid quantum-AI workflows outperform, match, or underperform classical baselines.

Implementation deliverables:

1. Implement benchmark harness scripts:
   - `bench/hybrid_quantum_ai_benchmark.exs`
   - `bench/hybrid_quantum_ai_baseline.exs`
   - `bench/hybrid_quantum_ai_report.exs`
2. Implement scoped benchmark scenarios with pinned datasets/seeds and explicit classical baselines:
   - reranking-quality delta scenarios,
   - constrained optimization assistant scenarios,
   - latency and fallback impact scenarios.
3. Add CI-reportable benchmark gate checks:
   - `test/nx_quantum/hybrid_quantum_ai_benchmark_guard_test.exs`
4. Publish benchmark evidence and integration guide:
   - `docs/v0.9-hybrid-quantum-ai-benchmark.md`
   - `docs/v1.0-hybrid-quantum-ai-integration-guide.md`

Implementation status checklist (as of March 25, 2026):

1. `[x]` Hybrid benchmark harness scripts are implemented:
   - `bench/hybrid_quantum_ai_benchmark.exs`
   - `bench/hybrid_quantum_ai_baseline.exs`
   - `bench/hybrid_quantum_ai_report.exs`
2. `[x]` Scoped benchmark scenario families are implemented with pinned seed and explicit classical baseline fields:
   - reranking-quality delta
   - constrained optimization assistant
   - fallback latency impact
3. `[x]` CI-reportable benchmark guard coverage is implemented (`test/nx_quantum/hybrid_quantum_ai_benchmark_guard_test.exs`).
4. `[x]` Benchmark evidence docs are published:
   - `docs/v0.9-hybrid-quantum-ai-benchmark.md`
   - `docs/v1.0-hybrid-quantum-ai-integration-guide.md`

Milestone X review gate (before Phase 21):

1. Hybrid benchmarks are reproducible and version-pinned.
2. Every reported gain includes a classical baseline and caveat notes.
3. Fallback and failure-path behavior is measured and documented.
4. Evidence is sufficient for migration-go/no-go decisions.

## Phase 21 - v0.9 P4: Quantum AI Production Promotion Gates

Goal:

1. Ship deterministic rollout gates so teams can promote or block hybrid quantum-AI workflows in production using typed decisions and reproducible evidence.

Dependency:

1. Requires Phase 20 benchmark outputs.
2. `[ ]` Original dependency on the full Phase 17 Migration Assurance Toolkit remains deferred in this cycle.
3. `[x]` This phase currently ships a scoped `NxQuantum.Migration.AI*` rollout-gate slice, pending full Phase 17 consolidation.

Implementation deliverables:

1. Implement AI promotion gate modules:
   - `lib/nx_quantum/migration/ai_gates.ex`
   - `lib/nx_quantum/migration/ai_report.ex`
2. Implement rollout gate flow with typed decision outputs:
   - `promote`, `hold`, `rollback`.
3. Extend observability for AI-tool calls with request correlation:
   - `lib/nx_quantum/observability/profile_strategy/*` updates
   - `test/nx_quantum/observability_ai_tool_calls_test.exs`
4. Add acceptance/contract coverage:
   - `features/quantum_ai_rollout_gates.feature`
   - `test/features/steps/quantum_ai_rollout_gates_steps.ex`
   - `test/nx_quantum/migration/ai_gates_test.exs`
5. Publish production rollout playbook:
   - `docs/v0.9-quantum-ai-rollout-playbook.md`

Implementation status checklist (as of March 25, 2026):

1. `[x]` AI promotion gate modules are implemented:
   - `lib/nx_quantum/migration/ai_gates.ex`
   - `lib/nx_quantum/migration/ai_report.ex`
2. `[x]` Rollout gate flow with typed decision outputs is implemented (`promote`, `hold`, `rollback`).
3. `[x]` Observability correlation coverage for AI tool lifecycle/decision metadata is implemented and tested (`test/nx_quantum/observability_ai_tool_calls_test.exs`).
4. `[x]` Acceptance/contract coverage is implemented:
   - `features/quantum_ai_rollout_gates.feature`
   - `test/features/steps/quantum_ai_rollout_gates_steps.ex`
   - `test/nx_quantum/migration/ai_gates_test.exs`
5. `[x]` v0.9 rollout playbook is published (`docs/v0.9-quantum-ai-rollout-playbook.md`).

Milestone Y review gate (v0.9 readiness):

1. Hybrid AI promotion decisions are deterministic, typed, and CI-friendly.
2. Observability provides enough context to isolate quantum-vs-classical path failures.
3. Rollout artifacts are reproducible and actionable for release decisions.
4. Public docs clearly distinguish implemented capabilities from research backlog.

## Proposed Backlog (Not Scheduled in Roadmap)

1. Additional provider-native analog/non-gate-model workflow support remains unscheduled beyond v0.9.
2. End-to-end quantum-native LLM architecture research remains outside short-to-medium execution scope and is tracked in `docs/quantum-llm-vision.md`.
