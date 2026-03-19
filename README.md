# NxQuantum

NxQuantum is a pure-Elixir quantum ML library for the `Nx` ecosystem.
It is built for ML engineers and researchers who want quantum primitives inside the same BEAM stack used for training loops, inference services, and production pipelines.

## Why It Matters

Quantum tooling is mostly Python-first today. NxQuantum focuses on the Elixir/Nx community by providing:

- Elixir-native primitives (`Estimator`, `Sampler`, `Kernels`, `Transpiler`).
- Deterministic behavior with explicit runtime and seed contracts.
- A cleaner path from research code to BEAM production systems.

See positioning and comparison details:

- [docs/product-positioning.md](docs/product-positioning.md)

## Quick Start

```bash
mise trust
mise install
mix setup
mix run examples/quantum_kernel_classifier.exs
```

For full setup and API walkthroughs and usage examples:

- [docs/getting-started.md](docs/getting-started.md)

## Main Features (Current)

- Circuit construction and expectation estimation.
- Shot-based sampling with deterministic seeds.
- Batched estimator/sampler APIs.
- Gradient modes (`backprop`, `parameter_shift`, `adjoint`).
- Error mitigation pipeline (`readout`, `zne_linear`).
- Topology-aware transpilation interface.
- Quantum kernel matrix generation.

## What Is Still Planned

- Full dynamic-circuit execution engine (validation boundary exists, execution is future work).
- Deeper hardware-provider integrations and calibration workflows.
- Larger-scale simulator strategies (for example tensor-network/MPS paths).

Track status here:

- [docs/roadmap.md](docs/roadmap.md)
- [docs/v0.3-feature-spec.md](docs/v0.3-feature-spec.md)
- [docs/v0.4-feature-spec.md](docs/v0.4-feature-spec.md)

## Docs

- [docs/getting-started.md](docs/getting-started.md)
- [docs/product-positioning.md](docs/product-positioning.md)
- [docs/axon-integration.md](docs/axon-integration.md)
- [docs/model-recipes.md](docs/model-recipes.md)
- [docs/backend-support.md](docs/backend-support.md)
- [docs/api-stability.md](docs/api-stability.md)
- [docs/architecture.md](docs/architecture.md)

## Contributing

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/development-flow.md](docs/development-flow.md)
