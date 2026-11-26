# API Stability

This document declares stable vs experimental API surfaces.

## Stable Surface

These modules/functions are expected to remain contract-stable until an `api change` says otherwise:

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

## Experimental Surface

These are available but may evolve without an `api change`:

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
15. Envelope serialization and notebook-used result fields: `NxQuantum.ProviderBridge.Serialization.to_external_map/1` and `from_external_map/1`; the `counts` field of the `NxQuantum.Sampler.run/2` result; and, for `NxQuantum.Transpiler.run/2`, the `operations` field of the routed circuit and the `inserted_swaps` and `added_swap_gates` fields of the report

Items 4 to 15 are listed here so that the tier is explicit. This is a documentation statement, not a promotion: nothing moved to the stable surface, and these items stay experimental until the owner decides otherwise under an `api change` intent.

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

## Option Validation (KG-25, phase 1)

Applies to the top-level keyword options of `NxQuantum.Estimator.run/2`, `NxQuantum.Estimator.expectation_result/2`, and `NxQuantum.Sampler.run/2`. `NxQuantum.Estimator.expectation/2` and `NxQuantum.Circuit.expectation/2` go through the same check, because they call `expectation_result/2`.

1. Each call checks every top-level key against the allow-list in `lib/nx_quantum/option_keys.ex`. The Estimator list covers every key read on the estimator path, including the simulator's cache and concurrency keys (KG-22). The Sampler list covers the keys `Sampler.run/2` reads.
2. An unknown key does not change the computation. The call returns the result it returned before, logs one `Logger.warning` that names the keys, and, when the result has a `metadata` map (`Estimator.run/2` and `Sampler.run/2`), adds `metadata.unknown_options`, the unknown keys in order of appearance. The entry is absent when no key is unknown. `expectation_result/2` returns a tensor and has no metadata, so it only logs.
3. Phase 2, in a later minor release, returns a typed error for an unknown key, with a CHANGELOG migration note. Until then, a misspelled key is ignored, as it was before this rule.
4. A change that starts reading a new top-level option adds its key to the allow-list in the same change. Otherwise callers get a false warning.
5. Not checked in phase 1: the nested contents of `noise:` and `backend_opts:`, `Estimator.batched_expectation/3`, `Sampler.batched_run/3`, and `Estimator.sampled_expectation_from_counts/2`.

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
