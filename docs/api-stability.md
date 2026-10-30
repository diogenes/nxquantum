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
4. `NxQuantum.Sampler.run/2`
5. `NxQuantum.ProviderBridge.run_lifecycle/3`
6. `NxQuantum.Observability.fingerprint/2`
7. `NxQuantum.Transpiler.run/2`
8. `NxQuantum.Mitigation.pipeline/2`
9. `NxQuantum.ProviderBridge.submit_job/3`
10. `NxQuantum.Observability.portability_delta/2`
11. The `observability: [enabled: boolean, adapter: module]` option of `NxQuantum.ProviderBridge.run_lifecycle/3`
12. The provider adapter modules passed as the first argument to `NxQuantum.ProviderBridge` functions: `NxQuantum.Adapters.Providers.IBMRuntime`, `AwsBraket`, `AzureQuantum` and `GoogleQuantumAI`
13. The `NxQuantum.ProviderBridge.ProviderError` fields `code`, `reason` and `metadata.missing_keys`, and the `NxQuantum.ProviderBridge.Result` fields (`job_id`, `state`, `provider`, `payload`, `metadata` and the identifier fields), except the contents of `metadata`
14. The `NxQuantum.Ports.ObservabilityEmitter` behaviour, when you implement it in your own code. Its callbacks may change.

Items 4 to 14 are listed here so that the tier is explicit. This is a documentation statement, not a promotion: nothing moved to the stable surface, and these items stay experimental until the owner decides otherwise under an `api change` intent.

Not listed on purpose: `metadata.transport` of a provider result. It is built by an internal module and typed only as `map()`, so no notebook or caller should rely on its keys.

Experimental does not mean untested. The notebooks under `examples/livebook/` use several of these items, and `test/nx_quantum/livebooks_test.exs` runs them (`docs/livebook-tutorials.md`). A notebook that passes shows the current behavior, not a stability promise.

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

## Dependency Policy

1. NxQuantum tracks the latest stable Nx ecosystem and Elixir/OTP releases. This is checked at each minor release cut (`docs/release-process.md`).
2. Raising the major floor of a runtime dependency is an `api change`, with a CHANGELOG migration note (example: `nx ~> 1.0` in `[Unreleased]`).
3. Removing an unused optional dependency relaxes constraints and is not breaking (example: `axon`, dropped in H1.6 PR-A).
4. Optional backend requirements (`exla`, `torchx`) are env-gated in `mix.exs` when `mix hex.build` runs. A package built with `NXQ_ENABLE_EXLA=0` carries no `exla` requirement, and one built with `NXQ_ENABLE_TORCHX` unset or `0` carries no `torchx` requirement (`torchx` defaults off, `exla` defaults on). `.github/workflows/release.yml` sets both to `"0"` for its dry run, so that dry-run package carries neither. The effective version floor reaches consumers through `nx`. Do not assume an optional requirement is published.
