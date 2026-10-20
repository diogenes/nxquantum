defmodule NxQuantum.TestSupport.Unitary do
  @moduledoc """
  Builds the unitary of a gate sequence by applying it to every computational basis state.

  Used by compiler semantic tests. Comparisons are up to global phase, with an explicit tolerance.
  """

  alias NxQuantum.Adapters.Simulators.StateVector.State

  @doc "Returns the `{dim, dim}` complex unitary of `operations` on `qubits` qubits. Column j is the image of |j>."
  @spec of([NxQuantum.GateOperation.t()], pos_integer()) :: Nx.Tensor.t()
  def of(operations, qubits) do
    dim = Integer.pow(2, qubits)

    columns =
      for j <- 0..(dim - 1) do
        j
        |> basis_state(dim)
        |> State.apply_operations(operations)
      end

    Nx.stack(columns, axis: 1)
  end

  @doc """
  True when `b = e^{i phi} a` for some phase, within `tol`.

  For unitaries, |Tr(a^dagger b)| equals the dimension exactly when they agree up to global phase.
  """
  @spec equal_up_to_phase?(Nx.Tensor.t(), Nx.Tensor.t(), float()) :: boolean()
  def equal_up_to_phase?(a, b, tol \\ 1.0e-6) do
    dim = elem(Nx.shape(a), 0)
    overlap = a |> Nx.conjugate() |> Nx.multiply(b) |> Nx.sum() |> Nx.abs() |> Nx.to_number()
    abs(overlap - dim) <= tol * dim
  end

  defp basis_state(j, dim) do
    values = for i <- 0..(dim - 1), do: if(i == j, do: 1.0, else: 0.0)
    Nx.tensor(values, type: {:c, 64})
  end
end
