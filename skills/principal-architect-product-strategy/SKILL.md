# principal-architect-product-strategy

## When To Use
Use before Builder work for every change intent to validate plan quality across product value, architecture integrity, and deterministic delivery evidence.

## Required Reading
- `AGENTS.md`
- `docs/roadmap.md`
- `docs/development-flow.md`
- `docs/architecture.md`
- `docs/bounded-context-map.md`
- `docs/product-positioning.md`
- `docs/quantum-llm-vision.md`
- `docs/decision-matrix.md`
- `docs/api-stability.md`

## Step-by-Step Workflow
1. Review the proposed behavior against roadmap phase, user value, and positioning constraints.
2. Confirm owning bounded context and dependency direction (`Domain <- Application <- Adapters`).
3. Identify public API stability risk (`stable`, `experimental`, or `api change` required).
4. Validate deterministic verification strategy (acceptance + unit/property/contract) and benchmark evidence strategy when performance-sensitive.
5. Builder support: tighten scope to the smallest behavior-complete increment with explicit acceptance criteria.
6. Critic: challenge vague outcomes, provider-breadth overclaims, and hidden architecture coupling.
7. Verifier: require concrete evidence plan (`mix` commands, suites, and benchmark scripts) before implementation starts.

## Output Requirements
- Plan review decision: `pass`, `pass with risks`, or `fail`.
- Product-quality summary: user outcome, differentiator alignment, and messaging risks.
- Architecture-quality summary: bounded context ownership, dependency direction, and contract impact.
- Evidence plan: deterministic tests/benchmarks to run and expected artifacts.
- Explicit risk list and required mitigation actions.

## Quality Criteria
- Plan protects deterministic-by-default commitments and avoids unsupported public claims.
- Plan preserves hexagonal/DDD boundaries with explicit ownership.
- API changes are intentionally routed and documented.
- Verification and benchmark evidence are defined before coding starts.
