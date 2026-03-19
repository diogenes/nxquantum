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

1. Dynamic-circuit execution is still boundary-only (validation exists, execution engine is pending).
2. Hardware-provider depth is still early (job lifecycle/calibration/provider-specific contracts need expansion).
3. Large-scale simulation strategies (for example tensor-network/MPS) are still pending.
4. Product-positioning assets versus Python-first alternatives need stronger public packaging (migration guides, side-by-side comparisons, case studies).

## Phase 6 - v0.4 P0: Dynamic Execution + Hardware Bridges

- [ ] Implement dynamic-circuit runtime execution for supported IR nodes (mid-circuit measurement + feed-forward branches).
- [ ] Add provider-facing job lifecycle contracts (`submit`, `poll`, `cancel`, typed result retrieval).
- [ ] Add first provider bridge adapter behind ports with deterministic typed error mapping.
- [ ] Extend mitigation hooks to accept hardware calibration payload contracts.

Milestone F review gate (before Phase 7):

1. Dynamic IR execution works for the approved v0.4 subset and remains typed/deterministic.
2. Provider bridge integration is behind explicit ports/adapters and has contract tests.
3. Hardware execution and mitigation calibration paths are covered by executable acceptance scenarios.

## Phase 7 - v0.4 P1: Scale and Performance

- [ ] Add large-scale simulator fallback path (tensor-network/MPS-oriented strategy).
- [ ] Improve batched execution path for `batch >= 32` with deterministic shape/performance contracts.
- [ ] Publish cross-profile benchmark matrix (latency, throughput, memory) with reproducible scripts.
- [ ] Add regression thresholds for performance-sensitive paths in CI reporting.

Milestone G review gate (before Phase 8):

1. Large-scale simulator fallback is callable through stable facades.
2. Benchmarks show measurable gains for targeted batch/size ranges versus current baseline.
3. Performance reports are reproducible and versioned in-repo.

## Phase 8 - v0.4 P2: Product Positioning vs Python-First Alternatives

- [ ] Publish side-by-side workflow docs for identical tasks (estimation, sampling, kernels, transpilation) vs Python-first stacks.
- [ ] Add migration playbooks from common Python quantum workflows into Elixir/NxQuantum patterns.
- [ ] Provide Livebook-first tutorials and runnable end-to-end recipe packs for ML teams.
- [ ] Publish a clear decision matrix: when NxQuantum is the better fit and when Python-first tooling is still preferable.
- [ ] Add at least one public case-study style benchmark narrative focused on BEAM integration value.

Milestone H review gate (positioning readiness):

1. Positioning docs make differentiators explicit without hiding current limitations.
2. Migration guides and side-by-side examples are runnable and verified.
3. Public narrative is backed by reproducible data (benchmarks and workflow evidence), not only claims.
