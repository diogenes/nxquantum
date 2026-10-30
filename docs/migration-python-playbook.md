# Migration Playbook: Python-First Quantum Workflows to NxQuantum

This playbook helps teams move incrementally without rewriting everything at once.

## Step 1: Map Workflow Intents (not APIs)

Typical intents:

1. Estimate observables from parameterized circuits.
2. Sample bitstrings with seeded reproducibility.
3. Generate kernel matrices for classical models.
4. Route circuits against topology constraints.

Start by mapping these intents to NxQuantum modules:

- `Estimator`
- `Sampler`
- `Kernels`
- `Transpiler`

## Step 2: Reproduce Deterministic Baselines

Before migration, pin reference inputs and outputs:

1. Fixed parameter vectors.
2. Fixed shot counts and seeds.
3. Fixed backend/runtime profile.

Then validate equivalence using the same benchmark inputs in NxQuantum.

## Step 3: Replace One Path at a Time

Suggested order:

1. Kernel generation (`Kernels.matrix/2`) for low-friction parity checks.
2. Estimation path (`Estimator.expectation_result/2`).
3. Sampling and mitigation (`Sampler.run/2`, `Mitigation.pipeline/2`).
4. Topology routing (`Transpiler.run/2`).

## Step 4: Keep Risk Visible

Track explicit gaps while migrating:

1. Provider-specific hardware APIs may still require Python-side glue.
2. Some dynamic-circuit/provider workflows may need phased rollout.
3. Use typed error codes as integration checkpoints in CI.

## Step 5: Production Rollout Pattern

1. Shadow mode: run NxQuantum path alongside current production path.
2. Compare deterministic metrics and distributions.
3. Promote NxQuantum path once tolerances and latency budgets are met.

## References

- [docs/getting-started.md](getting-started.md)
- [docs/python-comparison-workflows.md](python-comparison-workflows.md)
- [docs/product-positioning.md](product-positioning.md) (Choosing NxQuantum vs Python-First)
- [docs/migration-packs.md](migration-packs.md)
- [docs/provider-support-catalog.md](provider-support-catalog.md)
- [docs/provider-benchmark-matrix.md](provider-benchmark-matrix.md)
