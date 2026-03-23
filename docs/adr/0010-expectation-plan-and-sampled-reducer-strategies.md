# ADR 0010: Expectation Plan and Sampled Reducer Strategies

Date: 2026-03-23
Status: Accepted

## Context

Benchmarking on 2026-03-23 showed remaining gaps in three hot paths:

1. Repeated Pauli expectation on unchanged state (`state_reuse_8q_xy`).
2. Sparse-term sampled expectation from fixed counts (`sampled_counts_sparse_terms`).
3. Multi-observable batch execution (`batch_obs_8q`).

The previous implementation mixed orchestration and math concerns in single modules and rebuilt execution metadata for repeated calls.

## Decision

Introduce cohesive strategy and planning components with explicit responsibilities:

1. `NxQuantum.Adapters.Simulators.StateVector.PauliExpval.ExpectationPlan`
2. `NxQuantum.Adapters.Simulators.StateVector.PauliExpval.ExecutionStrategy`
3. `NxQuantum.Estimator.SampledExpval.ParsedCounts`
4. `NxQuantum.Estimator.SampledExpval.MaskLookupCache`
5. `NxQuantum.Estimator.SampledExpval.CountsReducer`
6. `NxQuantum.Estimator.SampledExpval.ExecutionStrategy`

Also adopt adaptive threshold + chunk sizing for parallel execution, and memoized reuse for duplicate batch terms and shared intermediate kernels (`X/Y` overlap and `Z` probabilities).

## Consequences

Positive:

1. Better separation of orchestration from kernel math.
2. Deterministic plan/caching boundaries that can be tested in isolation.
3. Strong performance gains on state-reuse and sampled sparse reductions.

Tradeoff:

1. `batch_obs_8q` gap narrowed and target improvement was reached, but a residual parity gap vs Qiskit remains for this workload shape.

## Contract Impact

1. Public API remains unchanged.
2. Typed error behavior remains unchanged.
3. New modules are internal implementation detail behind existing facades.
