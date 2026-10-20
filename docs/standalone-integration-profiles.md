# Standalone and External Integration Profiles (v0.7)

This guide defines two runnable usage profiles:

1. Standalone production profile (default fixture-first behavior).
2. External-operations integration profile (machine-consumable contract outputs).

Both profiles preserve the same public lifecycle contract and do not require orchestration features inside NxQuantum.

## Profile A: Standalone Production

Use this profile when NxQuantum runs directly inside a BEAM service and you want deterministic typed lifecycle behavior with low-overhead telemetry.

```elixir
alias NxQuantum.Adapters.Observability.OpenTelemetry
alias NxQuantum.Adapters.Providers.IBMRuntime
alias NxQuantum.ProviderBridge

payload = %{workflow: :sampler, shots: 1024}

opts = [
  target: "ibm_backend_simulator",
  provider_config: %{
    auth_token: "token",
    channel: "ibm_cloud",
    backend: "ibm_backend_simulator"
  },
  observability: [
    enabled: true,
    adapter: OpenTelemetry,
    profile: :high_level
  ]
]

{:ok, %{submitted: submitted, polled: polled, result: result}} =
  ProviderBridge.run_lifecycle(IBMRuntime, payload, opts)

submitted.schema_version
# :v1
```

Expected contract notes:

1. `submitted`, `polled`, and `result` envelopes remain typed and deterministic.
2. `schema_version`, `correlation_id`, and `idempotency_key` are explicit in the returned envelopes.
3. High-level profile keeps metric cardinality bounded.

## Profile B: External Operations Integration

Use this profile when a separate client/tooling layer consumes NxQuantum lifecycle output.

```elixir
alias NxQuantum.Adapters.Providers.IBMRuntime
alias NxQuantum.ProviderBridge
alias NxQuantum.ProviderBridge.Serialization

payload = %{workflow: :estimator, shots: 256}

opts = [
  target: "ibm_backend_simulator",
  provider_config: %{
    auth_token: "token",
    channel: "ibm_cloud",
    backend: "ibm_backend_simulator"
  },
  correlation_id: "corr_external_001",
  idempotency_key: "idem_external_001"
]

{:ok, job} = ProviderBridge.submit_job(IBMRuntime, payload, opts)
external_map = Serialization.to_external_map(job)
{:ok, serialized} = Serialization.serialize(job)
```

Expected contract notes:

1. `external_map` is versioned and machine-readable (`schema_version` = `"v1"`).
2. Equivalent envelope input serializes to identical deterministic output.
3. External consumers do not need provider-specific parsing logic beyond metadata extensions.

## Observability Schema Governance Check

```elixir
alias NxQuantum.Adapters.Observability.OpenTelemetry
alias NxQuantum.Observability
alias NxQuantum.Observability.Schema

snapshot = Observability.snapshot(adapter: OpenTelemetry)
:ok = Schema.validate_snapshot(snapshot, :high_level)
```

Validation guarantees:

1. Mandatory lifecycle span names are present.
2. Required metric/log schema keys are present.
3. Sensitive redaction and cardinality rules are enforced.

## Non-Goals (Boundary Reminder)

NxQuantum does not implement:

1. Global queue schedulers.
2. Fleet-level orchestration/retry control planes.
3. Dashboard/RBAC/tenancy systems.

References:

1. `docs/archive/v0.7-feature-spec.md`
2. `docs/archive/v0.7-acceptance-criteria.md`
3. `docs/archive/v0.7-feature-to-step-mapping.md`
4. `docs/release-process.md`

