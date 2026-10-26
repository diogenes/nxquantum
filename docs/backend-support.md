# Backend Support Strategy (Pareto)

## Objective

Maximize practical coverage with minimal initial complexity by selecting a small set of backend
profiles that covers most developer and production environments.

## Pareto Selection

Initial supported profiles:

1. `cpu_portable` -> `Nx.BinaryBackend` (P0)
2. `cpu_compiled` -> `EXLA.Backend` on host CPU (P0)
3. `nvidia_gpu_compiled` -> `EXLA.Backend` on CUDA (P0)
4. `torch_interop_runtime` -> `Torchx.Backend` (P1)

Execution policy:

1. NxQuantum configures compiler/backend by runtime profile.
2. Tensor execution still delegates to native Nx backends.
3. Fallback behavior is explicit and deterministic:
   - `:strict` -> typed error.
   - `:allow_cpu_compiled` -> deterministic fallback to `:cpu_compiled` with warning code.
4. Runtime capabilities are auto-detected:
   - `cpu_portable`: always available.
   - `cpu_compiled`: available when EXLA host client is detected.
   - `nvidia_gpu_compiled`: available when EXLA CUDA client is detected.
   - `torch_interop_runtime`: available when `Torchx.Backend` is loadable.

Rationale:

- `Nx.BinaryBackend` offers a zero-native-setup baseline for onboarding and CI portability.
- `EXLA.Backend` covers the primary high-performance path for CPU and NVIDIA GPU.
- `Torchx.Backend` provides an additional high-value runtime path and interop flexibility.
- Together, these 4 profiles cover the majority of expected local-dev + production setups with
  bounded maintenance cost.

## Simulation Paths

The internal scale selector (`Scale.select/3`, hidden from HexDocs) reports one of two simulation paths:

1. `:dense_state_vector` (up to the dense threshold, 20 qubits by default): executed.
2. `:tensor_network_fallback` (above the threshold, or `:large_scale_preferred`): **routing label only.**
   No tensor-network engine executes it. Circuits still run through the dense path, and the report
   is the only effect. Treat it as a decision record, not a capability.

A tensor-network contraction engine is parked in `docs/vision.md` §11 until a benchmark shows a win over
dense simulation at 20 qubits or below.

## Numerical Precision

Decision (2026-10-25, KG-10, option A): the state-vector simulator stays single precision. This section documents the floor.

- Gate matrices and the state are `complex64` (`lib/nx_quantum/adapters/simulators/state_vector/matrix_library.ex`, `lib/nx_quantum/adapters/simulators/state_vector/state.ex`).
- `NxQuantum.Circuit.expectation/2` and the `NxQuantum.Estimator` expectation outputs are returned as `{:f, 32}`.

Measured against a float64 dense reference, with fixed seeds (reproduce with `MIX_ENV=test mix run bench/numerics_precision_floor.exs`; two runs were byte-identical; run date 2026-10-26, Elixir 1.19.5 on OTP 28, Nx 1.0.0 and complex 1.0.0, default BinaryBackend; evidence `bench/results/2026-10-26-h1.6/after-pr-a/precision_run1.txt` and `precision_run2.txt`):

| qubits | depth | circuits | observations | max abs error vs float64 | max abs error vs float32(reference) | exact after float32 rounding |
| --- | --- | --- | --- | --- | --- | --- |
| 4 | 18 | 10 | 120 | 3.18e-07 | 2.98e-07 | 45.8% |
| 6 | 18 | 10 | 180 | 2.38e-07 | 2.38e-07 | 66.1% |
| 6 | 200 | 5 | 90 | 4.40e-07 | 4.47e-07 | 2.2% |

A rerun on Elixir 1.20.4 / OTP 29.1.2 is pending H1.6 PR-B.

What this means:

1. Expectation values agree with a float64 reference to about 5e-7 absolute, over the measured range (up to 6 qubits, depth up to 200). This is a measured bound, not a guarantee beyond that range.
2. The error is float32 arithmetic inside the state, not only the output cast. Output rounding alone does not explain it.
3. Determinism is unaffected: the same inputs and seed give the same bits. Precision only sets the accuracy floor.
4. Comparisons with float64 frameworks (Qiskit, PennyLane, Cirq) need an absolute tolerance of at least 1e-6.
5. `resynthesize_1q` reads its angles from these matrices, so its angles carry about 1e-7 error. Its documented `resynthesis_tolerance` is 1e-6 (`docs/roadmap.md`, KG-10).
6. The dense reference used for the measurement is limited to 6 qubits. Larger-width accuracy claims need a cross-framework float64 reference.

Changing the precision is a public contract change (the output dtype of `expectation/2`). Reopen KG-10 with an `api change` intent if an external user needs float64 agreement, or if a benchmark shows a cheap path to complex128.

## Deferred Backends (Post-Foundation)

- `EXLA` on `:rocm` (AMD GPU tuning and validation).
- `EXLA` on `:tpu` (specialized infra).
- `Mlx.Backend` (Apple MLX ecosystem) pending maturity and dedicated validation matrix.

## Source Notes

Primary references used for this planning decision:

- Nx monorepo project split (`Nx`, `EXLA`, `Torchx`):
  [elixir-nx/nx](https://github.com/elixir-nx/nx)
- EXLA client/platform support (`:host`, `:cuda`, `:rocm`, `:tpu`):
  [EXLA docs](https://hexdocs.pm/exla/EXLA.html)
- MLX Nx backend availability:
  [Mlx.Backend docs](https://hexdocs.pm/elixir_mlx/Mlx.Backend.html)

## Acceptance Criteria Mapping

See:

- `features/backend_compilation.feature`
- `test/features/steps/backend_compilation_steps.ex`
- `test/features/features_test.exs`
