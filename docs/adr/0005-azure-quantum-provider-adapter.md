# ADR 0005: Azure Quantum Provider Adapter Strategy

- Status: Accepted (Delivered in v0.5 P1)
- Date: 2026-03-20

## Context

`Azure Quantum` is selected as the third v0.5 provider to expand enterprise and multi-provider coverage after IBM Runtime and AWS Braket.

NxQuantum needs an adapter that:

1. handles workspace/target/provider selection semantics,
2. maps lifecycle and cancellation behavior into deterministic typed contracts,
3. preserves provider-specific caveats explicitly in metadata.

## Decision

Implement `NxQuantum.Adapters.Providers.AzureQuantum` behind `NxQuantum.Ports.Provider`.

1. Scope for v0.5:
   - gate-model workflow submission/retrieval paths,
   - lifecycle (`submit`, `poll`, `cancel`, `fetch_result`),
   - typed normalization per ADR 0002.
2. Configuration envelope:
   - workspace/project identifiers,
   - auth context,
   - target/provider selector.
3. Capability contract:
   - explicit target/provider capability descriptors,
   - deterministic preflight checks for unsupported combinations.
4. Cancellation caveat policy:
   - surface provider/target-specific cancellation constraints in typed metadata,
   - do not mask caveats as generic success/failure strings.

## Proposed Domain Mapping

Bounded context: Dynamic Execution and Provider Bridge.

1. Domain:
   - normalized provider job/result/error value objects from ADR 0002.
2. Application:
   - provider/target selection, capability preflight, lifecycle orchestration.
3. Adapter:
   - Azure submission payload builder and result decoder.
   - status mapping table -> normalized states.
   - cancellation and terminal-state caveat mapping metadata.

## Status/Error Mapping Policy

1. Map Azure job lifecycle statuses deterministically to normalized states.
2. Preserve raw status and provider caveats in metadata.
3. Unknown or malformed status responses map to `:provider_invalid_response`.
4. Target/provider mismatch maps to `:provider_capability_mismatch`.

## Consequences

Positive:

1. Expands top-3 provider coverage with enterprise-friendly platform integration.
2. Strengthens cross-provider normalization confidence through third-adapter validation.
3. Makes portability boundaries explicit via typed caveat metadata.

Negative:

1. Additional complexity in workspace and target/provider configuration validation.
2. Cancellation semantics may vary by provider/target and require broader test fixtures.

## Alternatives Considered

1. Defer Azure to post-v0.5.
   - Rejected: weakens top-3 provider strategy and cross-provider normalization confidence.
2. Treat Azure as purely pass-through raw payload adapter.
   - Rejected: violates deterministic typed contract goals.

## Follow-up

1. Create `features/provider_azure_quantum_bridge.feature` with lifecycle and cancellation-caveat scenarios.
2. Add fixture-backed tests for representative Azure terminal states and target/provider mismatch failures.
3. Publish migration notes for Azure workflow mapping and provider caveat interpretation.
