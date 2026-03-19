# Skill: TDD + BDD

## Goal

Drive implementation from behavior scenarios and fast feedback loops.

## Workflow

1. Write or refine scenario in `features/*.feature`.
2. Add or update step implementations in `test/features/steps/`.
3. Ensure scenario execution is covered by `test/features/features_test.exs`.
4. Add focused unit/property tests in `test/`.
5. Implement minimal code to pass tests.
6. Refactor for readability and architecture boundaries.
7. Remove pending tags once behavior is implemented.

## Checklist

- Scenario exists.
- Feature step module references scenario language.
- Unit/property tests cover edge cases.
- Public docs/examples updated if API changed.
