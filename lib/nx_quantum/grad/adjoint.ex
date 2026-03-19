defmodule NxQuantum.Grad.Adjoint do
  @moduledoc false

  import Bitwise

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
  alias NxQuantum.Grad.Error

  @supported_gates [:h, :x, :y, :z, :rx, :ry, :rz, :cnot]
  @parameterized_gates [:rx, :ry, :rz]

  @spec value_and_grad((Nx.Tensor.t() -> Nx.Tensor.t()), Nx.Tensor.t(), keyword()) ::
          {Nx.Tensor.t(), Nx.Tensor.t()}
  def value_and_grad(fun, %Nx.Tensor{} = params, opts) do
    circuit_builder = Keyword.get(opts, :circuit_builder)

    if !is_function(circuit_builder, 1) do
      raise Error.new(:adjoint_requires_circuit_builder)
    end

    circuit =
      case circuit_builder.(params) do
        %Circuit{} = c -> c
        invalid -> raise Error.new(:adjoint_invalid_circuit_builder, %{value: inspect(invalid)})
      end

    ensure_measurement!(circuit)
    ensure_supported_operations!(circuit.operations)

    adjoint_value_and_grad(fun, params, circuit)
  end

  defp adjoint_value_and_grad(fun, params, %Circuit{} = circuit) do
    value = fun.(params)
    qubits = circuit.qubits
    ops = circuit.operations

    flat_params = Nx.to_flat_list(params)
    param_count = length(flat_params)
    op_to_param = op_to_param_index_map(ops, param_count)

    forward_states =
      ops
      |> Enum.reduce([initial_state(qubits)], fn op, [state | _] = acc ->
        next_state = Nx.dot(full_gate_matrix(op, qubits), state)
        [next_state | acc]
      end)
      |> Enum.reverse()

    final_state = List.last(forward_states)
    observable = observable_matrix(circuit, qubits)
    initial_lambda = Nx.dot(observable, final_state)
    grads = List.duplicate(0.0, param_count)

    {grad_values, _lambda} =
      ops
      |> Enum.with_index()
      |> Enum.reverse()
      |> Enum.reduce({grads, initial_lambda}, fn {op, op_index}, {acc_grads, lambda_next} ->
        psi_prev = Enum.at(forward_states, op_index)

        updated_grads =
          case Map.fetch(op_to_param, op_index) do
            {:ok, param_index} ->
              dpsi = Nx.dot(d_gate_matrix(op, qubits), psi_prev)
              scalar = Nx.sum(Nx.multiply(Nx.conjugate(lambda_next), dpsi))
              contribution = 2.0 * Nx.to_number(Nx.real(scalar))
              List.update_at(acc_grads, param_index, &(&1 + contribution))

            :error ->
              acc_grads
          end

        u_dag = Nx.conjugate(Nx.transpose(full_gate_matrix(op, qubits)))
        lambda_prev = Nx.dot(u_dag, lambda_next)
        {updated_grads, lambda_prev}
      end)

    {value, to_tensor(grad_values, Nx.shape(params))}
  end

  defp op_to_param_index_map(ops, param_count) do
    param_op_positions =
      ops
      |> Enum.with_index()
      |> Enum.filter(fn {%GateOperation{name: name}, _i} -> name in @parameterized_gates end)
      |> Enum.map(fn {_op, i} -> i end)

    if length(param_op_positions) != param_count do
      raise Error.new(:adjoint_parameter_mismatch, %{
              parameter_count: param_count,
              parameterized_gate_count: length(param_op_positions)
            })
    end

    param_op_positions
    |> Enum.with_index()
    |> Map.new(fn {op_index, param_index} -> {op_index, param_index} end)
  end

  defp ensure_measurement!(%Circuit{measurement: nil}) do
    raise Error.new(:adjoint_requires_measurement)
  end

  defp ensure_measurement!(%Circuit{}), do: :ok

  defp ensure_supported_operations!(operations) do
    Enum.each(operations, fn %GateOperation{name: name} ->
      if name not in @supported_gates do
        raise Error.new(:unsupported_gradient_mode, %{operation: name, mode: :adjoint})
      end
    end)
  end

  defp observable_matrix(%Circuit{measurement: %{observable: :pauli_z, wire: wire}}, qubits),
    do: full_single_wire_matrix(pauli_z(), wire, qubits)

  defp observable_matrix(%Circuit{measurement: %{observable: :pauli_x, wire: wire}}, qubits),
    do: full_single_wire_matrix(pauli_x(), wire, qubits)

  defp observable_matrix(%Circuit{measurement: %{observable: :pauli_y, wire: wire}}, qubits),
    do: full_single_wire_matrix(pauli_y(), wire, qubits)

  defp observable_matrix(%Circuit{measurement: %{observable: observable}}, _qubits) do
    raise Error.new(:unsupported_observable, %{observable: observable, mode: :adjoint})
  end

  defp full_gate_matrix(%GateOperation{name: :h, wires: [wire]}, qubits),
    do: full_single_wire_matrix(hadamard(), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :x, wires: [wire]}, qubits),
    do: full_single_wire_matrix(pauli_x(), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :y, wires: [wire]}, qubits),
    do: full_single_wire_matrix(pauli_y(), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :z, wires: [wire]}, qubits),
    do: full_single_wire_matrix(pauli_z(), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :rx, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(rx_matrix(Map.fetch!(params, :theta)), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :ry, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(ry_matrix(Map.fetch!(params, :theta)), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :rz, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(rz_matrix(Map.fetch!(params, :theta)), wire, qubits)

  defp full_gate_matrix(%GateOperation{name: :cnot, wires: [control, target]}, qubits),
    do: cnot_matrix(control, target, qubits)

  defp full_gate_matrix(%GateOperation{name: name}, _qubits) do
    raise Error.new(:unsupported_gradient_mode, %{operation: name, mode: :adjoint})
  end

  defp d_gate_matrix(%GateOperation{name: :rx, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(dr_x_matrix(Map.fetch!(params, :theta)), wire, qubits)

  defp d_gate_matrix(%GateOperation{name: :ry, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(dr_y_matrix(Map.fetch!(params, :theta)), wire, qubits)

  defp d_gate_matrix(%GateOperation{name: :rz, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(dr_z_matrix(Map.fetch!(params, :theta)), wire, qubits)

  defp d_gate_matrix(%GateOperation{name: name}, _qubits) when name in [:h, :x, :y, :z, :cnot] do
    Nx.tensor([[0.0]], type: {:c, 64})
  end

  defp d_gate_matrix(%GateOperation{name: name}, _qubits) do
    raise Error.new(:unsupported_gradient_mode, %{operation: name, mode: :adjoint})
  end

  defp initial_state(qubits) do
    size = trunc(:math.pow(2, qubits))
    Nx.tensor([1.0 | List.duplicate(0.0, size - 1)], type: {:c, 64})
  end

  defp full_single_wire_matrix(single_gate, wire, qubits) do
    Enum.reduce((qubits - 1)..0//-1, nil, fn q, acc ->
      next = if q == wire, do: single_gate, else: i2()
      if acc == nil, do: next, else: kron_2d(acc, next)
    end)
  end

  defp cnot_matrix(control, target, qubits) do
    size = trunc(:math.pow(2, qubits))

    rows =
      for row <- 0..(size - 1) do
        for col <- 0..(size - 1) do
          mapped_col = map_cnot_column(col, control, target)
          matrix_value(row, mapped_col)
        end
      end

    Nx.tensor(rows, type: {:c, 64})
  end

  defp hadamard do
    norm = 1.0 / :math.sqrt(2.0)
    Nx.tensor([[norm, norm], [norm, -norm]], type: {:c, 64})
  end

  defp pauli_x, do: Nx.tensor([[0.0, 1.0], [1.0, 0.0]], type: {:c, 64})
  defp pauli_z, do: Nx.tensor([[1.0, 0.0], [0.0, -1.0]], type: {:c, 64})

  defp pauli_y do
    Nx.complex(
      Nx.tensor([[0.0, 0.0], [0.0, 0.0]]),
      Nx.tensor([[0.0, -1.0], [1.0, 0.0]])
    )
  end

  defp rx_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    c = Nx.cos(half)
    s = Nx.sin(half)
    diag = Nx.complex(c, Nx.tensor(0.0))
    off = Nx.complex(Nx.tensor(0.0), Nx.negate(s))
    Nx.stack([Nx.stack([diag, off]), Nx.stack([off, diag])])
  end

  defp ry_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    c = Nx.cos(half)
    s = Nx.sin(half)

    Nx.complex(
      Nx.stack([Nx.stack([c, Nx.negate(s)]), Nx.stack([s, c])]),
      Nx.tensor(0.0)
    )
  end

  defp rz_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    c = Nx.cos(half)
    s = Nx.sin(half)
    p0 = Nx.complex(c, Nx.negate(s))
    p1 = Nx.complex(c, s)
    zero = Nx.complex(Nx.tensor(0.0), Nx.tensor(0.0))
    Nx.stack([Nx.stack([p0, zero]), Nx.stack([zero, p1])])
  end

  defp dr_x_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    ds = Nx.multiply(-0.5, Nx.sin(half))
    dc = Nx.multiply(-0.5, Nx.cos(half))
    diag = Nx.complex(ds, Nx.tensor(0.0))
    off = Nx.complex(Nx.tensor(0.0), dc)
    Nx.stack([Nx.stack([diag, off]), Nx.stack([off, diag])])
  end

  defp dr_y_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    ds = Nx.multiply(-0.5, Nx.sin(half))
    dc = Nx.multiply(0.5, Nx.cos(half))
    zero = Nx.tensor(0.0)

    Nx.complex(
      Nx.stack([
        Nx.stack([ds, Nx.negate(dc)]),
        Nx.stack([dc, ds])
      ]),
      zero
    )
  end

  defp dr_z_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    ds = Nx.multiply(-0.5, Nx.sin(half))
    dc = Nx.multiply(0.5, Nx.cos(half))

    p0 = Nx.complex(ds, Nx.negate(dc))
    p1 = Nx.complex(ds, dc)
    zero = Nx.complex(Nx.tensor(0.0), Nx.tensor(0.0))
    Nx.stack([Nx.stack([p0, zero]), Nx.stack([zero, p1])])
  end

  defp scalar_tensor(%Nx.Tensor{} = theta), do: theta
  defp scalar_tensor(theta) when is_number(theta), do: Nx.tensor(theta)

  defp i2, do: Nx.tensor([[1.0, 0.0], [0.0, 1.0]], type: {:c, 64})

  defp map_cnot_column(col, control, target) do
    if (col >>> control &&& 1) == 1, do: bxor(col, 1 <<< target), else: col
  end

  defp matrix_value(row, mapped_col), do: if(row == mapped_col, do: 1.0, else: 0.0)

  defp kron_2d(a, b) do
    {ar, ac} = Nx.shape(a)
    {br, bc} = Nx.shape(b)

    a
    |> Nx.reshape({ar, ac, 1, 1})
    |> Nx.multiply(Nx.reshape(b, {1, 1, br, bc}))
    |> Nx.reshape({ar * br, ac * bc})
  end

  defp to_tensor(values, shape) do
    values
    |> Nx.tensor(type: {:f, 64})
    |> Nx.reshape(shape)
  end
end
