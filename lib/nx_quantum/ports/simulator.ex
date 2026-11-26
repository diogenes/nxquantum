defmodule NxQuantum.Ports.Simulator do
  @moduledoc """
  Port for simulation engines that execute circuit operations.

  `expectation_with_simulation/2` and `expectations_with_simulation/3` return the value together with
  `simulation_facts()`, a provider-neutral record of how the value was produced. Callers read the facts
  from the return value. Simulators never publish them through process state.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation

  @type simulation_facts :: %{
          method: :state_vector | nil,
          evolution_path: :real_pauli_z | :complex | :mixed | nil,
          state_backend: :portable | :compiled | :other | :mixed | nil,
          cache_status: :hit | :miss | :bypass | :mixed | :unknown,
          expectation_path: :fused_single_wire | :generic | :mixed | nil,
          fused_kernel: %{requested_kernel: atom(), selected_kernel: atom(), reason: atom()}
        }

  @callback expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  @callback expectations(Circuit.t(), [map()], keyword()) :: Nx.Tensor.t()
  @callback expectation_with_simulation(Circuit.t(), keyword()) :: {Nx.Tensor.t(), simulation_facts()}
  @callback expectations_with_simulation(Circuit.t(), [map()], keyword()) ::
              {Nx.Tensor.t(), simulation_facts()}
  @callback apply_gates(Nx.Tensor.t(), [GateOperation.t()], keyword()) :: Nx.Tensor.t()

  @optional_callbacks expectations: 3, expectation_with_simulation: 2, expectations_with_simulation: 3

  @doc "Facts for a simulator that does not report them. Every field is unknown or nil."
  @spec unreported_facts() :: simulation_facts()
  def unreported_facts do
    %{
      method: nil,
      evolution_path: nil,
      state_backend: nil,
      cache_status: :unknown,
      expectation_path: nil,
      fused_kernel: %{requested_kernel: :unknown, selected_kernel: :unknown, reason: :not_applicable}
    }
  end
end
