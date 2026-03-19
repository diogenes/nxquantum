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
  - `NxQuantum.Circuit`
  - `NxQuantum.Gates`
- Domain modules:
  - `NxQuantum.Circuit`
  - `NxQuantum.Circuit.Validation`
  - `NxQuantum.Circuit.Error`
  - `NxQuantum.GateOperation`
  - `NxQuantum.Observables`
  - `NxQuantum.Observables.Schema`
  - `NxQuantum.Observables.Error`
- Invariants:
  - circuit immutability
  - gate ordering
  - measurable circuit declaration

### 2) Runtime Profile Context

- Features:
  - `features/backend_compilation.feature`
- Public entrypoints:
  - `NxQuantum.Runtime`
  - runtime options accepted by `NxQuantum.Estimator` and `NxQuantum.Sampler`
- Domain/application modules:
  - `NxQuantum.Runtime`
  - `NxQuantum.Runtime.Catalog`
  - `NxQuantum.Runtime.Detection`
  - `NxQuantum.Runtime.Fallback`
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
  - `NxQuantum.Estimator`
  - `Circuit.expectation/2`
- Application services:
  - `NxQuantum.Application.ExecuteCircuit`
- Domain modules:
  - `NxQuantum.Estimator.Batch`
  - `NxQuantum.Estimator.Scalar`
  - `NxQuantum.Estimator.ObservableSpecs`
  - `NxQuantum.Estimator.Measurement`
  - `NxQuantum.Estimator.Stochastic`
- Ports/adapters:
  - `NxQuantum.Ports.Simulator`
  - `NxQuantum.Adapters.Simulators.StateVector`
  - `NxQuantum.Adapters.Simulators.StateVector.State`
  - `NxQuantum.Adapters.Simulators.StateVector.Matrices`
- Invariants:
  - deterministic seeded estimation
  - stable observable ordering and typed errors

### 4) Primitive Sampling and Mitigation Context

- Features:
  - `features/primitives_api.feature` (Sampler scenarios)
  - `features/error_mitigation.feature`
  - sampler portions of `features/batched_pqc.feature`
- Public entrypoints:
  - `NxQuantum.Sampler`
  - `NxQuantum.Mitigation`
- Domain modules:
  - `NxQuantum.Sampler.Result`
  - `NxQuantum.Sampler.Options`
  - `NxQuantum.Sampler.Engine`
  - `NxQuantum.Sampler.ResultBuilder`
  - mitigation pipeline pass contracts
  - `NxQuantum.Mitigation.PassPipeline`
  - `NxQuantum.Mitigation.Passes.Readout`
  - `NxQuantum.Mitigation.Passes.ZneLinear`
  - `NxQuantum.Mitigation.Trace`
- Invariants:
  - deterministic counts/probabilities for fixed seed
  - explicit mitigation pass ordering and typed mitigation errors

### 5) Differentiation Context

- Features:
  - `features/differentiation_modes.feature`
  - gradient portions of `features/hybrid_training.feature`
- Public entrypoints:
  - `NxQuantum.Grad`
- Domain modules:
  - `NxQuantum.Grad.Numeric` (`:backprop`, `:parameter_shift`)
  - `NxQuantum.Grad.Adjoint`
  - `NxQuantum.Grad.Error`
- Invariants:
  - typed mode/contract errors
  - deterministic gradients for fixed inputs

### 6) Compilation and Optimization Context

- Features:
  - `features/circuit_optimization.feature`
- Public entrypoints:
  - `NxQuantum.Compiler`
- Domain modules:
  - `NxQuantum.Compiler.PassPipeline`
  - `NxQuantum.Compiler.Passes.Simplify`
  - `NxQuantum.Compiler.Passes.Fuse`
  - `NxQuantum.Compiler.Passes.Cancel`
  - `NxQuantum.Compiler.Theta`
- Invariants:
  - semantic equivalence under optimization
  - explicit before/after report contracts

### 7) Transpilation Context

- Features:
  - `features/topology_transpilation.feature`
- Public entrypoints:
  - `NxQuantum.Transpiler`
- Domain/application modules:
  - `NxQuantum.Transpiler.Topology`
  - `NxQuantum.Transpiler.Router`
  - `NxQuantum.Transpiler.SwapInsertion`
  - `NxQuantum.Transpiler.Report`
- Invariants:
  - strict-mode typed violations
  - deterministic shortest-path and tie-break behavior

### 8) Kernel Methods Context

- Features:
  - `features/quantum_kernel_methods.feature`
- Public entrypoints:
  - `NxQuantum.Kernels`
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

## Refactor Rules

1. Start from one context and one behavior slice.
2. Keep public APIs stable; move complexity behind internal modules.
3. Keep dependency direction: `Domain <- Application <- Adapters`.
4. Update this map whenever feature ownership or module boundaries change.
