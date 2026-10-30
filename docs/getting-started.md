# Getting Started

This guide is for BEAM/Nx teams embedding quantum workloads in Elixir services, and for researchers who need reproducible results. It takes you from an empty project to a first result using the Hex package.

## 1) What You Need

- Elixir `~> 1.19`, on OTP 28 or newer (CI tests OTP 28 and OTP 29, `.github/workflows/ci.yml`).
- No EXLA. EXLA and Torchx are optional (`mix.exs`).
- No environment flags.

## 2) Install

```bash
mix new my_quantum_app
cd my_quantum_app
```

Add the dependency to `mix.exs`, then run `mix deps.get`:

```elixir
defp deps do
  [
    {:nx_quantum, "~> 0.11.0"}
  ]
end
```

`0.11.0` is the current release, on the Nx 0.x line. 0.12.0 (unreleased) moves to Nx 1.0 (CHANGELOG `[Unreleased]`); use `~> 0.12.0` once it is published.

## 3) First Result

Run this in `iex -S mix`:

```elixir
alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates

circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.2)
{:ok, result} = Estimator.run(circuit, observable: :pauli_z, wire: 0)

# The expectation of Z after RY(1.2) is cos(1.2), about 0.3623577.
Nx.to_flat_list(result.values)
```

Expected result: `[0.3623577356338501]`, which is `cos(1.2)` in single precision (the documented precision floor, `docs/backend-support.md`).

`Estimator.run/2` and `result.values` exist in 0.11.0 (`lib/nx_quantum/estimator.ex` and `lib/nx_quantum/estimator/result.ex` at the 0.11.0 release commit) and on `main`.

## 4) What Deterministic Means Here

- Scope: simulator and fixture lanes only. Live provider and QPU results are not deterministic.
- Fixed inputs, seed, runtime profile, and toolchain on one host give the same outputs.
- On the default `Nx.BinaryBackend` the repeat runs are bit-identical. EXLA and Torchx are checked within stated tolerances, not bit-for-bit (`bench/results/2026-10-26-h1.6/SUMMARY.md`: Apple M4, macOS 26.6.2, one host).
- Job ids and fingerprints use OTP's term encoding, which OTP keeps stable only within a major release, so they can change across OTP majors.

The README "Determinism Scope" section has the full statement.

## 5) Errors: Tuple Versus Raise

- Tuple style returns `{:ok, value}` or `{:error, map}`: `Estimator.run/2` and `Estimator.expectation_result/2`. Use it in services and pipelines, where you want to match on the error.
- Raising style: `Estimator.expectation/2` returns the tensor and raises `ArgumentError` when runtime profile resolution fails. Use it in scripts, notebooks, and tests, where a failure should stop the run.

Unknown or misspelled options are currently ignored without an error (KG-25 in `docs/roadmap.md`), so check option names against the docs.

## 6) Next Steps

- Seeded sampling (experimental API). The same seed returns the same counts:

  ```elixir
  circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.1)
  NxQuantum.Sampler.run(circuit, shots: 1024, seed: 13, observable: :pauli_z, wire: 0)
  # counts: %{"0" => 752, "1" => 272}
  ```

  The counts are pinned in `test/nx_quantum/sampler_test.exs` on `main`.
- Interactive notebooks: [docs/livebook-tutorials.md](livebook-tutorials.md).
- Optional EXLA backend: [docs/backend-support.md](backend-support.md). The first result does not need it.
- More facades (`batched_expectation`, `Sampler.batched_run`, `Mitigation.pipeline`, `Kernels.matrix`, `Transpiler.run`): [docs/model-recipes.md](model-recipes.md), [docs/axon-integration.md](axon-integration.md), and `examples/`.
- Contributor setup (mise, `mix setup`, quality gates): [CONTRIBUTING.md](../CONTRIBUTING.md).
