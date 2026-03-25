# verification

## When To Use
Use for all behavior work requiring acceptance, unit, property, and contract evidence.

## Required Reading
- `AGENTS.md`
- `docs/testing-strategy.md`
- `docs/development-flow.md`

## Step-by-Step Workflow
1. Translate behavior into deterministic acceptance scenarios first.
2. Add or update failing step definitions under `test/features/steps/`.
3. Add focused unit tests for deterministic logic paths.
4. Add property tests for invariants (normalization, symmetry, determinism) when relevant.
5. Add contract tests for provider/port boundaries when interfaces change.
6. Critic: challenge flaky assertions, implicit randomness, and vague expectations.
7. Verifier: run `mix test.features`, `mix test.unit`, `mix test.property`, and targeted contract suites.

## Output Requirements
- Acceptance coverage for each user-visible behavior.
- Deterministic test evidence with seeds/tolerances documented.
- Updated fixtures or test support utilities when needed.

## Quality Criteria
- No hidden randomness.
- Assertions are explicit and non-vague.
- Failure modes are typed and testable.
