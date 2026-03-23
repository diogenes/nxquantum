# ADR 0002: Provider Capability Contract v1 and Normalized Lifecycle/Error Model

- Status: Accepted (Delivered in v0.5)
- Date: 2026-03-20

## Context

NxQuantum currently has provider bridge foundations (`submit`, `poll`, `cancel`, `fetch_result`) and typed error mapping, but:

1. Provider depth remains the primary gap versus Python-first alternatives.
2. Top-3 provider integrations (`IBM Runtime`, `AWS Braket`, `Azure Quantum`) expose different lifecycle states, capabilities, and failure contracts.
3. Without a normalized contract, adapter-specific behavior will leak into application/domain layers and destabilize DX.

## Decision

Adopt a cross-provider contract layer (`v1`) with deterministic normalization rules.

1. Introduce a provider capability contract:
   - `supports_estimator`
   - `supports_sampler`
   - `supports_batch`
   - `supports_dynamic`
   - `supports_cancel_in_running`
   - `supports_calibration_payload`
   - `target_class`
2. Normalize job states to:
   - `:submitted | :queued | :running | :completed | :cancelled | :failed`
3. Normalize provider errors to a stable taxonomy:
   - `:provider_transport_error`
   - `:provider_auth_error`
   - `:provider_invalid_state`
   - `:provider_invalid_response`
   - `:provider_capability_mismatch`
   - `:provider_execution_error`
   - `:provider_rate_limited`
4. Preserve raw provider status/payload under metadata:
   - `metadata.raw_state`
   - `metadata.raw_error`
   - `metadata.raw_payload`
5. Enforce explicit provider selection:
   - no silent cross-provider fallback or reroute.
6. Enforce deterministic redaction of secrets in diagnostics and logs.

## Proposed Domain Mapping

Bounded context: Dynamic Execution and Provider Bridge.

1. Domain:
   - value objects for normalized capability, job, result, and provider error envelopes.
2. Application:
   - preflight capability checks before remote submission.
   - lifecycle orchestration (`submit` -> `poll` -> `cancel`/`fetch_result`) through `NxQuantum.ProviderBridge`.
3. Ports:
   - provider lifecycle callbacks remain stable.
   - capability introspection added at provider boundary (direct callback or adapter metadata contract).
4. Adapters:
   - provider-specific status/error mapping tables.
   - provider payload builders/decoders.

Dependency direction remains: `Domain <- Application <- Adapters`.

## Consequences

Positive:

1. Consistent typed contract across top-3 providers.
2. Clear portability boundaries and explicit unsupported-capability behavior.
3. Lower migration friction from Python provider workflows.
4. Better long-term adapter maintainability under API drift.

Negative:

1. Additional adapter boilerplate for mapping and metadata normalization.
2. Contract versioning responsibility when provider behavior changes.
3. More up-front design work before first provider goes live.

## Alternatives Considered

1. Provider-specific contracts only.
   - Rejected: leaks complexity to callers and harms DX.
2. Dynamic schema driven only by raw provider payloads.
   - Rejected: weak typed guarantees and poor reproducibility.
3. Silent fallback to another provider when unsupported.
   - Rejected: violates determinism and explicit contract stability.

## Follow-up

1. Implement provider capability and normalized envelope modules.
2. Add feature scenarios for capability preflight and cross-provider parity.
3. Update provider adapter ADRs with provider-specific mapping tables.
4. Add fixture-backed contract tests for all top-3 providers.
