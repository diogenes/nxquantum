# v0.5 Provider Migration Packs

Status note (as of March 20, 2026):

1. This document is the migration evidence pack for v0.5 Milestone K.
2. Scope is deterministic fixture-first migration for top-3 providers.
3. Acceptance mapping source of truth:
   - `docs/archive/v0.5-acceptance-criteria.md` (F6)
   - `features/provider_cross_platform_rollout.feature`

## Shared Preflight Checklist

Run this checklist before migrating any provider workflow:

1. Pin deterministic inputs:
   - parameter vectors
   - shots
   - seed
   - target/runtime profile
2. Validate provider capability envelope through `NxQuantum.ProviderBridge` preflight.
3. Confirm typed failure handling is wired for:
   - `provider_auth_error`
   - `provider_capability_mismatch`
   - `provider_invalid_response`
   - `provider_execution_error`
4. Enable fixture mode in CI and smoke tests before live credential lanes.
5. Capture observability profile (`high_level` by default) and retain fingerprint metadata.

## Pack A: Qiskit Runtime -> NxQuantum (IBM Runtime)

### Migration intent

1. Move primitive-centric estimator/sampler workloads to `NxQuantum.ProviderBridge` with `IBMRuntime` adapter.

### Contract mapping

1. Python workflow intent: estimator/sampler primitive submission.
2. NxQuantum path:

```elixir
alias NxQuantum.Adapters.Providers.IBMRuntime
alias NxQuantum.ProviderBridge

payload = %{workflow: :sampler, shots: 1024}

ProviderBridge.run_lifecycle(IBMRuntime, payload,
  target: "ibm_backend_simulator",
  provider_config: %{
    auth_token: "ibm-token",
    channel: "ibm_cloud",
    backend: "ibm_backend_simulator"
  }
)
```

### Parity checkpoints

1. Normalized envelopes include required keys (`id/state/provider/target/payload/metadata`).
2. Unknown provider state returns typed `provider_invalid_response`.
3. Unsupported capability fails preflight before remote submission.

### Acceptance traceability

1. `features/provider_ibm_runtime_bridge.feature`
2. `features/provider_capability_contracts.feature`
3. `features/provider_cross_platform_rollout.feature`

## Pack B: Braket workflows -> NxQuantum (AWS Braket)

### Migration intent

1. Move Braket gate-model lifecycle workloads to `AwsBraket` adapter with deterministic preflight checks.

### Contract mapping

```elixir
alias NxQuantum.Adapters.Providers.AwsBraket
alias NxQuantum.ProviderBridge

payload = %{workflow: :sampler, shots: 1024}

ProviderBridge.run_lifecycle(AwsBraket, payload,
  target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
  provider_config: %{
    region: "us-east-1",
    credentials_profile: "default",
    device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
  }
)
```

### Parity checkpoints

1. Device/target mismatches return typed `provider_capability_mismatch`.
2. Terminal failure/cancelled states are normalized and deterministic.
3. Provider raw payload/state is preserved only under `metadata`.

### Acceptance traceability

1. `features/provider_aws_braket_bridge.feature`
2. `features/provider_capability_contracts.feature`
3. `features/provider_cross_platform_rollout.feature`

## Pack C: Azure Quantum workflows -> NxQuantum

### Migration intent

1. Move workspace/target/provider-selected workflows to `AzureQuantum` adapter with explicit caveat metadata.

### Contract mapping

```elixir
alias NxQuantum.Adapters.Providers.AzureQuantum
alias NxQuantum.ProviderBridge

payload = %{workflow: :sampler, shots: 1024}

ProviderBridge.run_lifecycle(AzureQuantum, payload,
  target: "azure.quantum.sim",
  provider_config: %{
    workspace: "ws-1",
    auth_context: "managed_identity",
    target_id: "azure.quantum.sim",
    provider_name: "microsoft"
  }
)
```

### Parity checkpoints

1. Target/provider mismatch returns typed capability error.
2. Cancellation caveats are explicit in metadata.
3. Cross-provider envelope parity remains deterministic for equivalent inputs.

### Acceptance traceability

1. `features/provider_azure_quantum_bridge.feature`
2. `features/provider_cross_platform_rollout.feature`
3. `features/provider_observability.feature`

## Runnable Tutorial and Benchmark Linkage

1. Side-by-side fixture tutorial:
   - `examples/livebook/provider_bridge_side_by_side.livemd`
2. Reproducible benchmark script:
   - `bench/milestone_k.exs`
3. Benchmark evidence and caveats:
   - `docs/provider-benchmark-matrix.md`

## Known Caveats (v0.5)

1. Fixture mode is mandatory for deterministic CI acceptance.
2. Live provider lanes remain optional and must not weaken typed contract guarantees.
3. Gate-model path is the primary v0.5 workflow scope across providers.
