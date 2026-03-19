defmodule NxQuantum.Adapters.Simulators.StateVector.Matrices do
  @moduledoc false

  import Bitwise

  alias NxQuantum.GateOperation

  @spec observable_matrix(
          :pauli_x | :pauli_y | :pauli_z,
          non_neg_integer(),
          pos_integer()
        ) :: Nx.Tensor.t()
  def observable_matrix(:pauli_z, wire, qubits), do: full_single_wire_matrix(pauli_z(), wire, qubits)
  def observable_matrix(:pauli_x, wire, qubits), do: full_single_wire_matrix(pauli_x(), wire, qubits)
  def observable_matrix(:pauli_y, wire, qubits), do: full_single_wire_matrix(pauli_y(), wire, qubits)

  @spec gate_matrix(GateOperation.t(), pos_integer()) :: Nx.Tensor.t()
  def gate_matrix(%GateOperation{name: :h, wires: [wire]}, qubits), do: full_single_wire_matrix(hadamard(), wire, qubits)

  def gate_matrix(%GateOperation{name: :x, wires: [wire]}, qubits), do: full_single_wire_matrix(pauli_x(), wire, qubits)

  def gate_matrix(%GateOperation{name: :y, wires: [wire]}, qubits), do: full_single_wire_matrix(pauli_y(), wire, qubits)

  def gate_matrix(%GateOperation{name: :z, wires: [wire]}, qubits), do: full_single_wire_matrix(pauli_z(), wire, qubits)

  def gate_matrix(%GateOperation{name: :rx, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(rx_matrix(Map.fetch!(params, :theta)), wire, qubits)

  def gate_matrix(%GateOperation{name: :ry, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(ry_matrix(Map.fetch!(params, :theta)), wire, qubits)

  def gate_matrix(%GateOperation{name: :rz, wires: [wire], params: params}, qubits),
    do: full_single_wire_matrix(rz_matrix(Map.fetch!(params, :theta)), wire, qubits)

  def gate_matrix(%GateOperation{name: :cnot, wires: [control, target]}, qubits), do: cnot_matrix(control, target, qubits)

  def gate_matrix(%GateOperation{name: name}, _qubits) do
    raise ArgumentError, "unsupported gate #{inspect(name)}"
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

  defp pauli_y do
    Nx.complex(
      Nx.tensor([[0.0, 0.0], [0.0, 0.0]]),
      Nx.tensor([[0.0, -1.0], [1.0, 0.0]])
    )
  end

  defp pauli_z, do: Nx.tensor([[1.0, 0.0], [0.0, -1.0]], type: {:c, 64})

  defp rx_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    c = Nx.cos(half)
    s = Nx.sin(half)

    diag = Nx.complex(c, Nx.tensor(0.0))
    off = Nx.complex(Nx.tensor(0.0), Nx.negate(s))

    Nx.stack([
      Nx.stack([diag, off]),
      Nx.stack([off, diag])
    ])
  end

  defp ry_matrix(theta) do
    t = scalar_tensor(theta)
    half = Nx.divide(t, 2.0)
    c = Nx.cos(half)
    s = Nx.sin(half)

    Nx.complex(
      Nx.stack([
        Nx.stack([c, Nx.negate(s)]),
        Nx.stack([s, c])
      ]),
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

    Nx.stack([
      Nx.stack([p0, zero]),
      Nx.stack([zero, p1])
    ])
  end

  defp scalar_tensor(%Nx.Tensor{} = theta), do: theta
  defp scalar_tensor(theta) when is_number(theta), do: Nx.tensor(theta)

  defp i2, do: Nx.tensor([[1.0, 0.0], [0.0, 1.0]], type: {:c, 64})

  defp map_cnot_column(col, control, target) do
    if (col >>> control &&& 1) == 1, do: bxor(col, 1 <<< target), else: col
  end

  defp matrix_value(row, mapped_col) when row == mapped_col, do: 1.0
  defp matrix_value(_row, _mapped_col), do: 0.0

  defp kron_2d(a, b) do
    {ar, ac} = Nx.shape(a)
    {br, bc} = Nx.shape(b)

    a
    |> Nx.reshape({ar, ac, 1, 1})
    |> Nx.multiply(Nx.reshape(b, {1, 1, br, bc}))
    |> Nx.reshape({ar * br, ac * bc})
  end
end
