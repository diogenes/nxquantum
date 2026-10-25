defmodule NxQuantum.TestSupport.DenseReference do
  @moduledoc """
  Independent dense unitary reference for circuits of up to 6 qubits.

  This module does not reuse the production matrix library. Every gate is written
  from its textbook definition, so a bug shared with production code cannot make
  the two agree. Wire 0 is the most significant bit of the basis index.

  Supported gates: h, x, y, z, rx, ry, rz (theta in `params`), cnot, swap.
  """

  import Bitwise

  alias NxQuantum.GateOperation

  @max_qubits 6

  @doc "Dense unitary (dim x dim, complex128) for `operations` on `qubits` wires."
  @spec unitary(pos_integer(), [GateOperation.t()]) :: Nx.Tensor.t()
  def unitary(qubits, operations) when qubits >= 1 and qubits <= @max_qubits do
    dim = bsl(1, qubits)
    identity = Nx.eye(dim, type: {:c, 128})

    Enum.reduce(operations, identity, fn op, acc -> apply_operation(op, qubits, acc) end)
  end

  @doc """
  Maximum entrywise distance between `actual` and `expected` after removing
  the global phase. Zero for unitaries that differ only by a phase.
  """
  @spec distance_up_to_phase(Nx.Tensor.t(), Nx.Tensor.t()) :: float()
  def distance_up_to_phase(actual, expected) do
    overlap = Nx.sum(Nx.multiply(Nx.conjugate(expected), actual))
    magnitude = overlap |> Nx.abs() |> Nx.to_number()
    phase = Nx.divide(overlap, magnitude)

    actual
    |> Nx.subtract(Nx.multiply(expected, phase))
    |> Nx.abs()
    |> Nx.reduce_max()
    |> Nx.to_number()
  end

  @doc """
  Reorders the rows of `unitary` for a final logical -> physical `layout`.

  Routing keeps the logical state on physical wires; this maps the logical
  unitary onto the physical basis so it can be compared with a routed circuit.
  """
  @spec permute_rows(Nx.Tensor.t(), pos_integer(), %{non_neg_integer() => non_neg_integer()}) ::
          Nx.Tensor.t()
  def permute_rows(unitary, qubits, layout) do
    logical_rows =
      Enum.map(0..(bsl(1, qubits) - 1), fn physical_index ->
        Enum.reduce(0..(qubits - 1), 0, fn logical, acc ->
          bit = physical_bit(physical_index, qubits, layout[logical])
          acc + bsl(bit, qubits - 1 - logical)
        end)
      end)

    Nx.take(unitary, Nx.tensor(logical_rows, type: {:s, 64}), axis: 0)
  end

  defp physical_bit(index, qubits, wire), do: index |> bsr(qubits - 1 - wire) |> band(1)

  defp apply_operation(%GateOperation{name: name, wires: [wire]} = op, qubits, acc)
       when name in [:h, :x, :y, :z, :rx, :ry, :rz] do
    apply_single(gate_matrix(op), wire, qubits, acc)
  end

  defp apply_operation(%GateOperation{name: :cnot, wires: [control, target]}, qubits, acc) do
    permute(acc, qubits, fn index ->
      if physical_bit(index, qubits, control) == 1,
        do: bxor(index, bsl(1, qubits - 1 - target)),
        else: index
    end)
  end

  defp apply_operation(%GateOperation{name: :swap, wires: [a, b]}, qubits, acc) do
    permute(acc, qubits, fn index ->
      bit_a = physical_bit(index, qubits, a)
      bit_b = physical_bit(index, qubits, b)

      if bit_a == bit_b,
        do: index,
        else: bxor(index, bsl(1, qubits - 1 - a) ||| bsl(1, qubits - 1 - b))
    end)
  end

  defp apply_single(matrix, wire, qubits, acc) do
    dim = bsl(1, qubits)
    left = bsl(1, wire)
    right = bsl(1, qubits - 1 - wire)

    # Rows are (left, bit, right); contract the bit axis with the gate matrix.
    rows = Nx.reshape(acc, {left, 2, right, dim})
    contracted = Nx.dot(matrix, [1], rows, [1])

    contracted
    |> Nx.transpose(axes: [1, 0, 2, 3])
    |> Nx.reshape({dim, dim})
  end

  # Permutation gates move amplitude without mixing: output row `index` takes
  # the input row `source.(index)`. Both CNOT and SWAP are involutions, so the
  # pre-image and the image coincide.
  defp permute(acc, qubits, source) do
    dim = bsl(1, qubits)
    indices = Enum.map(0..(dim - 1), source)
    Nx.take(acc, Nx.tensor(indices, type: {:s, 64}), axis: 0)
  end

  defp gate_matrix(%GateOperation{name: :h}) do
    s = 1.0 / :math.sqrt(2.0)
    matrix({s, 0.0}, {s, 0.0}, {s, 0.0}, {-s, 0.0})
  end

  defp gate_matrix(%GateOperation{name: :x}), do: matrix({0.0, 0.0}, {1.0, 0.0}, {1.0, 0.0}, {0.0, 0.0})
  defp gate_matrix(%GateOperation{name: :y}), do: matrix({0.0, 0.0}, {0.0, -1.0}, {0.0, 1.0}, {0.0, 0.0})
  defp gate_matrix(%GateOperation{name: :z}), do: matrix({1.0, 0.0}, {0.0, 0.0}, {0.0, 0.0}, {-1.0, 0.0})

  defp gate_matrix(%GateOperation{name: :rx, params: params}) do
    half = theta(params) / 2.0
    c = :math.cos(half)
    s = :math.sin(half)
    matrix({c, 0.0}, {0.0, -s}, {0.0, -s}, {c, 0.0})
  end

  defp gate_matrix(%GateOperation{name: :ry, params: params}) do
    half = theta(params) / 2.0
    c = :math.cos(half)
    s = :math.sin(half)
    matrix({c, 0.0}, {-s, 0.0}, {s, 0.0}, {c, 0.0})
  end

  defp gate_matrix(%GateOperation{name: :rz, params: params}) do
    half = theta(params) / 2.0
    matrix({:math.cos(-half), :math.sin(-half)}, {0.0, 0.0}, {0.0, 0.0}, {:math.cos(half), :math.sin(half)})
  end

  defp theta(params) do
    case Map.get(params, :theta, 0.0) do
      %Nx.Tensor{} = tensor -> Nx.to_number(tensor)
      value -> value
    end
  end

  defp matrix({ar, ai}, {br, bi}, {cr, ci}, {dr, di}) do
    re = Nx.tensor([[ar, br], [cr, dr]], type: {:f, 64})
    im = Nx.tensor([[ai, bi], [ci, di]], type: {:f, 64})
    Nx.complex(re, im)
  end
end
