# ADR 0013: Adapter option keys in the application option allow-list (KG-25 exception)

- Status: Accepted (owner: user, 2026-11-26)
- Date: 2026-11-26
- Owner: user
- Owner context: Primitive Estimation and Primitive Sampling (option validation at the public entrypoints)
- Related: `docs/api-stability.md` (Option Validation), `lib/nx_quantum/option_keys.ex`, KG-22 and KG-25 in `docs/roadmap.md`

## Context

KG-25 phase 1 validates top-level option keys at `NxQuantum.Estimator.run/2`, `expectation_result/2`, and `NxQuantum.Sampler.run/2`. The allow-list lives in `NxQuantum.OptionKeys`, an application-level module. The Estimator list also names five keys that belong to the simulator and the KG-22 cache:

- `:simulator`, `:backend_opts`: read in `lib/nx_quantum/application/execute_circuit.ex` and `lib/nx_quantum/runtime/simulator_resolver.ex`. These choose the simulator adapter.
- `:cache_evolved_state`, `:evolved_state_cache_ttl_ms`, `:fused_compiled_kernel_policy`: read inside the StateVector adapter (`lib/nx_quantum/adapters/simulators/state_vector.ex`, `state_vector/evolved_state_cache.ex`, `state_vector/pauli_expval/fused_single_wire.ex`).

The architecture invariant says domain and application depend on ports, never on adapters. Listing these keys in the application module is a dependency in the wrong direction, in the sense that the application names adapter detail.

## Options considered

1. Move the five keys out of the application list, and let the adapter declare its own list that the application composes at the adapter boundary. Not practical in one small change. The application already reads `:simulator` and `:backend_opts` itself, so the keys cannot leave the application without a port that carries the adapter's key list. Moving them without that port would make valid calls such as `Estimator.run(c, simulator: X)` log a false warning and gain a false `metadata.unknown_options` entry.
2. Keep the keys in the application list and record the exception here. Chosen.

## Decision

1. The five keys stay in `NxQuantum.OptionKeys`. This is a recorded exception to the rule that application code does not name adapter detail.
2. The exception covers only the names of these keys in the allow-list. It does not permit the application to import adapter modules. `OptionKeys` still depends on no module outside itself.
3. The exception ends when a port carries adapter option keys (a `NxQuantum.Ports.Simulator` callback that returns the keys its adapter reads, composed by the Estimator and Sampler entrypoints). At that point the five names move out of `OptionKeys`, in the same change, with a CHANGELOG note.
4. Owner: user. Any new adapter-specific key needs the same decision, recorded in this ADR or a successor.

## Consequences

- The boundary breach on the allow-list is known and bounded, not silent.
- A misspelled simulator or cache key is not reported by name the way other unknown keys are, because the allow-list accepts the real names. Their nested values are not checked (see `docs/api-stability.md`).
- Phase 2 (typed error for unknown keys) can proceed without changing this exception.

## Open questions

1. Which port carries the adapter key list, and whether `NxQuantum.Ports.Simulator` or a new port owns it. Needs owner approval before implementation.
