# Product Positioning

## Why NxQuantum is Relevant

NxQuantum targets Elixir and Nx teams that embed quantum workloads in BEAM services and need deterministic, contract-stable execution without a separate Python stack.

It is most valuable when you care about:

1. Seeded, reproducible results in simulator and fixture lanes, so CI and regression checks stay stable.
2. Typed, versioned contracts: one provider job lifecycle and envelopes that host applications and control planes can build on (decoding stored envelopes is unreleased; on `main`, see CHANGELOG `[Unreleased]`).
3. Execution inside the same BEAM runtime as your services and `Nx`/`Nx.Defn` code.

Hybrid quantum-AI (AI tool contracts with rerank and optimization handlers) is an application of these properties, not the lead. The bundled handlers compute classically today, and in-repo rerank evaluation uses synthetic datasets only; no real-data quality claim is made.

Not targeted: teams whose top need is provider breadth, compiler depth, or large-scale GPU simulation.

## Determinism Scope

1. Deterministic means fixed inputs + fixed seed + fixed runtime profile/options produce stable outputs in simulator and fixture lanes.
2. Live provider/QPU lanes remain probabilistic by nature and may vary due to hardware noise and runtime conditions.
3. In live lanes, NxQuantum guarantees typed contracts, lifecycle semantics, and reproducible request metadata rather than identical measured outcomes.

## Strengths

1. Elixir-native quantum primitives (`Estimator`, `Sampler`, `Kernels`, `Transpiler`).
2. Explicit runtime-profile and fallback contracts.
3. Seeded deterministic behavior across simulator/fixture sampling and batch workflows.
4. Compiler and transpiler property suites plus the documented single-precision floor (`docs/backend-support.md`). (unreleased; on `main`, see CHANGELOG `[Unreleased]`)
5. Golden envelope snapshots (`docs/api-stability.md`). (unreleased; on `main`, see CHANGELOG `[Unreleased]`)
6. OpenTelemetry-style telemetry behind a pluggable emitter, and experiment fingerprints (`docs/observability.md`).

## Comparison Snapshot

| Topic | NxQuantum | Python-first quantum frameworks |
| --- | --- | --- |
| Primary ecosystem | Elixir + Nx + BEAM | Python data/ML stack |
| Determinism emphasis | Strong typed contracts + seeded deterministic simulator/fixture behavior | Varies by framework/workflow |
| Runtime profile model | Explicit profile + fallback semantics | Usually backend/provider specific settings |
| Service integration in BEAM apps | Native fit | Cross-language integration required |
| Hardware-provider depth today | Early foundation, expanding | Typically broader at present |

## Positioning Assets

1. Side-by-side workflows:
   - [docs/python-comparison-workflows.md](python-comparison-workflows.md)
2. Migration playbook:
   - [docs/migration-python-playbook.md](migration-python-playbook.md)
3. Decision matrix:
   - [docs/decision-matrix.md](decision-matrix.md)
4. Livebook tutorials:
   - [docs/livebook-tutorials.md](livebook-tutorials.md)
5. BEAM integration case study:
   - [docs/case-study-beam-integration.md](case-study-beam-integration.md)

## Important Gaps (Planned)

NxQuantum is intentionally honest about current limits:

1. Hardware-provider integrations and calibration depth are still growing.
2. Some advanced provider-specific execution flows remain phased.
3. Hybrid quantum-AI rerank results use synthetic datasets; a real-data lane is parked (`docs/vision.md` §11).
4. Multi-node (distributed) execution is planned for Horizon 2 and is not shipped.

References:

- [docs/roadmap.md](roadmap.md)
- [docs/archive/v0.3-feature-spec.md](archive/v0.3-feature-spec.md)
