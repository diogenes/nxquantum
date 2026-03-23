# ADR 0003: IBM Runtime Provider Adapter Strategy

- Status: Accepted (Delivered in v0.5 P0)
- Date: 2026-03-20

## Context

`IBM Runtime` is a high-impact migration target for primitive-centric workflows and is one of the selected top-3 provider priorities for v0.5.

NxQuantum needs an adapter that:

1. maps `Estimator`/`Sampler` intents to IBM Runtime execution payloads,
2. preserves deterministic typed contracts,
3. keeps provider-specific details inside adapter boundaries.

## Decision

Implement `NxQuantum.Adapters.Providers.IBMRuntime` behind `NxQuantum.Ports.Provider`.

1. Scope for v0.5:
   - estimator and sampler workflow intents,
   - lifecycle operations (`submit`, `poll`, `cancel`, `fetch_result`),
   - typed state/error normalization per ADR 0002.
2. Configuration envelope:
   - provider auth token,
   - account/channel context,
   - backend/target selector.
3. Capability declaration:
   - explicit per target/backend capability envelope,
   - deterministic unsupported-capability preflight.
4. Result strategy:
   - normalize result payload into NxQuantum envelope,
   - keep raw provider content in metadata for audits/debugging.

## Proposed Domain Mapping

Bounded context: Dynamic Execution and Provider Bridge.

1. Domain:
   - normalized provider job/result/error value objects from ADR 0002.
2. Application:
   - translate workflow intent (`:estimator`, `:sampler`) into provider submission envelope.
   - enforce capability contract before remote call.
3. Adapter:
   - IBM payload builder + result decoder modules.
   - IBM status mapping table -> normalized states.
   - IBM error mapping table -> normalized error codes.

## Status/Error Mapping Policy

1. Map IBM lifecycle statuses deterministically into normalized states.
2. Keep source status in `metadata.raw_state`.
3. Unknown status or malformed response returns `:provider_invalid_response`.
4. Auth/channel/backend issues map to typed auth/capability/execution errors.

## Consequences

Positive:

1. Strongest migration path for Qiskit Runtime style primitive workflows.
2. High fit with existing `Estimator`/`Sampler` NxQuantum facade model.
3. Clear provider-specific boundary with reusable cross-provider contract.

Negative:

1. Adapter complexity around provider-specific options and payload shapes.
2. Ongoing maintenance required for provider API/runtime evolution.

## Alternatives Considered

1. Delay IBM to post-v0.5.
   - Rejected: weakens immediate migration value and Pareto impact.
2. Add IBM-specific API surface directly in public modules.
   - Rejected: violates stable provider-agnostic facade strategy.

## Follow-up

1. Create `features/provider_ibm_runtime_bridge.feature` with lifecycle and failure scenarios.
2. Add fixture-backed contract tests for representative IBM response states and errors.
3. Add docs migration pack: Qiskit Runtime -> NxQuantum provider bridge.
