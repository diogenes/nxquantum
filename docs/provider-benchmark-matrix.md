# v0.5 Provider Benchmark Matrix (Deterministic)

Status note (as of March 20, 2026):

1. This matrix is the reproducible benchmark evidence for Milestone K.
2. Results represent fixture-based lifecycle benchmarking for cross-provider comparability.

## Reproducible Command

```bash
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mise exec -- mix run bench/milestone_k.exs
```

## Benchmark Scope

1. Workflow: `:sampler`
2. Shots: `1024`
3. Iterations per provider: `30`
4. Providers:
   - `ibm_runtime`
   - `aws_braket`
   - `azure_quantum`
5. Runtime profile: `cpu_portable`

## Reference Output Snapshot (2026-03-20)

| Provider | Mean latency (ms) | P95 latency (ms) | Success count | Failure count |
| --- | --- | --- | --- | --- |
| ibm_runtime | 0.074 | 0.448 | 30 | 0 |
| aws_braket | 0.015 | 0.005 | 30 | 0 |
| azure_quantum | 0.019 | 0.022 | 30 | 0 |

## Provider Caveats

1. `ibm_runtime`
   - Primitive-centric workflow assumptions are first-class.
   - Backend configuration must be explicit.
2. `aws_braket`
   - Gate-model workflow path is primary in v0.5.
   - Device selector mismatch is expected to fail preflight.
3. `azure_quantum`
   - Workspace/target/provider match must be explicit.
   - Cancellation semantics may vary by provider phase and are represented as caveat metadata.

## Evidence Traceability

1. Acceptance criteria: `docs/archive/v0.5-acceptance-criteria.md` (F6).
2. Feature linkage: `features/provider_cross_platform_rollout.feature`.
3. Adapter contracts:
   - `docs/adr/0003-ibm-runtime-provider-adapter.md`
   - `docs/adr/0004-aws-braket-provider-adapter.md`
   - `docs/adr/0005-azure-quantum-provider-adapter.md`
