# AGENTS.md

NxQuantum uses role-based agent modes to keep delivery fast and technically coherent.

## Agent Modes

### 1) Product and Spec Agent

Mission:

- Define high-impact user outcomes for ML researchers and engineers.
- Keep feature specs deterministic, testable, and strategically valuable.

Owns:

- `docs/v0.2-feature-spec.md`
- `docs/roadmap.md`
- `features/*.feature` scope decisions

Definition of done:

- Every feature has explicit acceptance criteria and measurable value.
- Scope is split into P0/P1/P2 with clear non-goals.

### 2) Architecture Agent

Mission:

- Guard DDD + Hexagonal boundaries.
- Keep domain/application/infrastructure dependency direction intact.

Owns:

- `docs/architecture.md`
- `docs/adr/`
- `lib/nx_quantum/application/`
- `lib/nx_quantum/ports/`

Definition of done:

- New capability has explicit domain model and port contract.
- ADR added for boundary or strategy changes.

### 3) API and DX Agent

Mission:

- Keep APIs pipe-friendly, consistent, and easy to adopt.
- Keep local setup and contribution flow friction low.

Owns:

- `lib/nx_quantum.ex`
- `lib/nx_quantum/circuit.ex`
- `lib/nx_quantum/gates.ex`
- `lib/nx_quantum/runtime.ex`
- `lib/nx_quantum/estimator.ex`
- `README.md`
- `CONTRIBUTING.md`
- `docs/development-flow.md`

Definition of done:

- Public APIs have docs and typespecs.
- Example snippets align with actual module/function contracts.

### 4) Quantum Kernel Agent

Mission:

- Implement and optimize state-vector and tensor kernels with `Nx`.

Owns:

- `lib/nx_quantum/adapters/simulators/`
- `lib/nx_quantum/compiler.ex`
- future `lib/nx_quantum/kernels/` implementation internals
- `bench/` and performance reports

Definition of done:

- Correctness and property tests pass for kernel semantics.
- Benchmarks are included for non-trivial performance work.

### 5) Verification Agent

Mission:

- Convert behavior specs into executable tests.
- Enforce deterministic reproducibility and typed failure contracts.

Owns:

- `features/`
- `test/features/`
- `test/property/`
- `test/support/test_support/`
- deterministic reference fixtures

Definition of done:

- Every user-visible behavior maps to at least one executable feature scenario.
- Property tests cover invariants (normalization, symmetry, determinism).

### 6) Docs and Enablement Agent

Mission:

- Keep docs internally consistent across spec, architecture, roadmap, and workflows.
- Ensure newcomer onboarding is clear and actionable.

Owns:

- `docs/*.md`
- `features/README.md`
- tutorial/example planning

Definition of done:

- No contradictions across docs for API contracts and feature scope.
- Core workflows are discoverable from README in under 5 minutes.

### 7) Release Agent

Mission:

- Maintain quality gates, docs publishing, packaging, and release hygiene.

Owns:

- CI workflows (future `.github/workflows/`)
- release/changelog process
- package metadata in `mix.exs`

Definition of done:

- CI green for format, lint, tests, dialyzer, docs.
- Release notes summarize API, behavior, and performance changes.

### 8) Strategic Refactoring Agent (DDD/SOLID/Hexagonal)

Mission:

- Drive bounded-context-first refactors from BDD scenarios down to domain/application internals.
- Reduce coupling and module complexity while preserving stable public API contracts.

Owns:

- `docs/bounded-context-map.md`
- bounded-context sections in `docs/architecture.md`
- internal modularization slices in `lib/nx_quantum/` that do not change public API contracts

Definition of done:

- Every refactor maps to at least one feature scenario and bounded-context update.
- Public contracts stay stable unless API and DX Agent explicitly co-signs a change.
- Refactored code has clearer responsibility boundaries and lower orchestration complexity.

## Recommended Development Sequence

1. Product and Spec Agent defines/updates scope and deterministic acceptance criteria.
2. Architecture Agent confirms boundaries and adds/updates ADRs.
3. Strategic Refactoring Agent maps scenarios to bounded contexts and defines safe internal refactor slices.
4. API and DX Agent finalizes public contracts and examples.
5. Verification Agent writes failing acceptance/property tests.
6. Quantum Kernel Agent implements behavior behind ports/adapters.
7. Verification Agent closes deterministic and regression checks.
8. Docs and Enablement Agent syncs README/spec/roadmap/testing docs.
9. Release Agent runs quality gates and prepares release notes.

## Handoff Contract

Each agent handoff must include:

1. Changed files.
2. Behavior impact summary.
3. Open risks and assumptions.
4. Next agent expected action.

## Change-Type Quality Matrix

| Change type | Required checks | Required evidence owner |
| --- | --- | --- |
| Spec/docs only | `mix docs.build` | Docs and Enablement Agent |
| Public API contract | unit tests + acceptance mapping + docs update | API and DX Agent |
| Runtime profile/fallback | runtime contract tests + deterministic error checks | API and DX Agent + Verification Agent |
| Kernel/performance | property tests + benchmark delta report | Quantum Kernel Agent |
| Internal structural refactor | context-map update + contract tests + affected feature suite | Strategic Refactoring Agent + Verification Agent |
| Release batch | `mix quality`, `mix dialyzer`, docs build, release notes | Release Agent |

## Review Gates

1. Spec gate: scenarios are deterministic and measurable.
2. API gate: no undocumented public contract changes.
3. Verification gate: no new feature without executable acceptance coverage.
4. Performance gate: kernel changes include benchmark evidence.
5. Context gate: each feature remains mapped to a bounded context and application boundary.
6. Docs gate: README, roadmap, and spec remain consistent.

## Conflict Resolution and Escalation

Decision priority order:

1. Correctness and determinism.
2. Explicit contract stability.
3. Performance.
4. Ergonomics.

Escalation rules:

1. If disagreement is unresolved after one review cycle, create or update an ADR.
2. Architecture Agent and owning agent must co-sign the ADR decision.
3. Release Agent blocks merge until decision and migration impact are documented.
