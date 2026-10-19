# v1.0 Quantum AI Tool Contracts

Status note (as of March 23, 2026):

1. This document defines the implementation-ready contract profile for `NxQuantum.AI` tool calls.
2. It is scoped to short-to-medium term execution and aligns with `docs/roadmap.md` Phase 19.

## Objective

Ship a production-safe tool-call contract so BEAM services and agent runtimes can invoke quantum workflows through deterministic, typed, observable envelopes.

## Standards Check: What Exists Today

There is no single universally adopted open standard specifically for "quantum AI tool contracts".  
The practical path is to compose mature open standards plus de-facto quantum interfaces.

### Recommended Contract Stack (Adopt Now)

1. MCP + JSON-RPC 2.0 for tool-call protocol semantics and host/client/server interaction.
2. JSON Schema 2020-12 (and OpenAPI 3.1 where HTTP is used) for strict request/response schemas.
3. W3C Trace Context + OpenTelemetry semantic conventions for distributed tracing and telemetry consistency.
4. RFC 9457 Problem Details for HTTP error payloads.
5. CloudEvents 1.0 for asynchronous event publication (optional profile).

### Quantum Domain References (Align, Not Hard-Couple)

1. Qiskit `BaseEstimatorV2` / `BaseSamplerV2` primitives as de-facto execution intent patterns.
2. OpenQASM 3 and QIR as optional interoperability payload formats where circuit/IR exchange is needed.

## Contract Design Principles

1. Deterministic envelopes:
   - identical inputs + seed + profile => identical contract outputs.
2. Typed failures:
   - stable `code`, `category`, `retryable`, and machine-readable `details`.
3. Additive versioning:
   - `schema_version` is explicit; breaking changes require new version.
4. Transport neutrality:
   - one canonical envelope model mapped to MCP/JSON-RPC and HTTP.
5. Provider abstraction:
   - provider-specific details live in namespaced metadata and never break envelope shape.

## Hexagonal Transport Strategy

The canonical envelope model is domain/application-owned and transport-neutral.

1. Port:
   - `NxQuantum.Ports.AIToolTransport`
2. Initial sync adapter:
   - `NxQuantum.Adapters.AIToolTransport.McpJsonRpcSync`
3. Initial async adapter:
   - `NxQuantum.Adapters.AIToolTransport.CloudEventsAsync`

Port callback surface (v1):

1. `capabilities/1`
2. `invoke_sync/2`
3. `publish_async/2`
4. `fetch_async_result/2`
5. `cancel_async/2`

Rules:

1. Sync and async share the same canonical envelopes and typed errors.
2. Unsupported mode calls must fail with typed deterministic transport errors.
3. Transport adapters must not alter tool semantics or fallback policy behavior.

## Canonical Envelope Model (v1)

## Request Envelope

```elixir
%{
  schema_version: "v1",
  request_id: String.t(),
  correlation_id: String.t(),
  idempotency_key: String.t() | nil,
  tool_name: String.t(),
  tool_version: String.t(),
  input: map(),
  execution_policy: %{
    timeout_ms: pos_integer(),
    transport_mode: :fixture | :live_smoke | :live,
    fallback_policy: :strict | :allow_classical_fallback
  },
  trace_context: %{
    traceparent: String.t() | nil,
    tracestate: String.t() | nil,
    baggage: map()
  },
  metadata: map()
}
```

Transport mode semantics:

1. `:fixture` is the deterministic baseline lane.
2. `:live_smoke` is a readiness lane for env/config and contract-path validation, and should not be interpreted as full remote provider execution.
3. `:live` is the lane for remote provider lifecycle execution when provider-backed tool flows are enabled.

## Result Envelope

```elixir
%{
  schema_version: "v1",
  request_id: String.t(),
  correlation_id: String.t(),
  status: :ok | :degraded | :fallback | :error,
  tool_name: String.t(),
  output: map() | nil,
  execution: %{
    provider: atom() | String.t() | :none,
    target: String.t() | :none,
    mode: :quantum | :classical_fallback,
    latency_ms: non_neg_integer(),
    started_at: String.t() | nil,
    finished_at: String.t() | nil
  },
  diagnostics: [map()],
  metadata: map()
}
```

## Error Envelope

```elixir
%{
  schema_version: "v1",
  request_id: String.t() | nil,
  correlation_id: String.t() | nil,
  code:
    :ai_tool_invalid_request
    | :ai_tool_unsupported
    | :ai_tool_timeout
    | :ai_tool_execution_failed
    | :ai_tool_provider_error
    | :ai_tool_fallback_blocked
    | :ai_tool_internal_error,
  category: :validation | :capability | :timeout | :provider | :policy | :internal,
  retryable: boolean(),
  message: String.t(),
  details: map()
}
```

## Initial Tool Set (Phase 19 Scope)

1. `quantum_kernel_rerank.v1`
   - input: candidate ids, feature vectors/embeddings reference, scoring options.
   - optional quantization options:
     - `codec: :turboquant`
     - `mode: :mse | :prod_unbiased`
     - `bit_width`
     - `seed`
     - `parallel_mode`
     - `max_concurrency`
   - output: ranked list with scores and execution metadata.
2. `constrained_optimize.v1`
   - input: objective id/config, constraint set, budget params.
   - output: candidate solution and optimization trace summary.

## Transport Profiles

## MCP / JSON-RPC Profile

Method namespace:

1. `nxq.ai.tools.list`
2. `nxq.ai.tools.execute`
3. `nxq.ai.capabilities.get`

Rules:

1. JSON-RPC `id` maps to `request_id`.
2. JSON-RPC error object carries typed `code`/`category` under `error.data`.
3. No transport-specific fields are allowed to alter canonical envelope semantics.

## CloudEvents Async Profile

Event flow:

1. `nxq.ai.tool.requested.v1` (dispatch accepted)
2. `nxq.ai.tool.progress.v1` (optional intermediate status)
3. `nxq.ai.tool.completed.v1` or `nxq.ai.tool.failed.v1` (terminal)

Required CloudEvents attributes:

1. `id` = dispatch identifier
2. `source` = NxQuantum transport source URI
3. `type` = one of the event types above
4. `subject` = `tool_name`
5. `time` = RFC3339 timestamp
6. `datacontenttype` = `application/json`
7. `data` contains canonical envelope payload with `schema_version`, `request_id`, and `correlation_id`

Delivery semantics:

1. At-least-once delivery is the baseline expectation.
2. Consumers must deduplicate by `id` + `request_id`.
3. Terminal events must be idempotent and safe to replay.

## HTTP Profile (Optional in Phase 19)

1. `POST /v1/ai/tools/{tool_name}:execute`
2. Success:
   - `200` with canonical result envelope.
3. Failure:
   - `4xx/5xx` with `application/problem+json` per RFC 9457,
   - include typed NxQuantum error data in extension members.

## Observability Contract

Required:

1. Propagate W3C trace context (`traceparent`, `tracestate`) when present.
2. Emit OpenTelemetry spans/metrics/logs with stable `nxq.ai.*` attributes.
3. Correlate AI tool call -> provider lifecycle -> terminal result/failure.

Minimum span attributes:

1. `nxq.ai.tool_name`
2. `nxq.ai.tool_version`
3. `nxq.ai.request_id`
4. `nxq.ai.correlation_id`
5. `nxq.ai.execution_mode`
6. `nxq.ai.status`
7. `nxq.ai.provider` (if quantum path)
8. `nxq.ai.target` (if quantum path)

## Security and Governance

1. User/system-provided sensitive fields must be redacted before logs/events.
2. Provider credentials must never appear in tool contract envelopes.
3. Fallback policy must be explicit and auditable in result metadata.
4. Schema validation is mandatory before execution dispatch.

## Implementation Plan (Phase 19)

## Slice A - Core Contracts and Schemas

1. Add modules:
   - `lib/nx_quantum/ai.ex`
   - `lib/nx_quantum/ai/request.ex`
   - `lib/nx_quantum/ai/result.ex`
   - `lib/nx_quantum/ai/error.ex`
2. Add schema validation and versioning helpers.
3. Add deterministic serialization tests.

## Slice B - Tool Runner + First Tool Handlers

1. Add:
   - `lib/nx_quantum/ai/tool_runner.ex`
   - `lib/nx_quantum/ai/tools/kernel_rerank.ex`
   - `lib/nx_quantum/ai/tools/constrained_optimize.ex`
2. Implement strict/fallback policy handling.
3. Add acceptance and contract tests.

## Slice C - Transport and Observability Integration

1. Add transport port:
   - `lib/nx_quantum/ports/ai_tool_transport.ex`
2. Add sync adapter scaffold:
   - `lib/nx_quantum/adapters/ai_tool_transport/mcp_json_rpc_sync.ex`
3. Add async adapter scaffold:
   - `lib/nx_quantum/adapters/ai_tool_transport/cloud_events_async.ex`
4. Add MCP mapping utilities (JSON-RPC binding layer).
5. Add optional HTTP adapter profile.
6. Add AI tool observability attribute set and tests.

## Verification Artifacts

1. `features/quantum_ai_tool_contracts.feature`
2. `test/features/steps/quantum_ai_tool_contracts_steps.ex`
3. `test/nx_quantum/ai/tool_contract_test.exs`
4. `test/nx_quantum/observability_ai_tool_calls_test.exs`
5. `test/nx_quantum/ai_tool_transport_contract_test.exs`

## Open Questions

1. Should Phase 19 HTTP profile ship immediately, or stay optional until Phase 20?
2. Which payload size limits and batching semantics should be hard-enforced in v1?
3. Which minimum quality/latency thresholds should gate `fallback` vs `ok` status for each tool?
4. Which CloudEvents broker integration should be first-class in Phase 20 (SNS/SQS, EventBridge, Kafka, or Azure Event Grid)?

## References (Standards and Open Sources)

1. MCP specification:
   - https://modelcontextprotocol.io/specification/2024-11-05/index
2. JSON-RPC 2.0:
   - https://www.jsonrpc.org/specification
3. OpenAPI 3.1:
   - https://spec.openapis.org/oas/v3.1.0
4. JSON Schema 2020-12:
   - https://json-schema.org/draft/2020-12
5. W3C Trace Context:
   - https://www.w3.org/TR/trace-context/
6. OpenTelemetry semantic conventions:
   - https://opentelemetry.io/docs/concepts/semantic-conventions/
7. RFC 9457 Problem Details:
   - https://www.ietf.org/rfc/rfc9457.html
8. CloudEvents:
   - https://cloudevents.io/
9. Qiskit primitives:
   - https://quantum.cloud.ibm.com/docs/en/api/qiskit/primitives
10. OpenQASM 3:
   - https://openqasm.com/language/
11. QIR Alliance ecosystem:
   - https://www.qir-alliance.org/qir-book/concepts/why-do-we-need.html
