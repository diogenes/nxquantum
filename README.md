# NxQuantum

NxQuantum is a pure-Elixir quantum ML library for the `Nx` ecosystem.
It is built for ML engineers and researchers who want quantum primitives inside the same BEAM stack used for training loops, inference services, and production pipelines.

## Who It Is For

- Teams building ML systems in Elixir/Nx that need deterministic-by-default quantum workflows in the same runtime.
- Researchers who want reproducible, typed contracts and BEAM-native integration patterns.
- Not a primary fit (today) for teams whose top requirement is immediate broad hardware-provider coverage.

## Why It Matters

Quantum tooling is mostly Python-first today. NxQuantum focuses on the Elixir/Nx community by providing:

- Elixir-native primitives (`Estimator`, `Sampler`, `Kernels`, `Transpiler`).
- Deterministic-by-default behavior with explicit runtime and seed contracts.
- A cleaner path from research code to BEAM production systems.

See positioning and comparison details:

- [docs/product-positioning.md](docs/product-positioning.md)

## Determinism Scope (Important)

- Deterministic means fixed inputs + fixed seed + fixed runtime profile/options produce stable outputs in simulator and fixture lanes.
- Live provider/QPU execution remains physically probabilistic and can vary due to noise, calibration drift, and queue/runtime conditions.
- For live lanes, NxQuantum guarantees typed lifecycle/error envelopes and reproducible request metadata; it does not guarantee bit-for-bit identical measured outcomes.

## Choose Your Path

- Evaluate vs Python-first workflows: [docs/python-comparison-workflows.md](docs/python-comparison-workflows.md)
- Plan migration from Python workflows: [docs/migration-python-playbook.md](docs/migration-python-playbook.md)
- Use provider-specific migration packs: [docs/v0.5-migration-packs.md](docs/v0.5-migration-packs.md)
- Start interactive tutorials: [docs/livebook-tutorials.md](docs/livebook-tutorials.md)
- Check provider support tiers and limits: [docs/v0.5-provider-support-tiers.md](docs/v0.5-provider-support-tiers.md)
- Use standalone and external integration profiles: [docs/standalone-integration-profiles.md](docs/standalone-integration-profiles.md)
- Review Quantum AI tool contract strategy (sync + async): [docs/v1.0-quantum-ai-tool-contracts.md](docs/v1.0-quantum-ai-tool-contracts.md)
- Review hybrid benchmark/dataset/API spec (planned Phase 20): [docs/v1.0-hybrid-quantum-ai-benchmark.md](docs/v1.0-hybrid-quantum-ai-benchmark.md)
- Review reproducible provider benchmark matrix: [docs/v0.5-benchmark-matrix.md](docs/v0.5-benchmark-matrix.md)
- Review Python alternatives benchmark run: [docs/python-alternatives-benchmark-2026-03-21.md](docs/python-alternatives-benchmark-2026-03-21.md)
- Review benchmark narrative evidence: [docs/case-study-beam-integration.md](docs/case-study-beam-integration.md)

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
- Shot-based sampling with explicit seeds (deterministic in simulator/fixture lanes).
- Batched estimator/sampler APIs.
- Gradient modes (`backprop`, `parameter_shift`, `adjoint`).
- Error mitigation pipeline (`readout`, `zne_linear`).
- Topology-aware transpilation interface.
- Quantum kernel matrix generation.

## What Is Still Planned

- v0.8 migration-assurance toolkit scope from ADR 0007 (unscheduled).
- Additional provider depth and broader provider-native dynamic/non-gate-model paths.
- More benchmark-backed case studies across real BEAM deployment patterns.

Track status here:

- [docs/roadmap.md](docs/roadmap.md)
- [docs/v0.6-feature-spec.md](docs/v0.6-feature-spec.md)
- [docs/v0.6-acceptance-criteria.md](docs/v0.6-acceptance-criteria.md)
- [docs/v0.6-feature-to-step-mapping.md](docs/v0.6-feature-to-step-mapping.md)
- [docs/v0.7-feature-spec.md](docs/v0.7-feature-spec.md)
- [docs/v0.7-acceptance-criteria.md](docs/v0.7-acceptance-criteria.md)
- [docs/v0.7-feature-to-step-mapping.md](docs/v0.7-feature-to-step-mapping.md)
- [docs/v0.3-feature-spec.md](docs/v0.3-feature-spec.md)
- [docs/v0.4-feature-spec.md](docs/v0.4-feature-spec.md)

## Docs

- [docs/getting-started.md](docs/getting-started.md)
- [docs/product-positioning.md](docs/product-positioning.md)
- [docs/python-comparison-workflows.md](docs/python-comparison-workflows.md)
- [docs/migration-python-playbook.md](docs/migration-python-playbook.md)
- [docs/decision-matrix.md](docs/decision-matrix.md)
- [docs/livebook-tutorials.md](docs/livebook-tutorials.md)
- [docs/case-study-beam-integration.md](docs/case-study-beam-integration.md)
- [docs/axon-integration.md](docs/axon-integration.md)
- [docs/model-recipes.md](docs/model-recipes.md)
- [docs/backend-support.md](docs/backend-support.md)
- [docs/api-stability.md](docs/api-stability.md)
- [docs/architecture.md](docs/architecture.md)
- [docs/observability.md](docs/observability.md)
- [docs/observability-dashboards.md](docs/observability-dashboards.md)
- [docs/standalone-integration-profiles.md](docs/standalone-integration-profiles.md)
- [docs/v0.5-feature-spec.md](docs/v0.5-feature-spec.md)
- [docs/v0.6-feature-spec.md](docs/v0.6-feature-spec.md)
- [docs/v0.6-acceptance-criteria.md](docs/v0.6-acceptance-criteria.md)
- [docs/v0.6-feature-to-step-mapping.md](docs/v0.6-feature-to-step-mapping.md)
- [docs/v0.7-feature-spec.md](docs/v0.7-feature-spec.md)
- [docs/v0.7-acceptance-criteria.md](docs/v0.7-acceptance-criteria.md)
- [docs/v0.7-feature-to-step-mapping.md](docs/v0.7-feature-to-step-mapping.md)
- [docs/v0.5-provider-implementation-plan.md](docs/v0.5-provider-implementation-plan.md)
- [docs/v0.5-acceptance-criteria.md](docs/v0.5-acceptance-criteria.md)
- [docs/v0.5-migration-packs.md](docs/v0.5-migration-packs.md)
- [docs/v0.5-benchmark-matrix.md](docs/v0.5-benchmark-matrix.md)
- [docs/python-alternatives-benchmark-2026-03-21.md](docs/python-alternatives-benchmark-2026-03-21.md)
- [docs/v0.5-provider-support-tiers.md](docs/v0.5-provider-support-tiers.md)

## Contributing

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/development-flow.md](docs/development-flow.md)
