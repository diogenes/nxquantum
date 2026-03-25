# refactor-ddd

## When To Use
Use for structural refactors that improve boundaries, ownership, and coupling without changing public behavior.

## Required Reading
- `AGENTS.md`
- `docs/architecture.md`
- `docs/bounded-context-map.md`
- relevant `docs/adr/*.md`

## Step-by-Step Workflow
1. Define refactor objective and protected public contracts.
2. Map touched modules to bounded contexts.
3. Builder: stage refactor in small slices with tests guarding behavior.
4. Critic: inspect dependency direction and responsibility clarity.
5. Verifier: run acceptance/contract suites plus `mix test.arch`.
6. Update context map and architecture docs when ownership shifts.
7. Emit handoff with explicit risk and rollback notes.

## Output Requirements
- Refactor slices with stable behavior evidence.
- Updated context-map/architecture docs when structure changed.
- Explicit list of moved/extracted responsibilities.

## Quality Criteria
- Public behavior remains stable unless explicitly co-signed as API change.
- Coupling is reduced or unchanged.
- Ownership boundaries are clearer after refactor.
