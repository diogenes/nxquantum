# Kernel Optimization Design Note (2026-03-23)

## Scope

Target hot paths:

1. `state_reuse_8q_xy`
2. `batch_obs_8q`
3. `sampled_counts_sparse_terms`

Constraints:

1. No public API breakage.
2. Deterministic typed behavior preserved.
3. DDD/Hexagonal boundaries preserved.

## Selected Strategy

### 1) State-vector Pauli expectation

1. Keep bitmask expectation core (`x_mask`, `z_mask`, coeff) as the canonical math model.
2. Use `ExpectationPlan` to precompute reusable per-term metadata.
3. Add `FusedSingleWire` kernel for single-state, many single-wire terms (`X/Y/Z`) to reduce per-term Nx call overhead.
4. Keep workload-aware execution strategy:
   - scalar + memoized intermediates for small/medium workloads,
   - parallel chunking for larger workloads.

### 2) Sampled counts sparse expectation

1. Parse counts once into compact integer representation (`ParsedCounts`).
2. Build reusable unique-mask lookup plan (`MaskLookupCache`).
3. Evaluate masks through `CountsReducer` with thresholded backend choice (Elixir vs Nx reducer).
4. Use deterministic merge order and stable typed errors.

### 3) Batch-observable execution

1. Reuse state once at batch-level (existing deterministic batch strategy).
2. Reuse term kernels and duplicate term values.
3. Reuse shared intermediates (`X/Y` overlap, `Z` probabilities).
4. Apply fused single-wire kernel when eligible to minimize orchestration overhead.

## Rejected / Deferred Alternatives

### Rejected now: fully vectorized tensor gather kernel over all terms

Reason:

1. Prototype introduced higher overhead and correctness risk on current runtime profile for 8q/48-term shape.
2. Required larger memory movement (`take` over stacked permutations) than expected for this workload.

### Deferred: FWHT/parity-transform path

Reason:

1. Promising for very large fixed-mask workloads, but complexity/crossover point needs dedicated benchmark matrix first.
2. Not necessary to meet current sampled-count parity target.

### Deferred: broad SU(2) resynthesis integration in this pass

Reason:

1. Independent compiler optimization lane already exists; not on critical path for these three benchmark bottlenecks.
2. Keep this pass focused on estimator hot paths and measurable parity gaps.

## Rollout and Safety

1. Keep fused path behind strict eligibility checks (`single-wire`, term-count threshold, bounded qubits).
2. Preserve fallback scalar/parallel paths for all other term shapes.
3. Add property coverage for parity/sign correctness, order invariance, and deterministic parallel output.
4. Add dedicated `batch_obs_8q` regression guard in CI reporting.
