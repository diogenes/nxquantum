# NxQuantum

Deterministic quantum execution on BEAM for Elixir and Nx teams.

NxQuantum is a pure-Elixir quantum library built on `Nx`. It runs circuit simulation, estimation, sampling, kernels, and transpilation inside your BEAM application, with no separate Python service. With fixed inputs, seed, and runtime profile, simulator and fixture runs return the same outputs every time. Jobs for IBM Runtime, AWS Braket, Azure Quantum, and Google Quantum AI go through one typed lifecycle with versioned envelopes ([support tiers](docs/provider-support-catalog.md)); live hardware results remain probabilistic (see Determinism Scope).

## Who It Is For

- Elixir and Nx teams embedding quantum workloads in BEAM services, who need seeded, reproducible results and typed contracts in the same runtime.
- Teams building host applications or control planes on NxQuantum's versioned job, result, and error envelopes and structured telemetry.
- Researchers who need reproducible runs: fixed seeds, experiment fingerprints, and Livebook tutorials.
- Teams exploring hybrid quantum-AI as an application of the same runtime: training steps that differentiate through quantum expectations (Axon-style pattern, `docs/axon-integration.md`), and versioned AI tool contracts for reranking and constrained optimization. The bundled rerank and optimization handlers compute classically today, and the in-repo rerank datasets are synthetic; no real-data quality claim is made.
- Not a primary fit (today) for teams whose top requirement is broad hardware-provider coverage, compiler depth, or large-scale GPU simulation.

## Why Teams Choose NxQuantum

Quantum tooling is mostly Python-first today. NxQuantum focuses on the Elixir/Nx/BEAM community by providing:

- Deterministic-by-default execution: fixed inputs, seed, and runtime profile give the same outputs in simulator and fixture lanes, so CI and regression checks are reproducible.
- Quantum execution in the same BEAM runtime as your services and `Nx` code, with no required cross-language service hop.
- Typed, versioned contracts: one provider job lifecycle (`submit_job`, `poll_job`, `cancel_job`, `fetch_result`) with typed errors, plus explicit runtime-profile fallback.
- Envelope compatibility guarded in CI: golden snapshots of job, result, and error envelopes fail the build on any byte change, and a deliberate change requires a `schema_version` bump (`docs/api-stability.md`). (unreleased; on `main`, see CHANGELOG `[Unreleased]`)
- Verified physics with stated limits: compiler and transpiler passes are property-tested against an independent dense reference, and the single-precision accuracy floor is documented. (unreleased; on `main`, see CHANGELOG `[Unreleased]`)
- Telemetry with OpenTelemetry-style span, metric, and log names behind a pluggable emitter (the bundled adapter records in-process; no OpenTelemetry exporter ships), plus experiment fingerprints for comparing runs. VM-independent fingerprint hashing is unreleased (on `main`, see CHANGELOG `[Unreleased]`).
- Hybrid quantum-AI building blocks (versioned AI tool contracts, a TurboQuant-compressed rerank handler, rollout gates) as an application rather than the core; the bundled handlers compute classically today.

See positioning and comparison details:

- [docs/product-positioning.md](docs/product-positioning.md)
- [docs/vision.md](docs/vision.md)

## Performance Value Proposition

Evidence, not hype:

- In the reproducible cross-framework benchmark (`docs/python-alternatives-benchmark-2026-03-25.md`), NxQuantum is faster than Qiskit on all 5 local simulator scenarios in the report (`baseline_2q`, `deep_6q`, `batch_obs_8q`, `state_reuse_8q_xy`, `sampled_counts_sparse_terms`).
- The same report shows strong wins vs PennyLane and Cirq on the same machine and run configuration.
- In the BEAM integration case-study throughput lane, throughput increases from `1333.333 ops/s` to `3030.303 ops/s` on `:cpu_portable`, and from `1666.667 ops/s` to `3787.879 ops/s` on `:cpu_compiled` as batch size increases (`8 -> 32`).

Benchmark references:

- [docs/python-alternatives-benchmark-2026-03-25.md](docs/python-alternatives-benchmark-2026-03-25.md)
- [docs/case-study-beam-integration.md](docs/case-study-beam-integration.md)

Caveat: these speed figures are from local simulator/fixture workflows on specific environments; they are not universal claims about remote provider/QPU execution latency.

## Determinism Scope (Important)

- Deterministic means fixed inputs + fixed seed + fixed runtime profile/options produce stable outputs in simulator and fixture lanes.
- Live provider/QPU execution remains physically probabilistic and can vary due to noise, calibration drift, and queue/runtime conditions.
- For live lanes, NxQuantum guarantees typed lifecycle/error envelopes and reproducible request metadata; it does not guarantee bit-for-bit identical measured outcomes.

## Choose Your Path

- Evaluate vs Python-first workflows: [docs/python-comparison-workflows.md](docs/python-comparison-workflows.md)
- Plan migration from Python workflows: [docs/migration-python-playbook.md](docs/migration-python-playbook.md)
- Use provider-specific migration packs: [docs/migration-packs.md](docs/migration-packs.md)
- Start interactive tutorials: [docs/livebook-tutorials.md](docs/livebook-tutorials.md)
- Check provider support tiers and limits: [docs/provider-support-catalog.md](docs/provider-support-catalog.md)
- Use standalone and external integration profiles: [docs/standalone-integration-profiles.md](docs/standalone-integration-profiles.md)
- Review Quantum AI tool contract strategy (sync + async): [docs/quantum-ai-tool-contracts.md](docs/quantum-ai-tool-contracts.md)
- Review hybrid benchmark/dataset/API spec (rerank datasets are synthetic; figures are placeholders): [docs/hybrid-quantum-ai-benchmark.md](docs/hybrid-quantum-ai-benchmark.md)
- Review TurboQuant-inspired rerank compression guide: [docs/turboquant-rerank-guide.md](docs/turboquant-rerank-guide.md)
- Review reproducible provider benchmark matrix: [docs/provider-benchmark-matrix.md](docs/provider-benchmark-matrix.md)
- Review Python alternatives benchmark run: [docs/python-alternatives-benchmark-2026-03-25.md](docs/python-alternatives-benchmark-2026-03-25.md)
- Review benchmark narrative evidence: [docs/case-study-beam-integration.md](docs/case-study-beam-integration.md)

## Requirements

- Elixir `~> 1.19` on OTP 28 or newer. CI tests two toolchain pairs: Elixir 1.19.1 / OTP 28.1 (the supported floor; optional backends off) and Elixir 1.20.4 / OTP 29.1.2. The optional EXLA and Torchx backends are tested on the 1.20.4 / OTP 29.1.2 pair only (`.github/workflows/ci.yml`).
- Nx `~> 1.0`.
- Optional EXLA and Torchx backends, `~> 1.0`.

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
- [docs/archive/v0.6-feature-spec.md](docs/archive/v0.6-feature-spec.md)
- [docs/archive/v0.6-acceptance-criteria.md](docs/archive/v0.6-acceptance-criteria.md)
- [docs/archive/v0.6-feature-to-step-mapping.md](docs/archive/v0.6-feature-to-step-mapping.md)
- [docs/archive/v0.7-feature-spec.md](docs/archive/v0.7-feature-spec.md)
- [docs/archive/v0.7-acceptance-criteria.md](docs/archive/v0.7-acceptance-criteria.md)
- [docs/archive/v0.7-feature-to-step-mapping.md](docs/archive/v0.7-feature-to-step-mapping.md)
- [docs/archive/v0.3-feature-spec.md](docs/archive/v0.3-feature-spec.md)
- [docs/archive/v0.4-feature-spec.md](docs/archive/v0.4-feature-spec.md)

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
- [docs/archive/v0.5-feature-spec.md](docs/archive/v0.5-feature-spec.md)
- [docs/archive/v0.6-feature-spec.md](docs/archive/v0.6-feature-spec.md)
- [docs/archive/v0.6-acceptance-criteria.md](docs/archive/v0.6-acceptance-criteria.md)
- [docs/archive/v0.6-feature-to-step-mapping.md](docs/archive/v0.6-feature-to-step-mapping.md)
- [docs/archive/v0.7-feature-spec.md](docs/archive/v0.7-feature-spec.md)
- [docs/archive/v0.7-acceptance-criteria.md](docs/archive/v0.7-acceptance-criteria.md)
- [docs/archive/v0.7-feature-to-step-mapping.md](docs/archive/v0.7-feature-to-step-mapping.md)
- [docs/archive/v0.5-provider-implementation-plan.md](docs/archive/v0.5-provider-implementation-plan.md)
- [docs/archive/v0.5-acceptance-criteria.md](docs/archive/v0.5-acceptance-criteria.md)
- [docs/migration-packs.md](docs/migration-packs.md)
- [docs/provider-benchmark-matrix.md](docs/provider-benchmark-matrix.md)
- [docs/python-alternatives-benchmark-2026-03-25.md](docs/python-alternatives-benchmark-2026-03-25.md)
- [docs/provider-support-catalog.md](docs/provider-support-catalog.md)
- [docs/turboquant-rerank-guide.md](docs/turboquant-rerank-guide.md)

## Contributing

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/development-flow.md](docs/development-flow.md)
