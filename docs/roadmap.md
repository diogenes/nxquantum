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

- [ ] Quantum kernel matrix generation API.
- [ ] Axon layer integration polish and end-to-end examples.
- [ ] Additional model recipes and tutorials.

## Phase 4 - Ecosystem Readiness

- [ ] API stabilization.
- [ ] HexDocs polish.
- [ ] CI/CD and release automation.

## Phase 5 - v0.3: Hardware-Ready Primitives and Batch Workflows

- [ ] Ship stable `Estimator` and `Sampler` primitives with deterministic typed contracts.
- [ ] Add batched PQC execution as a first-class API path.
- [ ] Add pluggable mitigation pipeline (readout + ZNE baseline).
- [ ] Add topology-aware transpilation interface with deterministic shortest-path routing.
- [ ] Add dynamic-circuit IR foundation (validation + metadata) with explicit no-execution boundary.
- [ ] Publish v0.3 spec and feature-to-step mappings.
