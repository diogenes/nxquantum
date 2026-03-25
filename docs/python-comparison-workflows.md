# Side-by-Side Workflows: NxQuantum vs Python-First Stacks

This guide compares equivalent tasks for ML engineers evaluating NxQuantum against Python-first quantum tooling.

Status note (as of March 19, 2026):

1. Python snippets here are conceptual workflow references, not API parity claims.
2. Hardware-provider breadth is generally deeper in Python-first stacks today.
3. Deterministic claims in this document refer to seeded simulator/fixture lanes and typed contract behavior, not guaranteed identical live QPU measurement outcomes.

## 1) Expectation Estimation

### NxQuantum (Elixir)

```elixir
alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates

circuit =
  Circuit.new(qubits: 2)
  |> Gates.h(0)
  |> Gates.cnot(control: 0, target: 1)
  |> Gates.ry(1, theta: Nx.tensor(0.3))

{:ok, value} =
  Estimator.expectation_result(
    circuit,
    observable: :pauli_z,
    wire: 1,
    runtime_profile: :cpu_portable
  )
```

### Python-first pattern (conceptual)

```python
# Build circuit, choose backend, run expectation job, extract result
```

## 2) Shot Sampling

### NxQuantum (Elixir)

```elixir
{:ok, sample} = NxQuantum.Sampler.run(circuit, shots: 2048, seed: 2026)
```

### Python-first pattern (conceptual)

```python
# Build transpiled circuit, configure sampler primitive, set seed/shots, run
```

## 3) Kernel Matrix Generation

### NxQuantum (Elixir)

```elixir
x = Nx.tensor([[0.0, 0.1], [0.2, 0.3], [0.4, 0.5]])
k = NxQuantum.Kernels.matrix(x, gamma: 0.7, seed: 1234)
```

### Python-first pattern (conceptual)

```python
# Encode dataset with feature map, evaluate pairwise kernels, form Gram matrix
```

## 4) Topology-Aware Transpilation

### NxQuantum (Elixir)

```elixir
{:ok, transpiled, report} =
  NxQuantum.Transpiler.run(
    circuit,
    topology: {:coupling_map, [{0, 1}, {1, 2}, {2, 3}]},
    mode: :insert_swaps
  )
```

### Python-first pattern (conceptual)

```python
# Provide coupling map, pick routing strategy, transpile and inspect swap report
```

## Practical Takeaway

NxQuantum is strongest when your ML + serving stack already runs on Elixir/BEAM and you want deterministic-by-default simulator/fixture workflows with typed contracts without crossing language boundaries.

For broader hardware-provider coverage today, Python-first stacks are often ahead.
