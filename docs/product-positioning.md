# Product Positioning

## Why NxQuantum is Relevant

NxQuantum targets teams that already build ML systems in Elixir and want quantum primitives without moving to a separate Python stack.

It is most valuable when you care about:

1. Deterministic-by-default and typed behavior for production-like workflows.
2. Tight integration with `Nx`, `Nx.Defn`, and BEAM services.
3. A path from research experiments to operational Elixir systems.

## Determinism Scope

1. Deterministic means fixed inputs + fixed seed + fixed runtime profile/options produce stable outputs in simulator and fixture lanes.
2. Live provider/QPU lanes remain probabilistic by nature and may vary due to hardware noise and runtime conditions.
3. In live lanes, NxQuantum guarantees typed contracts, lifecycle semantics, and reproducible request metadata rather than identical measured outcomes.

## Strengths

1. Elixir-native quantum primitives (`Estimator`, `Sampler`, `Kernels`, `Transpiler`).
2. Explicit runtime-profile and fallback contracts.
3. Seeded deterministic behavior across simulator/fixture sampling and batch workflows.
4. Structured feature + test coverage aligned to roadmap milestones.

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
5. Case-study benchmark narrative:
   - [docs/case-study-beam-integration.md](case-study-beam-integration.md)

## Important Gaps (Planned)

NxQuantum is intentionally honest about current limits:

1. Hardware-provider integrations and calibration depth are still growing.
2. Some advanced provider-specific execution flows remain phased.

References:

- [docs/roadmap.md](roadmap.md)
- [docs/v0.3-feature-spec.md](v0.3-feature-spec.md)
