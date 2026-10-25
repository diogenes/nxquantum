# API Stability (v0.2)

This document declares stable vs experimental API surfaces for v0.2.

## Stable Surface (v0.2)

These modules/functions are expected to remain contract-stable through v0.2:

1. `NxQuantum.Circuit.new/1`
2. `NxQuantum.Circuit.bind/2`
3. `NxQuantum.Circuit.expectation/2` (returns `{:f, 32}`; accuracy floor in `docs/backend-support.md`, "Numerical Precision")
4. `NxQuantum.Gates` pipe-friendly gate constructors (`h`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `cnot`)
5. `NxQuantum.Runtime.supported_profiles/0`
6. `NxQuantum.Runtime.profile!/1`
7. `NxQuantum.Runtime.resolve/2`
8. `NxQuantum.Estimator.expectation/2`
9. `NxQuantum.Estimator.expectation_result/2`
10. `NxQuantum.Estimator.run/2`

## Experimental Surface (v0.2)

These are available but may evolve during v0.2:

1. `NxQuantum.Grad.value_and_grad/3`
2. `NxQuantum.Compiler.optimize/2`
3. `NxQuantum.Kernels.matrix/2`

## Contract Policy

1. Stable API contract changes require:
   - docs update,
   - explicit acceptance mapping,
   - compatibility/migration note in release notes.
2. Experimental APIs may evolve, but must keep deterministic typed error behavior.
3. Public API contract tests live in:
   - `test/nx_quantum/public_api_contract_test.exs`

## Envelope Compatibility Policy (external provider envelopes)

Applies to job, result, and error envelopes produced by `NxQuantum.ProviderBridge.Serialization.to_external_map/1`.

1. Golden snapshots of every core provider's envelopes live in `test/fixtures/contracts/envelopes/`. Any byte change fails `test/nx_quantum/contracts/envelope_snapshot_test.exs`.
2. A shape or meaning change requires a `schema_version` bump and a CHANGELOG entry. Regenerating snapshots without a version bump is a contract violation.
3. Additive fields inside `v1` are allowed only when the snapshot is regenerated in the same change and the CHANGELOG lists the new field. Consumers must ignore unknown fields.
4. Consumers resume persisted envelopes through `Serialization.from_external_map/1`. It accepts `v1` only and returns typed errors for unknown versions, types, states, codes, and operations. It never creates atoms from input.
5. Round trip contract: `to_external_map(from_external_map(map)) == map` for every snapshot. Test: `test/nx_quantum/contracts/envelope_decode_test.exs`.
6. The provider field is kept as its external string id. The adapter module is not part of the envelope; callers pass the adapter when resuming a job.
7. To regenerate snapshots deliberately: `NXQ_UPDATE_SNAPSHOTS=1 mix test test/nx_quantum/contracts/envelope_snapshot_test.exs`.

Known consumer: FluxQ (separate project) reads these envelopes unchanged and gates releases on the snapshot files (its G2 gate).
