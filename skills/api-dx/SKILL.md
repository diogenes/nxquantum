# api-dx

## When To Use
Use for public API additions, API behavior changes, naming/ergonomics updates, and developer onboarding flow changes.

## Required Reading
- `AGENTS.md`
- `docs/api-stability.md`
- `docs/development-flow.md`
- `README.md`

## Step-by-Step Workflow
1. Confirm whether intent is additive or breaking.
2. Define deterministic API acceptance behavior and error contracts.
3. Builder: add failing tests for public contract changes.
4. Implement minimal API changes with typespecs and docs in the same pass.
5. Critic: verify pipe-friendliness, consistency, and migration impact.
6. Verifier: run `mix test.unit`, relevant `mix test.features`, and `mix dialyzer` for contract-heavy changes.
7. Sync README/examples/changelog guidance.

## Output Requirements
- Updated public module docs and typespecs.
- Passing tests covering new or changed API behavior.
- Explicit migration note for behavior changes.

## Quality Criteria
- API surface is coherent and discoverable.
- No undocumented public contract drift.
- Examples compile against actual function contracts.
