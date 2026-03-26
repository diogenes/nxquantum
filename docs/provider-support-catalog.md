# Provider Support Catalog

This document is the canonical catalog for the NxQuantum core provider set.

Status note (as of March 26, 2026):

1. The core provider set currently includes `IBM Runtime`, `AWS Braket`, and `Azure Quantum`.
2. Provider onboarding should extend this catalog first, then add provider-specific scenarios/tests.

## Core Provider Set

| Provider id | Label | Adapter module | Current support tier | Notes |
| --- | --- | --- | --- | --- |
| `ibm_runtime` | IBM Runtime | `NxQuantum.Adapters.Providers.IBMRuntime` | stable | Estimator/sampler lifecycle with typed normalization. |
| `aws_braket` | AWS Braket | `NxQuantum.Adapters.Providers.AwsBraket` | stable | Gate-model lifecycle; non-gate-model workflows remain outside primary scope. |
| `azure_quantum` | Azure Quantum | `NxQuantum.Adapters.Providers.AzureQuantum` | beta | Workspace/target/provider lifecycle with typed caveat metadata. |

## Onboarding Policy

When adding a provider:

1. Add provider matrix entry under test support (`NxQuantum.TestSupport.ProviderMatrix`).
2. Add provider-specific bridge scenarios and tests.
3. Update this catalog and linked support-tier docs.
