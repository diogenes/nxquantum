# NxQuantum Agent Team

Claude Code subagent definitions for NxQuantum development. Each file is one seat from the Plan → Producer → Critic → Verifier loop in `AGENTS.md`.

These files hold scope, domain context, and stop rules. They do not hold process. Process lives in `AGENTS.md`, procedures in `skills/*/SKILL.md`, and facts in `docs/`. When one of those changes, update the source and leave the agent pointing at it.

## Start a session

```bash
claude --agent engineering-manager
```

The coordinator runs as the main session because a subagent cannot start other subagents. Seats are dispatched from there through the Agent tool.

## Roster

| Seat | Model | Can edit | Role |
| --- | --- | --- | --- |
| `engineering-manager` | opus | no | Intake, prioritization, seat activation, handoff |
| `principal-architect` | opus | no | Plan review gate |
| `product-strategist` | opus | no | Audience fit, Kano, D1, claims |
| `architecture-critic` | opus | no | Boundaries, coupling, API drift |
| `quantum-physics-verifier` | opus | no | References, tolerances, seeds for numerical claims |
| `distributed-systems-engineer` | opus | yes | H2 determinism, fan-out, ADR 0012 |
| `sustainable-systems-architect` | opus | no | Contract longevity, dependency cost, evidence longevity |
| `quantum-engineering` | sonnet | yes | Provider adapters, lanes, envelopes, FluxQ contract |
| `elixir-beam-engineer` | sonnet | yes | OTP, typespecs, credo/dialyzer |
| `ml-nx-engineer` | sonnet | yes | Hybrid paths, baselines, dataset provenance |
| `kernel-performance` | sonnet | yes | Benchmarks and before/after deltas |
| `api-dx` | sonnet | yes | Public API, examples, time to first result |
| `verifier` | sonnet | no | Gates, determinism, evidence presence |
| `docs-sync` | sonnet | yes | Claims audit, drift |
| `release-readiness` | sonnet | no | Go/no-go |

Model choices are a starting point. Change them in each file's frontmatter if cost or depth needs to shift.

## Intent → seats (from `AGENTS.md`)

| Intent | Seats |
| --- | --- |
| feature | product-strategist, api-dx, verifier, docs-sync, + domain seat |
| api change | api-dx, architecture-critic, verifier, docs-sync |
| performance | quantum-physics-verifier, kernel-performance, verifier, architecture-critic, docs-sync |
| provider integration | quantum-engineering, architecture-critic, verifier, docs-sync |
| refactor | architecture-critic, verifier |
| release | release-readiness, verifier, docs-sync |

`principal-architect` runs first on every intent. It is the gate.

## Known gaps in this roster

- **Not created:** a dedicated computer-science or algorithms seat. Complexity questions go to `kernel-performance` and `architecture-critic`. Add a seat only when a recurring question has no owner.
- **Not created:** a product-marketing seat. The roadmap assigns it to the owner; `product-strategist` and `docs-sync` cover the claims side.
- **Unverified:** the CLI in this environment (2.1.307) does not list project agent definitions. `claude agents` shows background sessions only. Confirm discovery by starting `claude --agent engineering-manager` and checking that the seats appear in the Agent tool's list.
- **Resolved (2026-10-25):** the roadmap's Seats fields keep their names ("Lead", "DX", "Critic", "Quantum physics/math"). `docs/roadmap.md` now has a legend that maps each name to its agent file, so the roadmap is not renamed.

## Rules for editing these files

- Keep each file to what the seat decides, what it reads, and what it refuses. Link to the source instead of copying it.
- Keep `tools` to the minimum the seat needs. Advisory seats get no `Edit` or `Write`.
- A stop rule here must match `AGENTS.md`. If they diverge, `AGENTS.md` wins and this file gets fixed.
