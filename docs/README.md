# NxQuantum documentation map

Start here to find a document by what you want to do. Each concern has one owning document; other documents link to it instead of restating it.

## Is NxQuantum for me?

| Document | Owns |
| --- | --- |
| [product-positioning.md](product-positioning.md) | The one line, positioning statement, audience tiers, what you can rely on today (with evidence), and when to choose NxQuantum or a Python-first stack |
| [python-comparison-workflows.md](python-comparison-workflows.md) | Side-by-side workflows against Python-first stacks |
| [provider-support-catalog.md](provider-support-catalog.md) | Provider support tiers, lanes, and limits |

## Get a first result

| Document | Owns |
| --- | --- |
| [getting-started.md](getting-started.md) | Install from Hex and run a first expectation, seeded sample, and typed error |
| [livebook-tutorials.md](livebook-tutorials.md) | The Livebook notebooks and what each one checks |

## Build with NxQuantum

| Document | Owns |
| --- | --- |
| [model-recipes.md](model-recipes.md) | Short recipes: kernels, hybrid scalar heads, shot-based evaluation |
| [axon-integration.md](axon-integration.md) | Training steps that differentiate through quantum expectations |
| [backend-support.md](backend-support.md) | Runtime profiles, simulation paths, and the numerical precision floor |
| [standalone-integration-profiles.md](standalone-integration-profiles.md) | Standalone and external integration profiles |
| [case-study-beam-integration.md](case-study-beam-integration.md) | Illustrative pattern for a supervised BEAM service (not a user report) |
| [hybrid-quantum-ai-integration-guide.md](hybrid-quantum-ai-integration-guide.md) | Hybrid quantum-AI integration (an application of the core, not the lead) |
| [turboquant-rerank-guide.md](turboquant-rerank-guide.md) | TurboQuant-inspired rerank compression |

## Migrate from Python

| Document | Owns |
| --- | --- |
| [migration-python-playbook.md](migration-python-playbook.md) | Moving one workflow at a time |
| [migration-packs.md](migration-packs.md) | Provider-specific migration packs |

## Operate in production

| Document | Owns |
| --- | --- |
| [observability.md](observability.md) | Span, metric, and log names and the emitter port |
| [observability-dashboards.md](observability-dashboards.md) | Dashboard layouts |
| [playbooks/observability.md](playbooks/observability.md) | Observability procedure |
| [playbooks/provider-contracts.md](playbooks/provider-contracts.md) | Provider contract procedure |
| [playbooks/provider-release-hardening.md](playbooks/provider-release-hardening.md) | Provider release hardening |
| [playbooks/topology-routing.md](playbooks/topology-routing.md) | Topology routing procedure |
| [playbooks/quantum-ai-rollout.md](playbooks/quantum-ai-rollout.md) | Quantum-AI rollout gates |

## Contracts and reference

| Document | Owns |
| --- | --- |
| [api-stability.md](api-stability.md) | Stable and experimental tiers, envelope compatibility policy, dependency policy |
| [quantum-ai-tool-contracts.md](quantum-ai-tool-contracts.md) | Versioned AI tool contracts |
| [hybrid-quantum-ai-benchmark.md](hybrid-quantum-ai-benchmark.md) | Hybrid benchmark and dataset spec (synthetic data, placeholder figures) |
| [performance-matrix.md](performance-matrix.md) | Performance matrix and guards |
| [provider-benchmark-matrix.md](provider-benchmark-matrix.md) | Internal provider lifecycle benchmark (fixture lane) |
| [python-alternatives-benchmark-2026-03-25.md](python-alternatives-benchmark-2026-03-25.md) | Historical internal benchmark reference (methodology superseded) |

## Design

| Document | Owns |
| --- | --- |
| [architecture.md](architecture.md) | Layering and dependency rules |
| [bounded-context-map.md](bounded-context-map.md) | Bounded contexts, owned features, and invariants |
| [adr/](adr/) | Architecture decision records |

## Product strategy and governance

| Document | Owns |
| --- | --- |
| [vision.md](vision.md) | Long-horizon strategy: north star, thesis, audience model, ERRC and strategy canvas, horizons, decision gates, non-goals, parked ideas |
| [roadmap.md](roadmap.md) | Execution: milestones, known gaps (KG-n), and the Decision Log |
| [research/](research/) | Research inputs: the Kano survey and the 2025–2026 algorithm landscape |
| [launch/](launch/) | Launch drafts (not published) |

## Contribute

| Document | Owns |
| --- | --- |
| [../CONTRIBUTING.md](../CONTRIBUTING.md) | Contributor entry point |
| [development-flow.md](development-flow.md) | Commands, quality gates, PR expectations |
| [testing-strategy.md](testing-strategy.md) | Test layers and determinism rules |
| [release-process.md](release-process.md) | Release cut and checks |
| [../AGENTS.md](../AGENTS.md), [../SKILLS.md](../SKILLS.md) | Agent team, invariants, and skills |

## History

- [archive/](archive/): version-named specs, plans, and superseded benchmark runs. History only; not maintained.
- [decision-matrix.md](decision-matrix.md): pointer stub, merged into `product-positioning.md` on 2026-10-30.
