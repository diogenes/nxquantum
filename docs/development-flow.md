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
3. Run `principal-architect-product-strategy` on the implementation plan before Builder work.
4. Write failing tests first:
   - feature steps in `test/features/steps/*_steps.ex`
   - unit/property/contract tests in `test/`
5. Builder stage: implement minimal change in domain/application first.
6. Critic stage: run architecture review for boundary and coupling violations.
7. Verifier stage: run deterministic quality gates.
8. Sync docs, examples, and roadmap references.
9. Emit handoff using the required `AGENTS.md` format.

### 3.1) Plan Review Gate Criteria (`principal-architect-product-strategy`)
- Confirm user outcome and roadmap fit are explicit and measurable.
- Confirm bounded-context ownership and dependency direction are explicit.
- Confirm API stability impact and migration expectations are explicit.
- Confirm deterministic verification and benchmark evidence strategy exists before implementation.
- Record pass/fail plus risks in handoff `Plan review`.

## 4) Deterministic Quality Gates
- Baseline gate: `mix quality`
- Contract gate: `mix test.arch` and relevant provider contract suites
- Verification gate: `mix test.features`, `mix test.unit`, `mix test.property`, `mix test.domain_coverage`
- Release gate: `mix ci`

`mix test.domain_coverage` is a hard gate: all configured domain modules must be at `100.00%` line coverage.

Benchmark evidence is required for non-trivial performance work under `bench/` with fixed seeds and reproducible runtime settings.

## 5) PR Expectations
- State change intent (`feature`, `refactor`, `api change`, `performance`, `provider integration`, `release`).
- Include `principal-architect-product-strategy` review outcome and risk notes.
- List selected skills and resulting artifacts.
- Include deterministic evidence (tests/benchmarks/docs).
- Call out risks, assumptions, and next best step.

## 6) Specialized Flows
Use playbooks for specialized work:
- `docs/playbooks/topology-routing.md`
- `docs/playbooks/observability.md`
- `docs/playbooks/provider-release-hardening.md`
- `docs/playbooks/provider-contracts.md`
