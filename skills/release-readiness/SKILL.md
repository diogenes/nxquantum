# release-readiness

## When To Use
Use for release candidates, release branches, or final merge batches with contract/performance/doc impacts.

## Required Reading
- `AGENTS.md`
- `docs/release-process.md`
- `docs/playbooks/provider-release-hardening.md`
- `CHANGELOG.md`

## Step-by-Step Workflow
1. Confirm release scope, intended contracts, and known limits.
2. Builder: finalize minimal remaining changes needed for release criteria.
3. Critic: review risk areas (API drift, provider contracts, benchmark claims, docs drift).
4. Verifier: run `mix quality`, `mix dialyzer`, `mix test.release_evidence`, and `mix ci`.
5. Ensure benchmark evidence exists for performance claims.
6. Sync changelog and release notes with verified behavior.
7. Emit final handoff with clear go/no-go signal.

## Output Requirements
- Release evidence summary (tests, contracts, benchmarks, docs).
- Updated changelog/release notes.
- Explicit residual risk list.

## Quality Criteria
- Quality gates are green.
- Contract and migration impacts are documented.
- Release notes match actual validated behavior.
