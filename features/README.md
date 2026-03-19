# Feature Specs

This folder contains product behavior specs in Gherkin.

## Canonical Execution Path

- Specs live in `features/*.feature`.
- Feature execution code lives in `test/features/` under `NxQuantum.Features.*`.
- The feature suite entrypoint is `test/features/features_test.exs`.

Run all feature specs with:

```bash
mix test.features
```

## Structure

- `test/features/parser.ex`: Gherkin parser.
- `test/features/runner.ex`: scenario runner.
- `test/features/step_registry.ex`: feature-to-step-module wiring.
- `test/features/steps/*.ex`: one focused step module per feature file.
- `test/support/test_support/*.ex`: shared helpers, fixtures, factories, and doubles.
- `.vscode/cucumber-glue/steps.js`: editor-only generated glue for Cucumber extension step discovery.

## Contribution Rules

1. Update or add a `.feature` first.
2. Add or update the matching step module in `test/features/steps/`.
3. Regenerate editor glue with `mix features.sync_glue`.
4. Add/adjust unit or property tests in `test/nx_quantum/` and `test/property/`.
5. Implement production code until feature + unit/property suites are green.
