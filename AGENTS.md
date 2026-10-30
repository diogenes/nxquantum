# AGENTS.md

## Mission
Build NxQuantum as a high-performance, deterministic, BEAM-native quantum ML library with clean DDD + hexagonal boundaries and stable public APIs.

## Non-Negotiable Invariants
- Keep dependency direction strict: domain and application depend on ports, never adapters.
- Never leak provider-specific payloads or SDK semantics into domain/application modules.
- Keep tests deterministic: fixed seeds, fixed fixtures, explicit tolerances, no hidden randomness.
- Keep public API contracts stable unless change intent is explicitly `api change` and docs are updated.
- Any non-trivial performance change must include reproducible benchmark evidence.
- Public messaging must lead with deterministic quantum execution on BEAM and present hybrid quantum-AI only as an application of it; cite benchmarks only as internal, environment-specific references, never as official results or the lead proof; never imply universal provider breadth or deterministic live-QPU outcomes without explicit evidence.

## Required Reading By Task Type
| Task type | Required reading |
| --- | --- |
| Feature delivery | `docs/roadmap.md`, `docs/development-flow.md`, `docs/bounded-context-map.md` |
| Architecture/refactor | `docs/architecture.md`, `docs/bounded-context-map.md`, relevant `docs/adr/*.md` |
| API/DX | `docs/api-stability.md`, `docs/development-flow.md`, `README.md` |
| Positioning/docs | `README.md`, `docs/product-positioning.md`, `docs/vision.md`, `docs/decision-matrix.md`, latest `docs/python-alternatives-benchmark-*.md` |
| Verification | `docs/testing-strategy.md`, `docs/development-flow.md` |
| Kernel/performance | `docs/performance-matrix.md`, latest `docs/python-alternatives-benchmark-*.md`, `docs/axon-integration.md` |
| Provider integration/contracts | `docs/playbooks/provider-contracts.md`, `docs/migration-python-playbook.md`, `docs/python-comparison-workflows.md` |
| Release | `docs/release-process.md`, `docs/playbooks/provider-release-hardening.md`, `CHANGELOG.md` |

## Default Execution Sequence
1. Clarify behavior and acceptance criteria.
2. Run `principal-architect-product-strategy` plan review (product quality + architecture quality).
3. Confirm architecture boundaries and owning bounded context.
4. Write failing deterministic tests first.
5. Implement the minimal solution.
6. Wire adapters behind ports.
7. Run quality gates.
8. Update docs and examples.
9. Produce handoff.

## Plan -> Producer -> Critic -> Verifier Loop (Required)
1. Principal Architect + Product Strategist: review the plan for product-fit clarity, architecture boundary safety, API stability risk, and deterministic evidence strategy before code changes.
2. Builder: implement the smallest behavior-complete change.
3. Critic: challenge boundary integrity, coupling, and API drift before merge.
4. Verifier: prove determinism and coverage with acceptance/unit/property/contract checks.
5. Docs Sync: align `README`, `docs/`, playbooks, and roadmap references.

### Agent Team (activation by intent)
Seats advise in parallel; the Lead merges their notes into the single plan review. Builder starts only after that merge. Conflicts are decided by the Lead and recorded in the handoff `Plan review`. Evidence beats advocacy: a contested claim is cut back until evidence supports it.

| Intent | Seats active |
| --- | --- |
| feature | Lead, Product strategy, DX, Critic, Verifier, Docs |
| api change | Lead, DX, Critic, Verifier, Docs |
| performance | Lead, Quantum physics/math, Critic, Verifier (benchmark), Docs |
| provider integration | Lead, Quantum engineering, Critic, Verifier (contract tests), Docs |
| refactor | Lead, Critic, Verifier |
| release | Lead, Release readiness, Verifier, Docs |

Vetoes (each maps to a stop rule or merge blocker):
- Critic (architecture): domain or application depends on adapter or provider detail.
- DX: public API change without `api change` intent.
- Quantum physics/math: numerical claim without analytic reference or tolerance.
- Quantum engineering: live-hardware outcome claimed as deterministic.
- Verifier: `mix quality` or domain coverage fails; performance work lacks benchmark delta.
- Docs sync (claims audit): claim lacks in-repo evidence.
- Elixir code quality: advisory only (owner decision 2026-10-18); findings go to handoff `Risks`.


## Change-Intent Routing Matrix
| Change intent | Required skills |
| --- | --- |
| feature | `principal-architect-product-strategy`, `spec-feature`, `verification`, `docs-sync` |
| refactor | `principal-architect-product-strategy`, `refactor-ddd`, `architecture-review`, `verification`, `docs-sync` |
| api change | `principal-architect-product-strategy`, `api-dx`, `verification`, `architecture-review`, `docs-sync` |
| performance | `principal-architect-product-strategy`, `kernel-performance`, `verification`, `architecture-review`, `docs-sync` |
| provider integration | `principal-architect-product-strategy`, `spec-feature`, `architecture-review`, `verification`, `docs-sync` |
| release | `principal-architect-product-strategy`, `release-readiness`, `docs-sync` |

## Stop Rules
Stop immediately and report when any of these occurs:
- boundary violation (domain/application depending on adapters/provider details)
- missing deterministic acceptance criteria
- required verification is inherently nondeterministic and no deterministic fallback is defined
- accidental API-breaking change without explicit `api change` intent
- new dependency introduced without architecture ownership and justification
- unclear bounded-context ownership
- missing or failed `principal-architect-product-strategy` plan review before Builder stage

## Merge Blockers
- failing `mix quality`
- failing `mix dialyzer` when contract-affecting code changed
- missing acceptance coverage for user-visible behavior
- missing contract tests for port/provider changes
- failing `mix test.domain_coverage` (domain modules must remain at 100% line coverage)
- missing benchmark delta for non-trivial performance work
- docs drift between implementation and `README`/`docs/*`
- missing plan-review evidence from `principal-architect-product-strategy` in handoff
- missing mandatory handoff format

## HANDOFF
### Summary
### Changed files
### Behavior impact
### Architecture impact
### Plan review
### Evidence
- Commands run:
- Tests:
- Benchmarks:
### Risks
### Next best step
