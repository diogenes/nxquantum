# NxQuantum Architecture

## Goal

Provide high-performance QML primitives in pure Elixir by expressing circuits as tensor operations
that can be compiled and accelerated through Nx backends.

## Architecture Style

- DDD for explicit domain language.
- Hexagonal (Ports and Adapters) for testability and backend flexibility.
- SOLID for module responsibilities and extension points.

## Bounded Contexts

1. Circuit Definition (Domain)
- Declarative circuit building.
- Gate operation validation.
- Measurement/observable declaration.

2. Circuit Execution (Application)
- Orchestrates simulation requests.
- Resolves simulator and backend adapters.
- Returns typed numerical results.

3. Numerical Runtime (Infrastructure)
- Tensor kernel execution.
- Backend compilation strategy (CPU/GPU via EXLA or others).

## Feature-to-Context Mapping

Behavior ownership is defined by executable features, not by file location alone.

- Source of truth: `docs/bounded-context-map.md`
- Every refactor must trace from `features/*.feature` -> context -> modules.
- Cross-context orchestration belongs in application services, not domain entities.

## Core Port Contracts

- `NxQuantum.Ports.Simulator`
  - `expectation/2`
  - `apply_gates/3`
- `NxQuantum.Ports.Backend`
  - `compile/3`
  - `default_options/0`

## v0.2 Facade Modules

- `NxQuantum.Runtime`: explicit runtime profile and fallback policy resolution.
- `NxQuantum.Estimator`: expectation execution boundary for hybrid ML workflows.
- `NxQuantum.Sampler`: shot-based sampling primitive boundary.
- `NxQuantum.Mitigation`: composable error-mitigation pipeline facade.
- `NxQuantum.Transpiler`: topology-aware transpilation facade.
- `NxQuantum.Grad`: differentiation mode facade.
- `NxQuantum.Compiler`: deterministic circuit optimization pass entrypoint.
- `NxQuantum.Kernels`: quantum kernel matrix entrypoint.

Current internal decomposition examples:

- Estimation internals: `NxQuantum.Estimator.Batch`, `NxQuantum.Estimator.Scalar`, `NxQuantum.Estimator.ObservableSpecs`, `NxQuantum.Estimator.Measurement`, `NxQuantum.Estimator.Stochastic`.
- Transpilation internals: `NxQuantum.Transpiler.Topology`, `NxQuantum.Transpiler.Router`, `NxQuantum.Transpiler.SwapInsertion`, `NxQuantum.Transpiler.Report`.
- Differentiation internals: `NxQuantum.Grad.Numeric`, `NxQuantum.Grad.Adjoint`, `NxQuantum.Grad.Error`.
- Simulator internals: `NxQuantum.Adapters.Simulators.StateVector.State`, `NxQuantum.Adapters.Simulators.StateVector.Matrices`.
- Compiler internals: `NxQuantum.Compiler.PassPipeline`, `NxQuantum.Compiler.Passes.*`, `NxQuantum.Compiler.Theta`.
- Mitigation internals: `NxQuantum.Mitigation.PassPipeline`, `NxQuantum.Mitigation.Passes.Readout`, `NxQuantum.Mitigation.Passes.ZneLinear`, `NxQuantum.Mitigation.Trace`.
- Runtime internals: `NxQuantum.Runtime.Catalog`, `NxQuantum.Runtime.Detection`, `NxQuantum.Runtime.Fallback`.
- Sampler internals: `NxQuantum.Sampler.Options`, `NxQuantum.Sampler.Engine`, `NxQuantum.Sampler.ResultBuilder`.
- Circuit domain invariants: `NxQuantum.Circuit.Validation`, `NxQuantum.Circuit.Error`.
- Shared observable/measurement schema: `NxQuantum.Observables.Schema`, `NxQuantum.Observables.Error`.

## Dependency Direction

`Domain <- Application <- Adapters`

Domain never depends on adapters, and application depends only on ports.

## Refactoring Policy

1. Keep public API modules stable (`NxQuantum`, `Circuit`, `Gates`, `Runtime`, `Estimator`, `Sampler`, etc.).
2. Move procedural orchestration into small internal modules per bounded context.
3. Enforce single responsibility at module level and typed contracts at context boundaries.

## Initial Tradeoffs

- Start with state-vector simulator before density-matrix/noise channels.
- Keep first kernels simple and correctness-first.
- Delay hard optimization until invariants are covered by property tests.
