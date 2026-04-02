# AGENTS.md

## Mission
Build NxQuantum as a high-performance, deterministic, BEAM-native quantum ML library with clean DDD + hexagonal boundaries and stable public APIs.

## Non-Negotiable Invariants
- Keep dependency direction strict: domain and application depend on ports, never adapters.
- Never leak provider-specific payloads or SDK semantics into domain/application modules.
- Keep tests deterministic: fixed seeds, fixed fixtures, explicit tolerances, no hidden randomness.
- Keep public API contracts stable unless change intent is explicitly `api change` and docs are updated.
- Any non-trivial performance change must include reproducible benchmark evidence.
- Public messaging must foreground deterministic, BEAM-native, benchmark-backed hybrid quantum-AI workflows; never imply universal provider breadth or deterministic live-QPU outcomes without explicit evidence.

## Required Reading By Task Type
| Task type | Required reading |
| --- | --- |
| Feature delivery | `docs/roadmap.md`, `docs/development-flow.md`, `docs/bounded-context-map.md` |
| Architecture/refactor | `docs/architecture.md`, `docs/bounded-context-map.md`, relevant `docs/adr/*.md` |
| API/DX | `docs/api-stability.md`, `docs/development-flow.md`, `README.md` |
| Positioning/docs | `README.md`, `docs/product-positioning.md`, `docs/quantum-llm-vision.md`, `docs/decision-matrix.md`, latest `docs/python-alternatives-benchmark-*.md` |
| Verification | `docs/testing-strategy.md`, `docs/development-flow.md` |
| Kernel/performance | `docs/v0.9-high-value-performance-matrix.md`, `docs/python-alternatives-benchmark-2026-03-25.md`, `docs/axon-integration.md` |
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
