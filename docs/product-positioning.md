# Product Positioning

## Why NxQuantum is Relevant

NxQuantum targets teams that already build ML systems in Elixir and want quantum primitives without moving to a separate Python stack.

It is most valuable when you care about:

1. Deterministic and typed behavior for production-like workflows.
2. Tight integration with `Nx`, `Nx.Defn`, and BEAM services.
3. A path from research experiments to operational Elixir systems.

## Strengths

1. Elixir-native quantum primitives (`Estimator`, `Sampler`, `Kernels`, `Transpiler`).
2. Explicit runtime-profile and fallback contracts.
3. Seeded deterministic behavior across sampling and batch workflows.
4. Structured feature + test coverage aligned to roadmap milestones.

## Comparison Snapshot

| Topic | NxQuantum | Python-first quantum frameworks |
| --- | --- | --- |
| Primary ecosystem | Elixir + Nx + BEAM | Python data/ML stack |
| Determinism emphasis | Strong typed contracts + seeded behavior in core APIs | Varies by framework/workflow |
| Runtime profile model | Explicit profile + fallback semantics | Usually backend/provider specific settings |
| Service integration in BEAM apps | Native fit | Cross-language integration required |
| Hardware-provider depth today | Early foundation, expanding | Typically broader at present |

## Important Gaps (Planned)

NxQuantum is intentionally honest about current limits:

1. Full dynamic-circuit execution engine is not yet implemented (validation + explicit boundary is implemented).
2. Hardware-provider integrations and calibration depth are still growing.
3. Large-scale simulator alternatives (for example tensor-network/MPS paths) are still planned.

References:

- [docs/roadmap.md](roadmap.md)
- [docs/v0.3-feature-spec.md](v0.3-feature-spec.md)
