Feature: Backend compilation strategy
  As a performance-focused engineer
  I want quantum evaluation to be a pure tensor operation within Nx.defn
  So that it can be automatically JIT-compiled for CPU/GPU using standard backend policies

  # Strategy:
  # - NxQuantum publishes explicit runtime profiles for product clarity.
  # - Each profile delegates execution to native Nx backend/compiler settings.
  # - We do not implement hidden backend-specific kernels or implicit routing.

  Rule: Pareto runtime profiles with Nx-native delegation
    Background:
      Given the supported runtime profiles are
        | profile_id            | compiler | nx_backend       | target_hardware               | support_tier |
        | cpu_portable          | nil      | Nx.BinaryBackend | Any CPU (zero native setup)   | P0           |
        | cpu_compiled          | EXLA     | EXLA.Backend     | Production CPU                | P0           |
        | nvidia_gpu_compiled   | EXLA     | EXLA.Backend     | NVIDIA GPU via CUDA           | P0           |
        | torch_interop_runtime | nil      | Torchx.Backend   | CPU/GPU with LibTorch runtime | P1           |
      And a quantum circuit representing a state-vector simulation
      And the expectation operation is implemented as a pure tensor contraction

    Scenario Outline: Compile and execute expectation by runtime profile
      Given runtime profile "<profile_id>" is configured
      And the default compiler is set to "<compiler>"
      And the default backend is set to "<nx_backend>"
      When I compile the expectation function for the circuit
      Then execution uses the native "<nx_backend>" without custom backend routing
      And tensor operations are executed on the "<target_hardware>"

      Examples:
        | profile_id            | compiler | nx_backend       | target_hardware               |
        | cpu_portable          | nil      | Nx.BinaryBackend | Any CPU (zero native setup)   |
        | cpu_compiled          | EXLA     | EXLA.Backend     | Production CPU                |
        | nvidia_gpu_compiled   | EXLA     | EXLA.Backend     | NVIDIA GPU via CUDA           |
        | torch_interop_runtime | nil      | Torchx.Backend   | CPU/GPU with LibTorch runtime |

    Scenario: Deterministic fallback for unavailable accelerated runtime
      Given runtime profile "nvidia_gpu_compiled" is configured
      And fallback policy is "allow_cpu_compiled"
      And CUDA runtime is unavailable
      When I evaluate the expectation within defn
      Then runtime profile "cpu_compiled" is selected
      And warning code "NXQ_BACKEND_FALLBACK_001" is emitted

    Scenario: Strict policy errors when accelerated runtime is unavailable
      Given runtime profile "nvidia_gpu_compiled" is configured
      And fallback policy is "strict"
      And CUDA runtime is unavailable
      When I evaluate the expectation within defn
      Then error "backend_unavailable" is returned
      And error metadata includes requested profile "nvidia_gpu_compiled"
      And error metadata includes available fallback "cpu_compiled"

    Scenario: Reject unsupported runtime profile identifier
      Given runtime profile "unknown_profile" is configured
      When I compile the expectation function for the circuit
      Then error "unsupported_runtime_profile" is returned
      And the error lists all supported runtime profile identifiers

    Scenario: Expose runtime profile capability catalog
      When I request the runtime profile catalog
      Then I receive profile id, compiler, backend, hardware target, and support tier
      And each profile includes an "available" capability flag from auto-detection
      And profiles are ordered by support tier priority
