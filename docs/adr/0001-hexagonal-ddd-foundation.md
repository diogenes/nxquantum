# ADR 0001: Adopt DDD + Hexagonal Foundation

- Status: Accepted
- Date: 2026-03-17

## Context

NxQuantum must balance:

- mathematical correctness,
- high-performance backend execution,
- API ergonomics for Elixir pipelines,
- long-term extensibility (new simulators/backends).

## Decision

Use:

- DDD for domain clarity (`Circuit`, `GateOperation`, `Observable`).
- Hexagonal architecture for execution boundaries (`Ports` + `Adapters`).
- TDD + BDD as default delivery workflow.

## Consequences

Positive:

- Easy simulator/backend substitution.
- Better test isolation and clearer invariants.
- Lower risk when optimizing kernels.

Negative:

- More initial boilerplate.
- Requires discipline to avoid leaking adapter details into domain.

## Follow-up

- Define and stabilize core port contracts before deep optimization work.
- Enforce architecture boundaries in code reviews.

