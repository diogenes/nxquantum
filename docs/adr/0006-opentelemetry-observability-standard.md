# ADR 0006: OpenTelemetry-First Observability Standard for NxQuantum

- Status: Accepted (Delivered in v0.5 P1/P2)
- Date: 2026-03-20

## Context

NxQuantum is introducing top-3 provider support (`IBM Runtime`, `AWS Braket`, `Azure Quantum`) and needs first-class observability for:

1. provider lifecycle variability (queueing, execution, cancellation, failures),
2. cross-provider comparability for latency/error behavior,
3. production operations in BEAM systems where typed contracts and determinism are core values.

Current telemetry is not standardized as a cross-provider QML observability model.

## Decision

Adopt OpenTelemetry as the default observability framework for traces, logs, and metrics, with a QML-specific standard profile.

1. Instrumentation model:
   - traces via OpenTelemetry spans/events,
   - metrics via counters/histograms/gauges,
   - structured logs correlated to trace/span ids.
2. Visibility profiles (user configurable):
   - `:high_level` (low cardinality, production-safe defaults),
   - `:granular` (provider lifecycle breakdown + selected workflow metadata),
   - `:forensics` (debug/deep diagnostics, heavier cardinality and event detail).
3. Provider lifecycle spans are mandatory in all profiles:
   - `nxq.provider.submit`
   - `nxq.provider.poll`
   - `nxq.provider.cancel`
   - `nxq.provider.fetch_result`
4. Core workflow spans:
   - `nxq.workflow.run`
   - `nxq.transpile.run`
   - `nxq.mitigation.pipeline`
5. Mandatory metrics (all providers):
   - `nxq.provider.request.latency_ms` (histogram)
   - `nxq.provider.queue_wait_ms` (histogram)
   - `nxq.provider.execution_ms` (histogram)
   - `nxq.provider.error.count` (counter)
   - `nxq.workflow.success.count` (counter)
   - `nxq.workflow.failure.count` (counter)
6. Mandatory labels/attributes (bounded cardinality):
   - `nxq.provider`
   - `nxq.target`
   - `nxq.workflow`
   - `nxq.runtime_profile`
   - `nxq.error_code` (when present)
   - `nxq.visibility_profile`
7. Security and safety:
   - deterministic redaction for credentials/secrets,
   - payload hashing/fingerprinting instead of raw payload logging by default,
   - explicit opt-in for any sensitive debug fields in `:forensics`.

## Game-Changer Proposal (QML Community)

Introduce a deterministic cross-provider observability primitive:

1. `Quantum Experiment Fingerprint` (`nxq.experiment.fingerprint`):
   - hash of canonicalized circuit/observable/params/seed/shots/topology profile.
2. `Portability Delta Metrics` keyed by fingerprint:
   - `nxq.portability.latency_delta_ms`
   - `nxq.portability.expectation_delta_abs`
   - `nxq.portability.sample_kl_divergence`
3. Purpose:
   - make cross-provider behavior auditable and reproducible,
   - standardize apples-to-apples QML benchmarking in production-like environments.

This creates an observability layer that is not just operational telemetry, but a reproducibility and scientific-comparison tool.

## Proposed Domain Mapping

Bounded context: Dynamic Execution and Provider Bridge (with cross-cutting observability concern).

1. Domain:
   - `TelemetryProfile` value object (`:high_level | :granular | :forensics`).
   - `ExperimentFingerprint` value object.
   - `PortabilityDelta` metric envelope.
2. Application:
   - lifecycle instrumentation hooks around provider and workflow operations.
   - fingerprint generation and portability-delta emission for comparable workloads.
3. Ports:
   - telemetry emitter behavior (`span_start`, `span_stop`, `metric_emit`, `log_emit`).
4. Adapters:
   - OpenTelemetry adapter implementation.
   - no-op adapter for disabled observability mode.

Dependency direction remains: `Domain <- Application <- Adapters`.

## Standards (Semantic Conventions)

Use `nxq.*` namespace for custom QML conventions.

Trace/span attributes:

1. `nxq.provider`
2. `nxq.target`
3. `nxq.workflow`
4. `nxq.job_id`
5. `nxq.runtime_profile`
6. `nxq.error_code`
7. `nxq.experiment.fingerprint`

Log schema (structured):

1. `event`
2. `level`
3. `trace_id`
4. `span_id`
5. `provider`
6. `target`
7. `workflow`
8. `error_code` (optional)
9. `message`

Metric dimensionality rules:

1. No high-cardinality labels (for example raw `job_id`) in metric labels.
2. Provider/target/workflow/runtime_profile are allowed.
3. Fingerprint may be emitted as event/log attribute, not as high-cardinality metric label by default.

## Consequences

Positive:

1. Unified observability across top-3 providers.
2. Better production debugging and SLO management for QML workflows.
3. Reproducibility-aware benchmarking via fingerprint + portability deltas.
4. Strong DX story: users can choose low-cost or deep visibility profiles.

Negative:

1. Additional implementation complexity and telemetry overhead.
2. Cardinality and storage cost risks if profile defaults are not disciplined.
3. Requires careful documentation and defaults to avoid noisy telemetry.

## Alternatives Considered

1. Keep provider-specific logging only.
   - Rejected: no standardized cross-provider visibility or correlation.
2. Build custom telemetry framework instead of OpenTelemetry.
   - Rejected: weaker ecosystem interoperability and tooling support.
3. Single telemetry profile only.
   - Rejected: cannot balance production cost vs deep diagnostics needs.

## Follow-up

1. Add observability feature scenarios:
   - high-level profile emits mandatory core metrics/spans only,
   - granular profile emits lifecycle breakdown,
   - forensics profile emits deep diagnostic events with explicit opt-in.
2. Add provider instrumentation contract tests for all top-3 adapters.
3. Publish observability guide with semantic conventions and dashboard examples:
   - `docs/observability.md`
4. Add CI checks for telemetry schema stability and redaction behavior.
