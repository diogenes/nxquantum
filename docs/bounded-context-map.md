# NxQuantum Bounded Context Map

## Purpose

This map keeps refactoring grounded in behavior. Every internal structural change should start from
`features/*.feature` and preserve public API contracts while clarifying domain/application/adapter boundaries.

## Contexts

### 1) Circuit Authoring Context

- Features:
  - `features/variational_circuit.feature`
  - authoring portions of `features/hybrid_training.feature`
- Public entrypoints:
  - NxQuantum.Circuit
  - NxQuantum.Gates
- Domain modules:
  - NxQuantum.Circuit
  - NxQuantum.Circuit.Validation
  - NxQuantum.Circuit.Error
  - NxQuantum.GateOperation
  - NxQuantum.Observables
  - NxQuantum.Observables.Schema
  - NxQuantum.Observables.Error
- Invariants:
  - circuit immutability
  - gate ordering
  - measurable circuit declaration

### 2) Runtime Profile Context

- Features:
  - `features/backend_compilation.feature`
- Public entrypoints:
  - NxQuantum.Runtime
  - runtime options accepted by NxQuantum.Estimator and NxQuantum.Sampler
- Domain/application modules:
  - NxQuantum.Runtime
  - NxQuantum.Runtime.Catalog
  - NxQuantum.Runtime.Detection
  - NxQuantum.Runtime.Fallback
- Ports/adapters:
  - backend capability detection delegates to Nx/EXLA/Torchx availability
- Invariants:
  - deterministic fallback contract
  - typed runtime errors for unsupported/unavailable profiles

### 3) Primitive Estimation Context

- Features:
  - `features/primitives_api.feature`
  - `features/noise_and_shots.feature`
  - estimator portions of `features/batched_pqc.feature`
- Public entrypoints:
  - NxQuantum.Estimator
  - `Circuit.expectation/2`
- Application services:
  - NxQuantum.Application.ExecuteCircuit
- Domain modules:
  - NxQuantum.Estimator.Batch
  - NxQuantum.Estimator.Batch.Strategy
  - NxQuantum.Estimator.Batch.Strategies.Deterministic
  - NxQuantum.Estimator.Batch.Strategies.ScalarFallback
  - NxQuantum.Estimator.ExecutionMode
  - NxQuantum.Estimator.ResultBuilder
  - NxQuantum.Estimator.RuntimeProfile
  - NxQuantum.Estimator.SampledExpval
  - NxQuantum.Estimator.Scalar
  - NxQuantum.Estimator.ObservableSpecs
  - NxQuantum.Estimator.Measurement
  - NxQuantum.Estimator.Stochastic
  - NxQuantum.Observables.SparsePauli
- Ports/adapters:
  - NxQuantum.Ports.Simulator
  - NxQuantum.Adapters.Simulators.StateVector
  - NxQuantum.Adapters.Simulators.StateVector.State
  - NxQuantum.Adapters.Simulators.StateVector.Matrices
- Invariants:
  - deterministic seeded estimation
  - stable observable ordering and typed errors

### 4) Primitive Sampling and Mitigation Context

- Features:
  - `features/primitives_api.feature` (Sampler scenarios)
  - `features/error_mitigation.feature`
  - sampler portions of `features/batched_pqc.feature`
- Public entrypoints:
  - NxQuantum.Sampler
  - NxQuantum.Mitigation
- Domain modules:
  - NxQuantum.Sampler.Result
  - NxQuantum.Sampler.Options
  - NxQuantum.Sampler.Engine
  - NxQuantum.Sampler.ResultBuilder
  - NxQuantum.Sampler.ExecutionMode
  - NxQuantum.Sampler.BatchedRunner
  - NxQuantum.Sampler.Batch.Strategy
  - NxQuantum.Sampler.Batch.Strategies.Sequential
  - NxQuantum.Sampler.Batch.Strategies.Parallel
  - mitigation pipeline pass contracts
  - NxQuantum.Mitigation.PassPipeline
  - NxQuantum.Mitigation.Passes.Readout
  - NxQuantum.Mitigation.Passes.ZneLinear
  - NxQuantum.Mitigation.Trace
- Invariants:
  - deterministic counts/probabilities for fixed seed
  - explicit mitigation pass ordering and typed mitigation errors

### 5) Differentiation Context

- Features:
  - `features/differentiation_modes.feature`
  - gradient portions of `features/hybrid_training.feature`
- Public entrypoints:
  - NxQuantum.Grad
- Domain modules:
  - NxQuantum.Grad.Numeric (`:backprop`, `:parameter_shift`)
  - NxQuantum.Grad.Adjoint
  - NxQuantum.Grad.Error
- Invariants:
  - typed mode/contract errors
  - deterministic gradients for fixed inputs

### 6) Compilation and Optimization Context

- Features:
  - `features/circuit_optimization.feature`
- Public entrypoints:
  - NxQuantum.Compiler
- Domain modules:
  - NxQuantum.Compiler.PassPipeline
  - NxQuantum.Compiler.Passes.Simplify
  - NxQuantum.Compiler.Passes.Fuse
  - NxQuantum.Compiler.Passes.Cancel
  - NxQuantum.Compiler.Passes.Resynthesize1Q
  - NxQuantum.Compiler.Theta
- Invariants:
  - semantic equivalence under optimization
  - explicit before/after report contracts

### 7) Transpilation Context

- Features:
  - `features/topology_transpilation.feature`
- Public entrypoints:
  - NxQuantum.Transpiler
- Domain/application modules:
  - NxQuantum.Transpiler.Topology
  - NxQuantum.Transpiler.Router
  - NxQuantum.Transpiler.SwapInsertion
  - NxQuantum.Transpiler.Report
- Invariants:
  - strict-mode typed violations
  - deterministic shortest-path and tie-break behavior

### 8) Kernel Methods Context

- Features:
  - `features/quantum_kernel_methods.feature`
- Public entrypoints:
  - NxQuantum.Kernels
- Domain modules:
  - deterministic kernel matrix generation
- Invariants:
  - symmetry and PSD constraints within tolerance

### 9) Dynamic IR Foundation Context

- Features:
  - `features/dynamic_circuit_ir_foundation.feature`
- Public entrypoints:
  - currently validated through feature-step behavior contracts
- Domain modules:
  - dynamic IR node validation contracts
- Invariants:
  - typed validation errors
  - explicit no-execution boundary for v0.3

### 10) Dynamic Execution and Provider Bridge Context (v0.5 P0 active)

- Features:
  - `features/dynamic_execution_hardware_bridges.feature`
  - `features/provider_capability_contracts.feature`
  - `features/provider_ibm_runtime_bridge.feature`
  - `features/provider_aws_braket_bridge.feature`
  - `features/provider_azure_quantum_bridge.feature`
  - `features/provider_google_quantum_ai_bridge.feature`
  - `features/provider_cross_platform_rollout.feature`
  - `features/provider_observability.feature`
- Planned public entrypoints:
  - dynamic execution entrypoint over NxQuantum.DynamicIR
  - provider lifecycle orchestration through NxQuantum.ProviderBridge
- Domain/application modules:
  - dynamic execution interpreter (supported subset)
  - provider lifecycle facade (NxQuantum.ProviderBridge) delegating to:
    - NxQuantum.Application.ProviderLifecycle.Runner
    - NxQuantum.Application.ProviderLifecycle.Dispatcher
    - NxQuantum.Application.ProviderLifecycle.Preflight
    - NxQuantum.Application.ProviderLifecycle.ErrorMapper
    - NxQuantum.Application.ProviderLifecycle.Commands.*
  - provider lifecycle contract objects:
    - NxQuantum.ProviderBridge.Job
    - NxQuantum.ProviderBridge.Result
    - NxQuantum.ProviderBridge.ProviderError
    - NxQuantum.ProviderBridge.CapabilityContract
  - provider lifecycle port contract (NxQuantum.Ports.Provider)
  - capability preflight domain contract (NxQuantum.Providers.Capabilities)
  - provider config/redaction contracts (NxQuantum.Providers.Config, NxQuantum.Providers.Redaction)
  - calibration payload validation contracts
- Adapter modules:
  - NxQuantum.Adapters.Providers.IBMRuntime
  - NxQuantum.Adapters.Providers.AwsBraket
  - NxQuantum.Adapters.Providers.AzureQuantum
  - NxQuantum.Adapters.Providers.GoogleQuantumAI
  - NxQuantum.Adapters.Providers.Common.LifecycleSupport
  - NxQuantum.Adapters.Providers.Common.LiveTransport
  - NxQuantum.Adapters.Providers.Common.StateMapper
  - NxQuantum.Adapters.Providers.Common.TransportSupport
  - NxQuantum.Adapters.Observability.OpenTelemetry
  - NxQuantum.Adapters.Observability.Noop
  - NxQuantum.ProviderBridge.ReplayFixture
- Observability modules:
  - NxQuantum.Observability
  - NxQuantum.Observability.Profile
  - NxQuantum.Observability.ProfileStrategy
  - NxQuantum.Observability.ProfileStrategy.HighLevel
  - NxQuantum.Observability.ProfileStrategy.Granular
  - NxQuantum.Observability.ProfileStrategy.Forensics
  - NxQuantum.Observability.Fingerprint
  - NxQuantum.Observability.PortabilityDelta
- Invariants:
  - deterministic dynamic branch execution for supported subset
  - typed provider lifecycle and capability/error diagnostics
  - deterministic unsupported-capability preflight (no silent provider fallback)
  - uniform workflow validation behavior across providers
  - profile-driven telemetry depth with deterministic schema fields

### 10.1) State-Vector Execution Planning Subcontext (v0.5 P0 active)

- Features:
  - `features/primitives_api.feature`
  - `features/quantum_kernel_methods.feature`
- Application/domain modules:
  - NxQuantum.Adapters.Simulators.StateVector.Matrices (facade)
  - NxQuantum.Adapters.Simulators.StateVector.MatrixLibrary
  - NxQuantum.Adapters.Simulators.StateVector.CompiledPlan
  - NxQuantum.Adapters.Simulators.StateVector.Operations
  - NxQuantum.Adapters.Simulators.StateVector.Cache
  - NxQuantum.Adapters.Simulators.StateVector.KeyEncoder
  - NxQuantum.Application.BatchExecutor
  - NxQuantum.Random.Seed
- Invariants:
  - compiled-plan semantic equivalence with matrix execution
  - deterministic cache behavior under bounded eviction
  - deterministic seeded behavior for estimator/sampler/kernel entrypoints

### 11) Scale and Performance Context (Planned v0.4)

- Features:
  - `features/scale_and_performance.feature`
- Planned public entrypoints:
  - scale strategy options under execution facades
  - benchmark/report interfaces
- Planned domain/application modules:
  - large-scale fallback strategy contracts
  - benchmark matrix/report builders
  - regression threshold evaluators
- Invariants:
  - deterministic fallback selection
  - reproducible benchmark evidence

### 12) Product Positioning Context (Planned v0.4)

- Artifacts:
  - positioning and comparison docs
  - migration playbooks and case-study narratives
- Planned public assets:
  - side-by-side workflow guides
  - migration playbooks
  - decision matrix and case-study evidence
  - provider migration packs and release-hardening evidence (`v0.5`):
    - `docs/migration-packs.md`
    - `docs/provider-benchmark-matrix.md`
    - `docs/provider-support-catalog.md`
- Invariants:
  - claims backed by reproducible scripts/benchmarks
  - limitations explicitly documented

### 13) Quantum AI Tool Contract Context (Planned v1.0)

- Features:
  - `features/quantum_ai_tool_contracts.feature`
  - `features/quantum_ai_rollout_gates.feature`
  - `features/hybrid_quantum_ai_benchmark_pack.feature`
- Datasets (synthetic fixtures; KG-5):
  - `bench/datasets/rerank/`
- Planned public entrypoints:
  - `NxQuantum.AI`
- Domain/application modules:
  - `NxQuantum.AI`
  - `NxQuantum.AI.Request`
  - `NxQuantum.AI.Result`
  - `NxQuantum.AI.Error`
  - `NxQuantum.AI.ToolRunner`
  - `lib/nx_quantum/ai/tools/kernel_rerank.ex` (kernel rerank tool module)
  - `lib/nx_quantum/ai/tools/kernel_rerank/execution_strategy.ex` (execution strategy module)
- Ports/adapters:
  - `NxQuantum.Ports.AIToolTransport`
  - `NxQuantum.Ports.VectorQuantizer`
  - `NxQuantum.Adapters.AIToolTransport.McpJsonRpcSync`
  - `NxQuantum.Adapters.AIToolTransport.CloudEventsAsync`
  - `NxQuantum.Adapters.VectorQuantization.TurboQuant`
- Invariants:
  - canonical tool envelopes stay transport-neutral and versioned
  - sync and async execution paths preserve typed deterministic errors
  - trace/correlation metadata remains intact end-to-end
  - quantized rerank lane remains deterministic for fixed seed and bounded parallel settings

## Refactor Rules

1. Start from one context and one behavior slice.
2. Keep public APIs stable; move complexity behind internal modules.
3. Keep dependency direction: `Domain <- Application <- Adapters`.
4. Update this map whenever feature ownership or module boundaries change.
