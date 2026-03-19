# Contributing to NxQuantum

## First Principles

- Prefer correctness and determinism over premature optimization.
- Keep the domain model explicit and immutable.
- Add tests before implementation (TDD), then add feature-scenario coverage for user-visible behavior.
- Preserve the pipe-first API ergonomics.

## Project Layout

- `lib/nx_quantum/`: source modules.
- `test/`: unit, property, and feature tests.
- `test/support/test_support/`: shared helpers, fixtures, factories, and doubles.
- `features/`: Gherkin feature definitions.
- `docs/`: architecture, roadmap, ADRs.
- `skills/`: reusable contributor workflows.

## Environment and Tooling

`mix` is the canonical workflow for this repository.

`mix` does not pin Erlang/Elixir versions, so we use `mise` for toolchain reproducibility:

```bash
mise trust
mise install
mix setup
```

Daily commands:

- `mix test`
- `mix test.features`
- `mix features.sync_glue`
- `mix quality`
- `mix dialyzer`
- `mix docs.build`
- `mix ci`

## TDD Workflow

1. Start from a `.feature` or acceptance scenario.
2. Add/adjust unit tests for domain behavior.
3. Implement the smallest change in domain/application layers.
4. Wire adapters only after port contract is stable.
5. Refactor with tests green.

## Quality Gates

- `mix quality`
- `mix dialyzer`
- `mix docs.build`
- `mix ci`

## Commit and Review Conventions

- One coherent change per commit.
- Include motivation + architectural impact in PR description.
- Attach benchmark notes for performance-sensitive changes (`benchee` scripts under `bench/`).
- For new behavior, update:
  - relevant `.feature` files,
  - matching step modules in `test/features/steps/`,
  - unit/property tests and API docs.

## Performance Guidelines

- Keep tensor code in `Nx.Defn`-friendly boundaries.
- Avoid unnecessary host-device transfers.
- Batch operations when possible (vectorized gate application).
- Add property tests around numerical invariants before optimizing kernels.
