# Testing Strategy

## Testing Pyramid

1. Unit tests (`test/nx_quantum/`)
- Domain invariants.
- API contracts.
- Error handling.

2. Property tests (`test/property/`)
- Norm preservation after unitary operations.
- Determinism under fixed seeds.
- Shape invariants for state vectors.

3. Feature tests (`test/features/`)
- Scenario-level checks mapped from `features/*.feature`.
4. Shared test support (`test/support/test_support/`)
- `NxQuantum.TestSupport.Helpers`, `Fixtures`, `Factories`, and `Doubles` reused across feature and unit/property tests.

## Feature Mapping Rule

Each scenario in `features/` should map to:

- one executable step definition in `test/features/steps/*.ex`,
- one or more unit/property tests for underlying behavior.

v0.2 additions should include feature coverage for:

- runtime profile and fallback policies,
- differentiation modes,
- seeded shots and noise behavior,
- circuit optimization semantic preservation,
- kernel matrix validity properties.
- adjoint-mode contracts (supported gates, typed unsupported-operation errors, required `circuit_builder`).

v0.3 additions should include feature coverage for:

- primitives API contracts (`Estimator` and `Sampler`),
- batched parameter execution equivalence vs scalar references,
- deterministic mitigation pipeline composition,
- topology-aware transpilation typed errors and semantic preservation,
- deterministic shortest-path routing selection for known coupling maps,
- deterministic equal-path tie-break behavior (`lexicographic_path`),
- deterministic transpilation report fields (`routed_edges`, `logical_to_physical_map`, `topology_id`),
- dynamic-circuit IR validation and explicit execution boundary errors.

v0.6 additions should include feature coverage for:

- completion of currently scaffold-only provider scenario families (`dynamic capabilities`, `mitigation calibration contracts`, `topology execution policies`, `simulation strategy fallback`, `batched primitives performance`),
- deterministic fixture behavior preservation while adapter transport seams are hardened,
- typed failure behavior for malformed/unsupported provider response paths after seam refactors.

v0.7 additions should include feature coverage for:

- versioned and machine-readable lifecycle/capability/error envelope stability,
- observability schema governance across `high_level`, `granular`, and `forensics` profiles,
- deterministic redaction and cardinality safeguards as contract-level checks,
- standalone production behavior equivalence when observability/export adapter strategies change.

## Contract Tests

Add explicit contract tests for public APIs to prevent behavior drift:

- Runtime profile resolution and fallback policy behavior.
- Typed error code invariants for unsupported/unavailable runtime profiles.
- Deterministic seed behavior for stochastic estimators.
- Public option schema compatibility (`runtime_profile`, `fallback_policy`, `shots`, `seed`).

## Architecture Guard Tests

- Dependency-direction guard tests verify boundary rules:
  - domain does not depend on adapters/application,
  - application does not depend on adapters,
  - ports do not depend on adapters/application,
  - adapters do not depend on application.

## Numerical Testing Guidelines

- Use tolerances for float comparisons (`assert_in_delta/4`).
- Keep reference expected values small and deterministic.
- Prefer comparing against known analytical solutions for 1-2 qubit circuits.

## Performance Testing

- Add `benchee` scripts for each kernel optimization.
- Track:
  - latency per gate application,
  - memory growth by qubit count,
  - backend compile vs execution time.
