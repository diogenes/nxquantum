defmodule NxQuantum.Adapters.Simulators.StateVector.State do
  @moduledoc false

  import Nx.Defn

  alias NxQuantum.Adapters.Simulators.StateVector.Matrices
  alias NxQuantum.GateOperation

  @spec initial_state(pos_integer()) :: Nx.Tensor.t()
  def initial_state(qubits) do
    size = trunc(:math.pow(2, qubits))
    values = [1.0 | List.duplicate(0.0, size - 1)]
    Nx.tensor(values, type: {:c, 64})
  end

  @spec apply_operations(Nx.Tensor.t(), [GateOperation.t()]) :: Nx.Tensor.t()
  def apply_operations(%Nx.Tensor{} = state, operations) when is_list(operations) do
    qubits = qubit_count_from_state(state)

    Enum.reduce(operations, state, fn %GateOperation{} = op, acc ->
      matrix = Matrices.gate_matrix(op, qubits)
      apply_gate_kernel(matrix, acc)
    end)
  end

  @spec expectation_from_state(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def expectation_from_state(state, observable_matrix) do
    expectation_kernel(state, observable_matrix)
  end

  defp qubit_count_from_state(%Nx.Tensor{} = state) do
    size = elem(Nx.shape(state), 0)
    size |> :math.log2() |> round()
  end

  defn apply_gate_kernel(matrix, state) do
    Nx.dot(matrix, state)
  end

  defn expectation_kernel(state, observable_matrix) do
    obs_state = Nx.dot(observable_matrix, state)
    Nx.real(Nx.sum(Nx.multiply(Nx.conjugate(state), obs_state)))
  end
end
