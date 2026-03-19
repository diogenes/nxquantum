defmodule NxQuantum.Adapters.Simulators.StateVector do
  @moduledoc """
  State-vector simulator adapter.

  This module intentionally starts as correctness-first scaffold. Tensorized
  `Nx.Defn` kernels will be introduced incrementally once invariants are covered
  by unit/property tests.
  """

  @behaviour NxQuantum.Ports.Simulator

  alias NxQuantum.Adapters.Simulators.StateVector.Matrices
  alias NxQuantum.Adapters.Simulators.StateVector.State
  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation

  @type state_vector :: Nx.Tensor.t()

  @impl true
  @spec expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  def expectation(%Circuit{measurement: nil}, _opts) do
    raise ArgumentError, "measurement not set; call Circuit.expectation/2 with observable and wire"
  end

  def expectation(%Circuit{} = circuit, _opts) do
    state =
      circuit.qubits
      |> State.initial_state()
      |> State.apply_operations(circuit.operations)

    %{observable: observable, wire: wire} = circuit.measurement
    observable_matrix = Matrices.observable_matrix(observable, wire, circuit.qubits)

    state
    |> State.expectation_from_state(observable_matrix)
    |> Nx.as_type({:f, 32})
  end

  @impl true
  @spec apply_gates(state_vector(), [GateOperation.t()], keyword()) :: state_vector()
  def apply_gates(%Nx.Tensor{} = state, operations, _opts) when is_list(operations) do
    State.apply_operations(state, operations)
  end
end
