# Model Recipes

Deterministic workflow recipes for v0.2 advanced ML usage.

## 1) Quantum Kernel + Classical Model

Use `NxQuantum.Kernels.matrix/2` to produce a deterministic Gram matrix:

```elixir
x = Nx.tensor([[0.1, 0.2], [0.3, 0.4], [0.5, 0.6]])
k = NxQuantum.Kernels.matrix(x, gamma: 0.7, seed: 1234)
```

Then feed `k` into your classical kernel pipeline (ridge/SVM-like workflows).

See:

- `examples/quantum_kernel_classifier.exs`

## 2) Hybrid Scalar Head Training

Optimize a variational parameter with `Estimator.expectation/2` + `Grad.value_and_grad/3`.

See:

- `docs/axon-integration.md`
- `examples/axon_hybrid_train_step.exs`

## 3) Shot-Based Evaluation (and the Scalar Noise Option)

Seeded shots give reproducible finite-sampling estimates:

```elixir
NxQuantum.Estimator.expectation_result(
  circuit,
  shots: 2048,
  seed: 2026
)
```

The `noise:` option (`noise: [depolarizing: p, amplitude_damping: g]`) is a scalar model, not a noise channel. It rescales the final ideal expectation, so it ignores circuit depth and which qubits the gates act on, and its amplitude-damping shift is the ⟨Z⟩ formula applied to every observable (`docs/roadmap.md`, KG-30). Use it only as a coarse sensitivity knob, not as a model of hardware noise. Channel-based noise is planned (`docs/roadmap.md`, decision PD-5).

Keep seed, shots, and options fixed between runs for reproducibility.
