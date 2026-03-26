# Observability Guide (OpenTelemetry + QML Standards)

Status note (as of March 20, 2026):

1. This guide defines the implementation standard for v0.5 provider observability.
2. Architecture decision source of truth:
   - `docs/adr/0006-opentelemetry-observability-standard.md`
3. Starter dashboards and rollout conventions:
   - `docs/observability-dashboards.md`

## Why This Guide Exists

NxQuantum is adding the core provider set (`IBM Runtime`, `AWS Braket`, `Azure Quantum`).
To keep operations and research reproducibility strong, we need:

1. consistent traces, logs, and metrics across providers,
2. deterministic contracts and schema stability,
3. configurable visibility so teams can choose low-cost vs deep-debug telemetry.

## Design Principles

1. Determinism first: same workflow inputs should produce stable telemetry shape.
2. Contract-first telemetry: schema changes are versioned and tested.
3. Low-cardinality defaults: production-safe by default.
4. Explicit depth controls: `high_level`, `granular`, `forensics`.
5. Security by default: deterministic redaction and secret-safe logging.
6. Cross-provider comparability: telemetry should support portability analysis.

## Terminology

1. Workflow: one logical QML request (`estimator`, `sampler`, transpilation + execution path).
2. Provider lifecycle: `submit`, `poll`, `cancel`, `fetch_result`.
3. Visibility profile:
   - `:high_level`
   - `:granular`
   - `:forensics`
4. Experiment fingerprint: deterministic hash of canonicalized workflow inputs.
5. Portability delta: metric describing cross-provider behavioral differences for the same fingerprint.

## Telemetry Architecture

### Domain Layer

1. `TelemetryProfile` value object:
   - allowed values: `:high_level | :granular | :forensics`
2. `ExperimentFingerprint` value object:
   - deterministic hash representation + version tag
3. `PortabilityDelta` value object:
   - normalized latency/result-distribution deltas

### Application Layer

1. Orchestration services emit lifecycle and workflow telemetry hooks.
2. Capability and provider boundaries are captured in span attributes and logs.
3. Fingerprint and portability deltas are emitted after terminal result resolution.

### Adapter Layer

1. NxQuantum.Adapters.Observability.OpenTelemetry:
   - production emitter adapter
2. NxQuantum.Adapters.Observability.Noop:
   - deterministic no-op path for disabled observability

## Standard Span Taxonomy

Mandatory spans (all providers):

1. `nxq.workflow.run`
2. `nxq.provider.submit`
3. `nxq.provider.poll`
4. `nxq.provider.cancel` (when requested)
5. `nxq.provider.fetch_result`

Recommended spans:

1. `nxq.transpile.run`
2. `nxq.mitigation.pipeline`
3. `nxq.dynamic.execute`

Span event naming:

1. `nxq.lifecycle.transition`
2. `nxq.retry.scheduled`
3. `nxq.capability.preflight_failed`
4. `nxq.redaction.applied`
5. `nxq.portability.delta_computed`

## Required Span Attributes

Every provider lifecycle span must include:

1. `nxq.provider`
2. `nxq.target`
3. `nxq.workflow`
4. `nxq.runtime_profile`
5. `nxq.visibility_profile`

When available:

1. `nxq.job_id`
2. `nxq.error_code`
3. `nxq.experiment.fingerprint`
4. `nxq.target_class`
5. `nxq.capability_contract_version`

## Metric Standards

Core metric set (required):

| Metric | Type | Unit | Required dimensions |
| --- | --- | --- | --- |
| `nxq.provider.request.latency_ms` | histogram | ms | provider,target,workflow,runtime_profile |
| `nxq.provider.queue_wait_ms` | histogram | ms | provider,target,workflow |
| `nxq.provider.execution_ms` | histogram | ms | provider,target,workflow |
| `nxq.provider.error.count` | counter | count | provider,target,workflow,error_code |
| `nxq.workflow.success.count` | counter | count | provider,target,workflow |
| `nxq.workflow.failure.count` | counter | count | provider,target,workflow,error_code |

Advanced metric set (recommended):

| Metric | Type | Unit | Notes |
| --- | --- | --- | --- |
| `nxq.portability.latency_delta_ms` | histogram | ms | computed for comparable fingerprints |
| `nxq.portability.expectation_delta_abs` | histogram | unitless | absolute expectation-value difference |
| `nxq.portability.sample_kl_divergence` | histogram | unitless | sample-distribution divergence |
| `nxq.workflow.retry.count` | counter | count | per run, if retries enabled |

Cardinality rules:

1. Never use raw `job_id` as a metric label.
2. Use fingerprint in logs/spans/events, not high-cardinality metric labels by default.
3. Keep target labels stable and normalized (no full raw payload strings).

## Log Standards (Structured)

Required fields:

1. `event`
2. `level`
3. `message`
4. `provider`
5. `target`
6. `workflow`
7. `trace_id`
8. `span_id`

Optional fields:

1. `error_code`
2. `job_state`
3. `experiment_fingerprint`
4. `visibility_profile`

Log safety:

1. Never emit credentials, tokens, or raw secret-bearing headers.
2. Use deterministic redaction markers for blocked fields.
3. Prefer hashed payload references over raw payload bodies.

## Visibility Profiles

### `:high_level` (default)

Intended for production baselines.

1. Emit core lifecycle spans and core metric set.
2. Emit only low-cardinality labels.
3. Emit only major lifecycle events and terminal diagnostics.

### `:granular`

Intended for provider debugging and performance tuning.

1. Include queue/execution phase breakdown.
2. Include retry and polling-cycle summaries.
3. Include selected workflow metadata (for example shot count buckets).

### `:forensics`

Intended for short-lived deep investigations.

1. Include detailed lifecycle events and richer diagnostic logs.
2. Include advanced metadata behind explicit opt-in guards.
3. Should be time-bounded and not the default production mode.

## Configuration Contract

Recommended configuration shape:

```elixir
config :nx_quantum, :observability,
  enabled: true,
  adapter: NxQuantum.Adapters.Observability.OpenTelemetry,
  profile: :high_level,
  traces_enabled: true,
  metrics_enabled: true,
  logs_enabled: true,
  portability_enabled: true,
  sample_rate: 1.0,
  redact_secrets: true
```

Runtime override strategy:

1. Global config for default profile.
2. Per-request override (with bounded allowed transitions).
3. Safe fallback to `:high_level` when invalid profile is requested.

## Game-Changer Model: Fingerprint + Portability Delta

### Experiment Fingerprint

Canonical fields (ordered):

1. canonical circuit representation
2. observable definition
3. parameter vector
4. seed
5. shots
6. topology/transpilation profile
7. runtime profile
8. fingerprint schema version

Compute:

1. canonicalize fields deterministically,
2. hash using stable algorithm (for example SHA-256),
3. emit as `nxq.experiment.fingerprint`.

### Portability Delta

For same fingerprint across providers, compute:

1. latency delta (`ms`)
2. expectation absolute delta
3. sample-distribution divergence (KL or bounded equivalent)

Derived composite score (recommended):

1. `nxq.portability.score` (0-100):
   - weighted combination of latency and numerical consistency deltas
   - used for migration confidence dashboards

## SLO and Alerting Guidance

Baseline SLO candidates:

1. p95 `nxq.provider.request.latency_ms` per provider/target/workflow
2. `nxq.provider.error.count / (success + failure)` error-rate budget
3. cancellation success ratio for cancellation-enabled providers

Alert suggestions:

1. sudden error-rate increase by provider + error code
2. sustained queue-wait expansion
3. portability score degradation for critical workflows

## Dashboard Starter Views

### Operations Dashboard

1. lifecycle latency (submit/poll/fetch_result)
2. queue vs execution breakdown
3. error-rate by provider/error_code
4. retry and cancellation trend

### QML Portability Dashboard

1. fingerprint volume over time
2. portability deltas by provider pair
3. portability score trend by workflow type
4. top unstable fingerprints

## Testing and CI Standards

Schema tests (required):

1. span names and required attributes
2. metric names/types/units
3. log schema field presence and redaction behavior

Behavior tests (required):

1. profile-specific emission differences (`high_level` vs `granular` vs `forensics`)
2. deterministic fingerprint output for identical inputs
3. portability-delta calculation contract stability

CI gates (recommended):

1. fail on telemetry schema drift unless version bump is explicit
2. fail on redaction regressions
3. enforce cardinality guardrails via fixture-based checks

## Implementation Checklist (for agents)

1. Implement observability facade and profile validation.
2. Add OpenTelemetry and no-op adapters.
3. Instrument provider lifecycle and workflow spans.
4. Emit required core metrics and structured logs.
5. Implement deterministic fingerprint module.
6. Implement portability delta and optional composite portability score.
7. Add feature scenarios and contract tests.
8. Publish dashboard JSON/examples and alert templates.

## Related Docs

1. `docs/adr/0006-opentelemetry-observability-standard.md`
2. `docs/v0.5-feature-spec.md`
3. `docs/v0.5-provider-implementation-plan.md`
4. `docs/roadmap.md`
