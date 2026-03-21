defmodule NxQuantum.Adapters.Simulators.StateVector.MatrixLibrary do
  @moduledoc false

  import Bitwise

  alias NxQuantum.Adapters.Simulators.StateVector.Cache
  alias NxQuantum.Adapters.Simulators.StateVector.KeyEncoder
  alias NxQuantum.GateOperation

  @spec observable_matrix(:pauli_x | :pauli_y | :pauli_z, non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def observable_matrix(:pauli_z, wire, qubits),
    do: Cache.fetch({:observable, :pauli_z, wire, qubits}, fn -> full_single_wire_matrix(pauli_z(), wire, qubits) end)

  def observable_matrix(:pauli_x, wire, qubits),
    do: Cache.fetch({:observable, :pauli_x, wire, qubits}, fn -> full_single_wire_matrix(pauli_x(), wire, qubits) end)

  def observable_matrix(:pauli_y, wire, qubits),
    do: Cache.fetch({:observable, :pauli_y, wire, qubits}, fn -> full_single_wire_matrix(pauli_y(), wire, qubits) end)

  @spec pauli_z_signs(non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def pauli_z_signs(wire, qubits) do
    Cache.fetch({:observable, :pauli_z_signs, wire, qubits}, fn ->
      size = trunc(:math.pow(2, qubits))

      signs =
        for index <- 0..(size - 1) do
          if (index >>> wire &&& 1) == 1, do: -1.0, else: 1.0
        end

      Nx.tensor(signs, type: {:f, 64})
    end)
  end

  @spec gate_matrix(GateOperation.t(), pos_integer()) :: Nx.Tensor.t()
  def gate_matrix(%GateOperation{name: :h, wires: [wire]}, qubits),
    do: Cache.fetch({:gate, :h, wire, qubits}, fn -> full_single_wire_matrix(hadamard(), wire, qubits) end)

  def gate_matrix(%GateOperation{name: :x, wires: [wire]}, qubits),
    do: Cache.fetch({:gate, :x, wire, qubits}, fn -> full_single_wire_matrix(pauli_x(), wire, qubits) end)

  def gate_matrix(%GateOperation{name: :y, wires: [wire]}, qubits),
    do: Cache.fetch({:gate, :y, wire, qubits}, fn -> full_single_wire_matrix(pauli_y(), wire, qubits) end)

  def gate_matrix(%GateOperation{name: :z, wires: [wire]}, qubits),
    do: Cache.fetch({:gate, :z, wire, qubits}, fn -> full_single_wire_matrix(pauli_z(), wire, qubits) end)

  def gate_matrix(%GateOperation{name: :rx, wires: [wire], params: params}, qubits),
    do:
      Cache.fetch({:gate, :rx, wire, qubits, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        full_single_wire_matrix(rx_matrix(Map.fetch!(params, :theta)), wire, qubits)
      end)

  def gate_matrix(%GateOperation{name: :ry, wires: [wire], params: params}, qubits),
    do:
      Cache.fetch({:gate, :ry, wire, qubits, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        full_single_wire_matrix(ry_matrix(Map.fetch!(params, :theta)), wire, qubits)
      end)

  def gate_matrix(%GateOperation{name: :rz, wires: [wire], params: params}, qubits),
    do:
      Cache.fetch({:gate, :rz, wire, qubits, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        full_single_wire_matrix(rz_matrix(Map.fetch!(params, :theta)), wire, qubits)
      end)

  def gate_matrix(%GateOperation{name: :cnot, wires: [control, target]}, qubits),
    do: Cache.fetch({:gate, :cnot, control, target, qubits}, fn -> cnot_matrix(control, target, qubits) end)

  def gate_matrix(%GateOperation{name: name}, _qubits) do
    raise ArgumentError, "unsupported gate #{inspect(name)}"
  end

  @spec single_qubit_gate_matrix(GateOperation.t()) :: Nx.Tensor.t()
  def single_qubit_gate_matrix(%GateOperation{name: :h}), do: Cache.fetch({:single_gate, :h}, &hadamard/0)
  def single_qubit_gate_matrix(%GateOperation{name: :x}), do: Cache.fetch({:single_gate, :x}, &pauli_x/0)
  def single_qubit_gate_matrix(%GateOperation{name: :y}), do: Cache.fetch({:single_gate, :y}, &pauli_y/0)
  def single_qubit_gate_matrix(%GateOperation{name: :z}), do: Cache.fetch({:single_gate, :z}, &pauli_z/0)

  def single_qubit_gate_matrix(%GateOperation{name: :rx, params: params}),
    do:
      Cache.fetch({:single_gate, :rx, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        rx_matrix(Map.fetch!(params, :theta))
      end)

  def single_qubit_gate_matrix(%GateOperation{name: :ry, params: params}),
    do:
      Cache.fetch({:single_gate, :ry, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        ry_matrix(Map.fetch!(params, :theta))
      end)

  def single_qubit_gate_matrix(%GateOperation{name: :rz, params: params}),
    do:
      Cache.fetch({:single_gate, :rz, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        rz_matrix(Map.fetch!(params, :theta))
      end)

  def single_qubit_gate_matrix(%GateOperation{name: name}) do
    raise ArgumentError, "unsupported single-qubit gate #{inspect(name)}"
  end

  @type single_qubit_gate_coefficients :: %{
          g00: Nx.Tensor.t(),
          g01: Nx.Tensor.t(),
          g10: Nx.Tensor.t(),
          g11: Nx.Tensor.t()
        }

  @spec single_qubit_gate_coefficients(GateOperation.t()) :: single_qubit_gate_coefficients()
  def single_qubit_gate_coefficients(%GateOperation{name: :h}),
    do: Cache.fetch({:single_gate, :coeffs, :h}, fn -> extract_gate_coefficients(hadamard()) end)

  def single_qubit_gate_coefficients(%GateOperation{name: :x}),
    do: Cache.fetch({:single_gate, :coeffs, :x}, fn -> extract_gate_coefficients(pauli_x()) end)

  def single_qubit_gate_coefficients(%GateOperation{name: :y}),
    do: Cache.fetch({:single_gate, :coeffs, :y}, fn -> extract_gate_coefficients(pauli_y()) end)

  def single_qubit_gate_coefficients(%GateOperation{name: :z}),
    do: Cache.fetch({:single_gate, :coeffs, :z}, fn -> extract_gate_coefficients(pauli_z()) end)

  def single_qubit_gate_coefficients(%GateOperation{name: :rx, params: params}),
    do:
      Cache.fetch({:single_gate, :coeffs, :rx, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        params |> Map.fetch!(:theta) |> rx_matrix() |> extract_gate_coefficients()
      end)

  def single_qubit_gate_coefficients(%GateOperation{name: :ry, params: params}),
    do:
      Cache.fetch({:single_gate, :coeffs, :ry, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        params |> Map.fetch!(:theta) |> ry_matrix() |> extract_gate_coefficients()
      end)

  def single_qubit_gate_coefficients(%GateOperation{name: :rz, params: params}),
    do:
      Cache.fetch({:single_gate, :coeffs, :rz, KeyEncoder.theta_key(Map.fetch!(params, :theta))}, fn ->
        params |> Map.fetch!(:theta) |> rz_matrix() |> extract_gate_coefficients()
      end)

  def single_qubit_gate_coefficients(%GateOperation{name: name}) do
    raise ArgumentError, "unsupported single-qubit gate coefficients #{inspect(name)}"
  end

  @spec cnot_permutation(non_neg_integer(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def cnot_permutation(control, target, qubits) do
    Cache.fetch({:gate, :cnot, :permutation, control, target, qubits}, fn ->
      size = trunc(:math.pow(2, qubits))
      mapped = for index <- 0..(size - 1), do: map_cnot_column(index, control, target)
      Nx.tensor(mapped, type: {:s, 64})
    end)
  end

  @spec single_qubit_layout_plan(non_neg_integer(), pos_integer()) :: map()
  def single_qubit_layout_plan(wire, qubits) do
    Cache.fetch({:single_gate, :layout_plan, wire, qubits}, fn ->
      size = 1 <<< qubits
      inner_size = 1 <<< wire
      outer_size = 1 <<< (qubits - wire - 1)
      trailing_size = 1 <<< (qubits - 1)
      state_shape = {size}
      pair_shape = {outer_size, 2, inner_size}

      %{
        pair_shape: pair_shape,
        outer_size: outer_size,
        inner_size: inner_size,
        trailing_size: trailing_size,
        state_shape: state_shape
      }
    end)
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
    |> Nx.transpose(axes: [0, 2, 1, 3])
    |> Nx.reshape({ar * br, ac * bc})
  end

  defp extract_gate_coefficients(matrix) do
    %{
      g00: matrix |> Nx.slice([0, 0], [1, 1]) |> Nx.reshape({}),
      g01: matrix |> Nx.slice([0, 1], [1, 1]) |> Nx.reshape({}),
      g10: matrix |> Nx.slice([1, 0], [1, 1]) |> Nx.reshape({}),
      g11: matrix |> Nx.slice([1, 1], [1, 1]) |> Nx.reshape({})
    }
  end
end
