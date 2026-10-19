# Provider Support Catalog

This is the canonical catalog for the NxQuantum core provider set: identity, support tier, transport lanes, known limits, typed failures, and release-note policy. Merged from the former v0.5 support-tier policy and v0.8 capability matrix on 2026-10-19.

## Support Tiers

1. `stable`: acceptance-covered and fixture-verified in default release gates.
2. `beta`: usable with documented caveats; behavior is typed but may evolve.
3. `experimental`: explicitly non-default paths with limited compatibility guarantees.

## Core Provider Set

| Provider id | Label | Adapter module | Tier | Scope summary | Known limits |
| --- | --- | --- | --- | --- | --- |
| `ibm_runtime` | IBM Runtime | `NxQuantum.Adapters.Providers.IBMRuntime` | stable | Estimator/sampler lifecycle with typed normalization | Depends on explicit backend/channel config |
| `aws_braket` | AWS Braket | `NxQuantum.Adapters.Providers.AwsBraket` | stable | Gate-model lifecycle with capability preflight and typed state/error mapping | Non-gate-model workflows are outside primary scope |
| `azure_quantum` | Azure Quantum | `NxQuantum.Adapters.Providers.AzureQuantum` | beta | Workspace/target/provider lifecycle with caveat metadata | Cancellation semantics can vary by provider phase |
| `google_quantum_ai` | Google Quantum AI | `NxQuantum.Adapters.Providers.GoogleQuantumAI` | stable | Estimator/sampler lifecycle with typed normalization and fixture/live transport parity | Requires explicit project/location/processor configuration |

## Transport and Lifecycle Lanes

| Provider | Fixture | Live smoke readiness | Live | Lifecycle (`submit/poll/cancel/fetch_result`) |
| --- | --- | --- | --- | --- |
| IBM Runtime | yes | yes (env-gated) | yes (env-gated) | yes |
| AWS Braket | yes | yes (env-gated) | yes (env-gated) | yes |
| Azure Quantum | yes | yes (env-gated) | yes (env-gated) | yes |
| Google Quantum AI | yes | yes (env-gated) | yes (env-gated) | yes |

Contract guarantees:

1. Envelope parity across lanes (`schema_version`, `request_id`, `correlation_id`, `idempotency_key`).
2. Unsupported live requests fail fast with typed diagnostics.
3. Fixture lanes stay deterministic for CI and regression checks.
4. `live_smoke` validates readiness and the contract path. Full remote lifecycle execution is guaranteed only in `live`.
5. Live outcomes are probabilistic. Typed contracts are deterministic; measured results are not.

## Typed Failure Catalog

Normalized failure codes exposed through `NxQuantum.ProviderBridge`:

1. `provider_transport_error`
2. `provider_auth_error`
3. `provider_invalid_state`
4. `provider_invalid_response`
5. `provider_capability_mismatch`
6. `provider_execution_error`
7. `provider_rate_limited`

Contract source: `docs/adr/0002-provider-capability-contract-v1.md`.

## Onboarding Policy

When adding a provider:

1. Add a provider matrix entry under test support (`NxQuantum.TestSupport.ProviderMatrix`).
2. Add provider-specific bridge scenarios and tests.
3. Add the provider to this catalog's tables, with its tier and known limits.

## Release Note Template (Per Provider)

1. Provider: `<provider_id>`
2. Tier: `<stable|beta|experimental>`
3. New behavior: `<typed lifecycle or capability updates>`
4. Contract impact: `<public API unchanged | explicit changes>`
5. Known limits: `<provider caveats and non-goals>`
6. Verification evidence: `<feature scenario IDs and benchmark references>`
7. Migration guidance: `<migration pack section links>`

## Evidence Links

1. Migration packs: `docs/migration-packs.md`
2. Benchmarks: `docs/provider-benchmark-matrix.md`
3. Observability conventions: `docs/observability.md`
