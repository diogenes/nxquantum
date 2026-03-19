# NxQuantum Roadmap

## Phase 0 - Foundation (current)

- [x] Project scaffolding.
- [x] Architecture docs + ADR baseline.
- [x] API and behavior skeletons.
- [x] Feature spec definitions.
- [x] v0.2 feature specification draft.
- [x] v0.2 improvement plan draft.

## Phase 1 - v0.2 P0: Correctness + Runtime Profiles

- [ ] Implement deterministic 1-2 qubit state-vector evolution.
- [ ] Implement expectation values for Pauli observables.
- [ ] Add property tests for normalization and gate composition.
- [ ] Stabilize runtime profile contract (`cpu_portable`, `cpu_compiled`, `nvidia_gpu_compiled`, `torch_interop_runtime`).
- [ ] Implement deterministic fallback policy (`strict`, `allow_cpu_compiled`).
- [ ] Add executable feature scenarios for backend and hybrid-training deterministic behavior.

## Phase 2 - v0.2 P1: Differentiation, Noise, and Optimization

- [ ] Move gate application path into `Nx.Defn` kernels.
- [ ] Add gradient modes (`backprop`, `parameter_shift`, optional `adjoint`).
- [ ] Add seeded shots and initial noise channels.
- [ ] Add deterministic circuit optimization pass pipeline.
- [ ] Add benchmark suite and baseline reports.

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
