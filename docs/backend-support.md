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

Measured against a float64 dense reference, with fixed seeds (reproduce with `MIX_ENV=test mix run bench/numerics_precision_floor.exs`; two runs per toolchain were byte-identical; run date 2026-10-26, Nx 1.0.0 and complex 1.0.0, default BinaryBackend; evidence on Elixir 1.19.5 / OTP 28: `bench/results/2026-10-26-h1.6/after-pr-a/precision_run1.txt` and `precision_run2.txt`; evidence on Elixir 1.20.4 / OTP 29.1.2: `bench/results/2026-10-26-h1.6/after-pr-b/precision_run1.txt` and `precision_run2.txt`; the two toolchains' outputs are byte-identical):

| qubits | depth | circuits | observations | max abs error vs float64 | max abs error vs float32(reference) | exact after float32 rounding |
| --- | --- | --- | --- | --- | --- | --- |
| 4 | 18 | 10 | 120 | 3.18e-07 | 2.98e-07 | 45.8% |
| 6 | 18 | 10 | 180 | 2.38e-07 | 2.38e-07 | 66.1% |
| 6 | 200 | 5 | 90 | 4.40e-07 | 4.47e-07 | 2.2% |

What this means:

1. Expectation values agree with a float64 reference to about 5e-7 absolute, over the measured range (up to 6 qubits, depth up to 200). This is a measured bound, not a guarantee beyond that range.
2. The error is float32 arithmetic inside the state, not only the output cast. Output rounding alone does not explain it.
3. Determinism is unaffected: the same inputs and seed give the same bits. Precision only sets the accuracy floor.
4. Comparisons with float64 frameworks (Qiskit, PennyLane, Cirq) need an absolute tolerance of at least 1e-6.
5. `resynthesize_1q` reads its angles from these matrices, so its angles carry about 1e-7 error. Its documented `resynthesis_tolerance` is 1e-6 (`docs/roadmap.md`, KG-10).
6. The dense reference used for the measurement is limited to 6 qubits. Larger-width accuracy claims need a cross-framework float64 reference.

Changing the precision is a public contract change (the output dtype of `expectation/2`). Reopen KG-10 with an `api change` intent if an external user needs float64 agreement, or if a benchmark shows a cheap path to complex128.

## Evolution Path Metadata

`NxQuantum.Estimator.run/2` results carry `metadata.simulation` (experimental, additive, KG-20). It reports which state-vector evolution path produced the state for that call. The fields are plain atoms and module names, and they never change numeric results.

| Field | Values | Meaning |
| --- | --- | --- |
| `method` | `:state_vector` or `nil` | `:state_vector` when the state was produced, or served from the evolved-state cache, in this call. `nil` when the simulator does not report the field. A cache hit is still `:state_vector`; read `strategy_observability.cache_status` to tell a hit from a miss. |
| `evolution_path` | `:real_pauli_z`, `:complex`, `:mixed`, or `nil` | `:real_pauli_z` when the real-amplitude path ran (H, X, Z, RY, and CNOT only, with a `pauli_z` measurement). `:complex` otherwise. `nil` when the state was served from the evolved-state cache, so no evolution ran in this call. `:mixed` when one call evolved with different paths. |
| `state_backend` | `:portable`, `:compiled`, `:other`, `:mixed`, or `nil` | A neutral label for the backend of the state tensor after the runtime transfer. `:portable` for `Nx.BinaryBackend`, `:compiled` for the EXLA backend, `:other` for any other backend. The Nx module itself is not exposed. A failed transfer is not an error: the field then reports the backend the state actually has, which can differ from the requested profile. |
| `expectation_path` | `:fused_single_wire`, `:generic`, `:mixed`, or `nil` | `:fused_single_wire` when the fused single-wire Pauli kernel evaluated the observables. This is reported from the branch that ran, and that branch is taken only for at least 24 single-wire Pauli terms on at most 12 qubits in a non-parallel plan. `:generic` for every other evaluation. `nil` when no observable was evaluated in this call. |

Not reported, because the code has no choice to report:

- Gate application always runs through the compiled execution plan, so there is no "compiled-plan vs per-gate" field.
- Expectation kernels run on the state tensor's backend (`backend_from_state/1` in `pauli_expval/fused_single_wire.ex`), so there is no separate `expectation_backend`. Read `state_backend` for both.

The facts reach the Estimator through the return value of the simulator port (`expectation_with_simulation/2` and `expectations_with_simulation/3` in `NxQuantum.Ports.Simulator`), not through process state. A simulator that does not implement those callbacks reports nil fields.

`metadata.strategy_observability` keeps its existing fields. `cache_status` (`:hit`, `:miss`, `:bypass`, or `:mixed` when a scalar fallback run had both) and the `fused_kernel_*` fields keep their meaning. `metadata.simulation` adds the path and backend facts those fields do not give.

`NxQuantum.Estimator.expectation/2` and `expectation_result/2` return a tensor, not a `Result`, so they carry no metadata.

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
