# Skill: Quantum Kernel

## Goal

Implement or optimize quantum simulation kernels while preserving correctness.

## Inputs

- target gate(s) and expected math behavior,
- affected API contracts,
- benchmark baseline (if available).

## Workflow

1. Confirm behavior from `features/` and acceptance tests.
2. Add or update unit tests for gate-level math.
3. Add property tests for invariants (normalization, shape, determinism).
4. Implement kernel changes in simulator adapter/kernels.
5. Benchmark before/after and document tradeoffs.

## Done Criteria

- Tests pass.
- Benchmarks added or updated.
- Docs mention numerical assumptions and tolerance choices.

