# ADR 0004: AWS Braket Provider Adapter Strategy

- Status: Accepted (Delivered in v0.5 P0)
- Date: 2026-03-20

## Context

`AWS Braket` is selected as a v0.5 P0 provider because it provides broad hardware access through a single API family and explicit task lifecycle semantics.

NxQuantum needs an adapter that:

1. supports Braket task lifecycle behavior,
2. normalizes diverse device/provider behavior behind typed contracts,
3. preserves deterministic runtime and migration-friendly DX.

## Decision

Implement `NxQuantum.Adapters.Providers.AwsBraket` behind `NxQuantum.Ports.Provider`.

1. Scope for v0.5:
   - gate-model workflows as primary path,
   - task lifecycle (`submit`, `poll`, `cancel`, `fetch_result`),
   - typed normalization per ADR 0002.
2. Configuration envelope:
   - AWS region,
   - credential/profile source,
   - explicit device selector (`device_arn` or equivalent target alias).
3. Capability contract:
   - per target/device class capability metadata,
   - deterministic preflight rejection for unsupported target classes.
4. Result strategy:
   - normalize terminal results to NxQuantum contract,
   - preserve raw provider fields in metadata.

## Proposed Domain Mapping

Bounded context: Dynamic Execution and Provider Bridge.

1. Domain:
   - normalized provider job/result/error value objects from ADR 0002.
2. Application:
   - workflow intent submission with capability preflight.
   - explicit provider/target routing with no fallback.
3. Adapter:
   - Braket request/response mapping modules.
   - task status mapping table -> normalized states.
   - provider error mapping for transport/auth/quota/invalid target/terminal failures.

## Status/Error Mapping Policy

1. Map Braket task lifecycle statuses to normalized states.
2. Preserve raw task status and reason codes in metadata.
3. Unknown or inconsistent payloads map to `:provider_invalid_response`.
4. Target/device mismatches map to `:provider_capability_mismatch`.

## Consequences

Positive:

1. High Pareto impact via single adapter covering multiple hardware paths.
2. Strong migration story for Braket-native and brokered workflows.
3. Reusable state/error normalization patterns for additional adapters.

Negative:

1. Device/provider heterogeneity increases fixture and mapping coverage needs.
2. Non-gate-model workflows remain out-of-scope for initial v0.5 delivery.

## Alternatives Considered

1. Build direct vendor adapters first (IonQ, Rigetti, etc.).
   - Rejected: duplicates integration effort that Braket broker already covers.
2. Support analog and gate-model paths together in v0.5 P0.
   - Rejected: scope risk; gate-model-first preserves delivery focus.

## Follow-up

1. Create `features/provider_aws_braket_bridge.feature` with lifecycle/cancellation/failure scenarios.
2. Add fixture-backed tests covering representative Braket terminal and failed states.
3. Publish migration notes for Braket workflow mapping and known target-class boundaries.
