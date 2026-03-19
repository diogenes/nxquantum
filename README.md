# NxQuantum

Pure-Elixir quantum circuit simulation and quantum machine learning primitives powered by `Nx`.

## Why NxQuantum

`NxQuantum` treats quantum state vectors and gates as tensor transformations, so the entire execution
path can be compiled and accelerated on BEAM-compatible numerical backends.

Core principles:

- Pipelines over configuration.
- `Nx.Defn`-ready APIs.
- Composable, test-first architecture (DDD + Hexagonal).

## Current Status

This repository is currently in **planning + skeleton phase**:

- Architecture and domain boundaries are defined.
- Public API shape is scaffolded.
- Feature specs and executable feature-test scaffolding are in place.
- Core simulator implementation is intentionally minimal.
- v0.3 specification work is active, with deterministic topology-routing scenarios prioritized.

## Quickstart

```bash
mise trust
mise install
mix setup
mix test
mix test.features
mix quality
```

## Mix vs Mise

- `mix` is the source of truth for project tasks and dependencies.
- `mix` alone does not enforce Erlang/Elixir versions across developer machines.
- `mise` is used here only to pin/install the local toolchain (`erlang`, `elixir`) from `mise.toml`.
- After toolchain setup, all daily commands stay on `mix`.

See [docs/development-flow.md](docs/development-flow.md) for full developer workflow and task catalog.

## VSCode Cucumber

If you use the Cucumber extension in VSCode, refresh editor glue after feature-step changes:

```bash
mix features.sync_glue
```

## Backend Lanes

Dependency lanes can be toggled to keep local setup and CI reproducible:

- `NXQ_ENABLE_EXLA=1|0` (default `1`)
- `NXQ_ENABLE_TORCHX=1|0` (default `0`)

Examples:

```bash
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mix test
NXQ_ENABLE_EXLA=1 NXQ_ENABLE_TORCHX=0 mix test
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=1 mix test
```

## API Preview

```elixir
alias NxQuantum.Circuit
alias NxQuantum.Gates

Circuit.new(qubits: 2)
|> Gates.h(0)
|> Gates.rx(0, theta: Nx.tensor(0.3))
|> Gates.cnot(control: 0, target: 1)
|> Gates.ry(1, theta: Nx.tensor(0.1))
|> Circuit.expectation(observable: :pauli_z, wire: 1)
```

## Architecture Snapshot

- Domain:
  - `NxQuantum.Circuit`
  - `NxQuantum.GateOperation`
  - `NxQuantum.Observables`
- Application:
  - `NxQuantum.Application.ExecuteCircuit`
- Ports:
  - `NxQuantum.Ports.Simulator`
  - `NxQuantum.Ports.Backend`
- Adapters:
  - `NxQuantum.Adapters.Simulators.StateVector`
  - `NxQuantum.Adapters.Backends.NxBackend`

See [docs/architecture.md](docs/architecture.md) for details.

## Development Documentation

- [CONTRIBUTING.md](CONTRIBUTING.md)
- [docs/development-flow.md](docs/development-flow.md)
- [docs/backend-support.md](docs/backend-support.md)
- [docs/bounded-context-map.md](docs/bounded-context-map.md)
- [docs/v0.2-feature-spec.md](docs/v0.2-feature-spec.md)
- [docs/v0.2-improvement-plan.md](docs/v0.2-improvement-plan.md)
- [docs/v0.3-feature-spec.md](docs/v0.3-feature-spec.md)
- [docs/testing-strategy.md](docs/testing-strategy.md)
- [docs/roadmap.md](docs/roadmap.md)
- [AGENTS.md](AGENTS.md)
- [SKILLS.md](SKILLS.md)
