# docs-sync

## When To Use
Use after any change that can affect docs, onboarding, architecture guidance, or playbook accuracy.

## Required Reading
- `AGENTS.md`
- `README.md`
- `docs/development-flow.md`
- any changed docs under `docs/`

## Step-by-Step Workflow
1. Identify impacted docs from changed files and behavior.
2. Update authoritative docs first (`README`, `docs/development-flow.md`, architecture/spec docs).
3. Builder: apply minimal doc edits that match implementation.
4. Critic: remove contradictions, stale commands, and narrative drift.
5. Verifier: run `mix docs.build` when doc sets change materially.
6. Ensure links to playbooks/skills remain valid.

## Output Requirements
- Updated docs aligned with code behavior and contracts.
- Explicit note of any known limitations or deferred docs.

## Quality Criteria
- No contradictions across README, roadmap, architecture, and workflow docs.
- Commands and file paths are executable and current.
- Specialized guidance lives in playbooks, not duplicated in core flow docs.
