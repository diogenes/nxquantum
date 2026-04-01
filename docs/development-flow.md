# Development Flow

## 1) Setup
Use `mix` as the primary interface and `mise` for pinned toolchains.

```bash
mise trust
mise install
mix setup
```

## 2) Command Reference
- `mix test`
- `mix test.unit`
- `mix test.property`
- `mix test.arch`
- `mix test.domain_coverage`
- `mix test.features`
- `mix test.provider_smoke`
- `mix test.release_evidence`
- `mix quality`
- `mix dialyzer`
- `mix docs.build`
- `mix ci`

If shell activation is missing:

```bash
mise exec -- mix ci
```

## 3) Core Behavior-First Loop
1. Define or update behavior in `features/*.feature` with deterministic acceptance criteria.
2. Map scenario ownership in `docs/bounded-context-map.md`.
3. Write failing tests first:
   - feature steps in `test/features/steps/*_steps.ex`
   - unit/property/contract tests in `test/`
4. Builder stage: implement minimal change in domain/application first.
5. Critic stage: run architecture review for boundary and coupling violations.
6. Verifier stage: run deterministic quality gates.
7. Sync docs, examples, and roadmap references.
8. Emit handoff using the required `AGENTS.md` format.

## 4) Deterministic Quality Gates
- Baseline gate: `mix quality`
- Contract gate: `mix test.arch` and relevant provider contract suites
- Verification gate: `mix test.features`, `mix test.unit`, `mix test.property`, `mix test.domain_coverage`
- Release gate: `mix ci`

`mix test.domain_coverage` is a hard gate: all configured domain modules must be at `100.00%` line coverage.

Benchmark evidence is required for non-trivial performance work under `bench/` with fixed seeds and reproducible runtime settings.

## 5) PR Expectations
- State change intent (`feature`, `refactor`, `api change`, `performance`, `provider integration`, `release`).
- List selected skills and resulting artifacts.
- Include deterministic evidence (tests/benchmarks/docs).
- Call out risks, assumptions, and next best step.

## 6) Specialized Flows
Use playbooks for specialized work:
- `docs/playbooks/topology-routing.md`
- `docs/playbooks/observability.md`
- `docs/playbooks/provider-release-hardening.md`
- `docs/playbooks/provider-contracts.md`
