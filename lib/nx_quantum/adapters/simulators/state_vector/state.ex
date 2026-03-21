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
      apply_operation(acc, op, qubits)
    end)
  end

  @spec expectation_pauli_z(Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def expectation_pauli_z(%Nx.Tensor{} = state, wire, qubits) do
    signs = Matrices.pauli_z_signs(wire, qubits)
    expectation_pauli_z_kernel(state, signs)
  end

  @spec expectation_from_state(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def expectation_from_state(state, observable_matrix) do
    expectation_kernel(state, observable_matrix)
  end

  defp qubit_count_from_state(%Nx.Tensor{} = state) do
    size = elem(Nx.shape(state), 0)
    size |> :math.log2() |> round()
  end

  defp apply_operation(%Nx.Tensor{} = state, %GateOperation{name: name, wires: [wire]} = op, qubits)
       when name in [:h, :x, :y, :z, :rx, :ry, :rz] do
    op
    |> Matrices.single_qubit_gate_matrix()
    |> apply_single_qubit_gate(state, wire, qubits)
  end

  defp apply_operation(%Nx.Tensor{} = state, %GateOperation{name: :cnot, wires: [control, target]}, qubits) do
    control
    |> Matrices.cnot_permutation(target, qubits)
    |> apply_permutation_kernel(state)
  end

  defp apply_operation(%Nx.Tensor{} = state, %GateOperation{} = op, qubits) do
    matrix = Matrices.gate_matrix(op, qubits)
    apply_gate_kernel(matrix, state)
  end

  defp apply_single_qubit_gate(gate, state, wire, qubits) do
    if qubits <= 2 do
      apply_single_qubit_gate_small(gate, state, wire, qubits)
    else
      apply_single_qubit_gate_pairwise(gate, state, wire, qubits)
    end
  end

  defp apply_single_qubit_gate_small(gate, state, wire, qubits) do
    axis = qubits - wire - 1
    base_axes = Enum.to_list(0..(qubits - 1))
    transpose_axes = [axis | Enum.reject(base_axes, &(&1 == axis))]
    inverse_axes = invert_permutation(transpose_axes)
    reshaped = Nx.reshape(state, List.to_tuple(List.duplicate(2, qubits)))
    permuted = Nx.transpose(reshaped, axes: transpose_axes)
    trailing_size = div(elem(Nx.shape(state), 0), 2)
    flattened = Nx.reshape(permuted, {2, trailing_size})
    updated = apply_small_gate_kernel(gate, flattened)
    unflattened = Nx.reshape(updated, List.to_tuple([2 | List.duplicate(2, qubits - 1)]))

    unflattened
    |> Nx.transpose(axes: inverse_axes)
    |> Nx.reshape(Nx.shape(state))
  end

  defp apply_single_qubit_gate_pairwise(gate, state, wire, qubits) do
    layout = Matrices.single_qubit_layout_plan(wire, qubits)
    reshaped = Nx.reshape(state, layout.pair_shape)

    v0 =
      reshaped
      |> Nx.slice_along_axis(0, 1, axis: 1)
      |> Nx.reshape({layout.outer_size, layout.inner_size})

    v1 =
      reshaped
      |> Nx.slice_along_axis(1, 1, axis: 1)
      |> Nx.reshape({layout.outer_size, layout.inner_size})

    g00 = gate_entry(gate, 0, 0)
    g01 = gate_entry(gate, 0, 1)
    g10 = gate_entry(gate, 1, 0)
    g11 = gate_entry(gate, 1, 1)

    updated0 = Nx.add(Nx.multiply(g00, v0), Nx.multiply(g01, v1))
    updated1 = Nx.add(Nx.multiply(g10, v0), Nx.multiply(g11, v1))

    [updated0, updated1]
    |> Nx.stack(axis: 1)
    |> Nx.reshape(layout.state_shape)
  end

  defp invert_permutation(axes) do
    max_axis = length(axes) - 1
    Enum.map(0..max_axis, fn axis -> Enum.find_index(axes, &(&1 == axis)) end)
  end

  defp gate_entry(gate, row, col) do
    gate
    |> Nx.slice([row, col], [1, 1])
    |> Nx.reshape({})
  end

  defn apply_gate_kernel(matrix, state) do
    Nx.dot(matrix, state)
  end

  defn apply_small_gate_kernel(gate, flattened_state) do
    Nx.dot(gate, flattened_state)
  end

  defn apply_permutation_kernel(indices, state) do
    Nx.take(state, indices)
  end

  defn expectation_pauli_z_kernel(state, signs) do
    probabilities = Nx.real(Nx.multiply(state, Nx.conjugate(state)))
    Nx.sum(Nx.multiply(probabilities, signs))
  end

  defn expectation_kernel(state, observable_matrix) do
    obs_state = Nx.dot(observable_matrix, state)
    Nx.real(Nx.sum(Nx.multiply(Nx.conjugate(state), obs_state)))
  end
end
