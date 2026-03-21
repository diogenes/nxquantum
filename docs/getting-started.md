# Getting Started

This guide is for ML engineers and researchers who want to run quantum workflows inside Elixir + `Nx`.

## 1) Setup

```bash
mise trust
mise install
mix setup
```

Optional backend lanes:

```bash
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mix test
NXQ_ENABLE_EXLA=1 NXQ_ENABLE_TORCHX=0 mix test
```

## 2) Quick Scripts

```bash
mix run examples/quantum_kernel_classifier.exs
mix run examples/axon_hybrid_train_step.exs
```

## 3) Core API Examples

### Circuit + expectation

```elixir
alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates

circuit =
  Circuit.new(qubits: 2)
  |> Gates.h(0)
  |> Gates.cnot(control: 0, target: 1)
  |> Gates.ry(1, theta: Nx.tensor(0.3))

expectation =
  Estimator.expectation(
    circuit,
    observable: :pauli_z,
    wire: 1,
    runtime_profile: :cpu_portable
  )
```

### Batched estimator

```elixir
angles = Nx.tensor([0.0, 0.5, 1.0, 1.5])

builder = fn theta ->
  NxQuantum.Circuit.new(qubits: 1)
  |> NxQuantum.Gates.ry(0, theta: theta)
end

{:ok, values} =
  NxQuantum.Estimator.batched_expectation(
    builder,
    angles,
    observable: :pauli_z,
    wire: 0,
    parallel: true,
    max_concurrency: System.schedulers_online()
  )
```

### Sampler + mitigation

```elixir
circuit =
  NxQuantum.Circuit.new(qubits: 1)
  |> NxQuantum.Gates.ry(0, theta: Nx.tensor(1.2))

{:ok, sample} = NxQuantum.Sampler.run(circuit, shots: 2048, seed: 2026)

calibration = Nx.tensor([[0.95, 0.05], [0.06, 0.94]], type: {:f, 32})

{:ok, mitigated} =
  NxQuantum.Mitigation.pipeline(sample, [
    {:readout, calibration: calibration},
    {:zne_linear, scales: [1.0, 2.0, 3.0]}
  ])
```

### Batched sampler (optional parallel lane)

```elixir
angles = Nx.tensor([0.1, 0.2, 0.3, 0.4], type: {:f, 32})

builder = fn theta ->
  NxQuantum.Circuit.new(qubits: 1)
  |> NxQuantum.Gates.ry(0, theta: theta)
end

{:ok, samples} =
  NxQuantum.Sampler.batched_run(builder, angles,
    shots: 1024,
    seed: 11,
    parallel: true,
    max_concurrency: System.schedulers_online()
  )
```

### Kernel matrix

```elixir
x =
  Nx.tensor([
    [0.0, 0.1],
    [0.2, 0.3],
    [0.4, 0.5],
    [0.6, 0.7]
  ])

k = NxQuantum.Kernels.matrix(x, gamma: 0.7, seed: 1234)
```

### Topology-aware transpilation

```elixir
circuit =
  NxQuantum.Circuit.new(qubits: 4)
  |> NxQuantum.Gates.cnot(control: 0, target: 3)

{:ok, transpiled, report} =
  NxQuantum.Transpiler.run(
    circuit,
    topology: {:coupling_map, [{0, 1}, {1, 2}, {2, 3}]},
    mode: :insert_swaps
  )
```
