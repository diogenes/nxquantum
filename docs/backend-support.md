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
