# spec-feature

## When To Use
Use for new user-visible behavior, scoped feature increments, or provider-facing capability additions.

## Required Reading
- `AGENTS.md`
- `docs/roadmap.md`
- `docs/development-flow.md`
- `docs/bounded-context-map.md`

## Step-by-Step Workflow
1. Define acceptance criteria in deterministic terms (inputs, outputs, tolerance, errors).
2. Update or add Gherkin scenarios in `features/*.feature`.
3. Map scenario to bounded context in `docs/bounded-context-map.md`.
4. Builder: add failing feature steps and minimal failing unit/property tests.
5. Implement minimal behavior-complete code through domain/application first.
6. Critic: run `architecture-review` checks for boundary and coupling drift.
7. Verifier: run `mix test.features` plus targeted `mix test.unit`/`mix test.property`.
8. Sync docs with `docs-sync` and emit handoff.

## Output Requirements
- Updated feature scenario(s) and step definitions.
- Deterministic tests proving new behavior.
- Bounded-context mapping update when scope changed.
- Handoff block in the root `AGENTS.md` format.

## Quality Criteria
- Acceptance criteria are measurable and deterministic.
- No architecture boundary violations.
- Behavior is covered by at least one acceptance path and one supporting test suite.
- Risks and assumptions are explicit.
