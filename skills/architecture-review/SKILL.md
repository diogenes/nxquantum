# architecture-review

## When To Use
Use for any change that may affect DDD boundaries, ports/adapters contracts, ownership, or module coupling.

## Required Reading
- `AGENTS.md`
- `docs/architecture.md`
- `docs/bounded-context-map.md`
- relevant `docs/adr/*.md`

## Step-by-Step Workflow
1. Identify owning bounded context and expected dependency direction.
2. Inspect changed modules for adapter leakage into domain/application.
3. Validate port contracts remain stable and technology-agnostic.
4. Builder support: propose smallest structural fix that restores boundary clarity.
5. Critic: run `mix test.arch` and inspect dependency/coupling hotspots.
6. Verifier: run impacted acceptance/unit suites.
7. Record architecture impact and residual risk in handoff.

## Output Requirements
- Boundary review summary with pass/fail findings.
- List of required refactors or ADR updates.
- Confirmed ownership of touched contexts and modules.

## Quality Criteria
- Domain/application layers are free of provider/adapter-specific details.
- Ports are stable contracts, not implementation containers.
- Any boundary strategy change is documented in ADR/docs.
