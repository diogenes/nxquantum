# ADR 0007: Migration Assurance Toolkit (Additive Library APIs)

- Status: Proposed
- Date: 2026-03-22

## Context

NxQuantum already provides deterministic execution contracts, typed provider lifecycle envelopes, and profile-driven observability.

Teams migrating from Python-first workflows still need a first-class way to:

1. produce canonical, reproducible workflow manifests,
2. compare reference and NxQuantum outputs with explicit tolerance budgets,
3. emit machine-readable promotion decisions for CI and rollout gates.

This must be achieved without changing NxQuantum's architecture boundary: NxQuantum remains a standalone library and must not embed orchestration/control-plane responsibilities.

## Decision

Introduce an additive **Migration Assurance Toolkit** in NxQuantum as optional library APIs.

Scope of this ADR:

1. Additive, non-breaking public APIs under `NxQuantum.Migration.*`.
2. Deterministic report contracts suitable for CI and external tooling.
3. Explicit non-goals for scheduling, global retry orchestration, dashboards, tenancy, or fleet management.

## Proposed API Surface (Examples)

### 1) Canonical Workflow Manifest

```elixir
{:ok, manifest} =
  NxQuantum.Migration.Manifest.new(
    workflow: :sampler,
    circuit: circuit,
    observable: :pauli_z,
    wire: 1,
    params: Nx.tensor([0.2, 0.4]),
    seed: 2026,
    shots: 4096,
    runtime_profile: :cpu_portable,
    provider: :ibm_runtime,
    target: "ibm_backend_simulator",
    capability_contract: :v1
  )
```

Expected output shape (conceptual):

```elixir
%NxQuantum.Migration.Manifest{
  workflow: :sampler,
  fingerprint: "nxqfp_v1_...",
  canonical_input: %{...},
  runtime_profile: :cpu_portable,
  provider: :ibm_runtime,
  target: "ibm_backend_simulator",
  seed: 2026,
  shots: 4096,
  schema_version: :v1
}
```

### 2) Deterministic Output Comparison

```elixir
{:ok, comparison} =
  NxQuantum.Migration.Compare.outputs(reference_result, nxq_result,
    kind: :sampler,
    tolerances: %{
      expectation_abs: 1.0e-3,
      sample_kl_divergence: 5.0e-2,
      latency_delta_ms: 25.0
    },
    manifest: manifest
  )
```

Expected output shape (conceptual):

```elixir
%NxQuantum.Migration.Comparison{
  fingerprint: "nxqfp_v1_...",
  deltas: %{
    expectation_abs: 0.0004,
    sample_kl_divergence: 0.012,
    latency_delta_ms: 8.7
  },
  tolerances: %{...},
  pass: true,
  reasons: [],
  schema_version: :v1
}
```

### 3) Promotion Gate Decision

```elixir
{:ok, decision} =
  NxQuantum.Migration.Gates.evaluate(comparison,
    require_all: true,
    failure_code: :migration_tolerance_exceeded
  )
```

Expected output shape (conceptual):

```elixir
%NxQuantum.Migration.Decision{
  status: :pass,
  code: :ok,
  fingerprint: "nxqfp_v1_...",
  failed_checks: [],
  summary: "all tolerance gates satisfied",
  schema_version: :v1
}
```

### 4) Machine-Readable Report Export

```elixir
report_map = NxQuantum.Migration.Report.to_map(manifest, comparison, decision)
json = Jason.encode!(report_map)
```

Report keys should remain versioned and stable for CI ingestion.

## Architecture and Boundary Rules

Dependency direction remains: `Domain <- Application <- Adapters`.

Mandatory boundaries:

1. `NxQuantum.Migration.*` may consume existing NxQuantum contracts (`Estimator`, `Sampler`, `ProviderBridge`, `Observability`), but must not depend on external orchestration products.
2. No global job scheduler, queue manager, or fleet orchestration behavior in this toolkit.
3. No dashboard/UI responsibilities in NxQuantum.
4. APIs must remain useful for standalone production users and equally consumable by external telemetry/capability clients.

## Compatibility and Versioning

1. Additive API introduction only (no breaking changes to existing facades).
2. All migration report/decision structs include explicit `schema_version`.
3. Changes to report shape require a documented contract version bump and migration notes.

## Consequences

Positive:

1. Strong migration confidence with deterministic evidence.
2. First-class CI-ready promotion gates without infrastructure coupling.
3. Better interoperability with any external manager, telemetry client, or workflow orchestrator.

Negative:

1. Additional surface area to maintain.
2. Risk of overlap with ad-hoc scripts unless contract ownership is explicit.
3. Requires strict schema governance for long-term stability.

## Alternatives Considered

1. Docs/scripts only, no library API additions.
   - Rejected: weak machine-consumable contract stability and duplicated comparison logic.
2. Embed migration orchestration workflows in NxQuantum.
   - Rejected: violates boundary and expands NxQuantum into infra-product scope.
3. Keep migration checks private/internal.
   - Rejected: prevents ecosystem adoption and CI standardization.

## Follow-up (If Accepted)

1. Define `NxQuantum.Migration.*` modules and typespecs with `schema_version` contracts.
2. Add feature scenarios and unit/property tests for manifest determinism, delta correctness, and gate decisions.
3. Publish migration-assurance usage docs with reference CI examples.
