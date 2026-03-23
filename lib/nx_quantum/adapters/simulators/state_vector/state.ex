defmodule NxQuantum.Adapters.Simulators.StateVector.State do
  @moduledoc false

  import Nx.Defn

  alias NxQuantum.Adapters.Simulators.StateVector.Matrices
  alias NxQuantum.Adapters.Simulators.StateVector.Operations.Cnot
  alias NxQuantum.Adapters.Simulators.StateVector.Operations.Dense
  alias NxQuantum.Adapters.Simulators.StateVector.Operations.SingleQubit
  alias NxQuantum.GateOperation

  @real_single_qubit_gates [:h, :x, :z, :ry]
  @real_supported_gates [:cnot | @real_single_qubit_gates]

  @spec initial_state(pos_integer()) :: Nx.Tensor.t()
  def initial_state(qubits) do
    size = trunc(:math.pow(2, qubits))
    values = [1.0 | List.duplicate(0.0, size - 1)]
    Nx.tensor(values, type: {:c, 64})
  end

  @spec initial_state_real(pos_integer()) :: Nx.Tensor.t()
  def initial_state_real(qubits) do
    size = trunc(:math.pow(2, qubits))
    values = [1.0 | List.duplicate(0.0, size - 1)]
    Nx.tensor(values, type: {:f, 64})
  end

  @spec apply_operations(Nx.Tensor.t(), [GateOperation.t()]) :: Nx.Tensor.t()
  def apply_operations(%Nx.Tensor{} = state, operations) when is_list(operations) do
    qubits = qubit_count_from_state(state)
    compiled_plan = Matrices.compiled_execution_plan(operations, qubits)

    Enum.reduce(compiled_plan, state, fn compiled_op, acc ->
      apply_compiled_operation(acc, compiled_op, qubits)
    end)
  end

  @spec apply_operations_real(Nx.Tensor.t(), [GateOperation.t()]) :: Nx.Tensor.t()
  def apply_operations_real(%Nx.Tensor{} = state, operations) when is_list(operations) do
    qubits = qubit_count_from_state(state)
    compiled_plan = Matrices.compiled_execution_plan(operations, qubits)

    Enum.reduce(compiled_plan, state, fn compiled_op, acc ->
      apply_compiled_operation_real(acc, compiled_op, qubits)
    end)
  end

  @spec real_path_eligible?([GateOperation.t()]) :: boolean()
  def real_path_eligible?(operations) when is_list(operations) do
    Enum.all?(operations, fn
      %GateOperation{name: name} -> name in @real_supported_gates
      _ -> false
    end)
  end

  @spec expectation_pauli_z(Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def expectation_pauli_z(%Nx.Tensor{} = state, wire, qubits) do
    probabilities = probabilities(state)
    expectation_pauli_z_from_probabilities(probabilities, wire, qubits)
  end

  @spec expectation_pauli_z_from_probabilities(Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def expectation_pauli_z_from_probabilities(%Nx.Tensor{} = probabilities, wire, qubits) do
    signs = Matrices.pauli_z_signs(wire, qubits)
    Nx.sum(Nx.multiply(probabilities, signs))
  end

  @spec expectation_pauli_x(Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def expectation_pauli_x(%Nx.Tensor{} = state, wire, qubits) do
    state
    |> pairwise_overlap(wire, qubits)
    |> Nx.real()
    |> Nx.sum()
    |> Nx.multiply(2.0)
  end

  @spec expectation_pauli_y(Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def expectation_pauli_y(%Nx.Tensor{} = state, wire, qubits) do
    state
    |> pairwise_overlap(wire, qubits)
    |> Nx.imag()
    |> Nx.sum()
    |> Nx.multiply(2.0)
  end

  @spec expectation_pauli_xy(Nx.Tensor.t(), non_neg_integer(), pos_integer()) :: {Nx.Tensor.t(), Nx.Tensor.t()}
  def expectation_pauli_xy(%Nx.Tensor{} = state, wire, qubits) do
    overlap = pairwise_overlap(state, wire, qubits)
    x = overlap |> Nx.real() |> Nx.sum() |> Nx.multiply(2.0)
    y = overlap |> Nx.imag() |> Nx.sum() |> Nx.multiply(2.0)
    {x, y}
  end

  @spec expectation_from_state(Nx.Tensor.t(), Nx.Tensor.t()) :: Nx.Tensor.t()
  def expectation_from_state(state, observable_matrix) do
    expectation_kernel(state, observable_matrix)
  end

  @spec probabilities(Nx.Tensor.t()) :: Nx.Tensor.t()
  def probabilities(%Nx.Tensor{} = state) do
    Nx.real(Nx.multiply(state, Nx.conjugate(state)))
  end

  defp qubit_count_from_state(%Nx.Tensor{} = state) do
    size = elem(Nx.shape(state), 0)
    size |> :math.log2() |> round()
  end

  defp apply_compiled_operation(%Nx.Tensor{} = state, %SingleQubit{} = op, qubits) do
    if qubits <= 2 do
      apply_single_qubit_gate_small(op.gate_matrix, state, op.wire, qubits)
    else
      apply_single_qubit_gate_pairwise(op.gate_coefficients, op.layout, state)
    end
  end

  defp apply_compiled_operation(%Nx.Tensor{} = state, %Cnot{} = op, _qubits) do
    apply_permutation_kernel(op.permutation, state)
  end

  defp apply_compiled_operation(%Nx.Tensor{} = state, %Dense{} = op, _qubits) do
    apply_gate_kernel(op.matrix, state)
  end

  defp apply_compiled_operation_real(%Nx.Tensor{} = state, %SingleQubit{} = op, qubits) do
    coeffs = op.real_gate_coefficients || real_coefficients(op.gate_coefficients)

    if qubits <= 2 do
      apply_single_qubit_gate_small(Nx.real(op.gate_matrix), state, op.wire, qubits)
    else
      apply_single_qubit_gate_pairwise(coeffs, op.layout, state)
    end
  end

  defp apply_compiled_operation_real(%Nx.Tensor{} = state, %Cnot{} = op, _qubits) do
    apply_permutation_kernel(op.permutation, state)
  end

  defp apply_compiled_operation_real(%Nx.Tensor{} = state, %Dense{} = op, _qubits) do
    state
    |> Nx.as_type({:c, 64})
    |> apply_gate_kernel(op.matrix)
    |> Nx.real()
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

  defp apply_single_qubit_gate_pairwise(gate_coefficients, layout, state) do
    reshaped = Nx.reshape(state, layout.pair_shape)
    %{g00: g00, g01: g01, g10: g10, g11: g11} = gate_coefficients

    v0 =
      reshaped
      |> Nx.slice_along_axis(0, 1, axis: 1)
      |> Nx.reshape({layout.outer_size, layout.inner_size})

    v1 =
      reshaped
      |> Nx.slice_along_axis(1, 1, axis: 1)
      |> Nx.reshape({layout.outer_size, layout.inner_size})

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

  defp real_coefficients(gate_coefficients) do
    %{
      g00: Nx.real(gate_coefficients.g00),
      g01: Nx.real(gate_coefficients.g01),
      g10: Nx.real(gate_coefficients.g10),
      g11: Nx.real(gate_coefficients.g11)
    }
  end

  defp pairwise_overlap(%Nx.Tensor{} = state, wire, qubits) do
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

    Nx.multiply(Nx.conjugate(v0), v1)
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

  defn expectation_kernel(state, observable_matrix) do
    obs_state = Nx.dot(observable_matrix, state)
    Nx.real(Nx.sum(Nx.multiply(Nx.conjugate(state), obs_state)))
  end
end
