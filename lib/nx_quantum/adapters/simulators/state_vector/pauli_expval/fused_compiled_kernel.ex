defmodule NxQuantum.Adapters.Simulators.StateVector.PauliExpval.FusedCompiledKernel do
  @moduledoc false

  import Nx.Defn

  @spec evaluate(
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          Nx.Tensor.t(),
          Nx.Tensor.t()
        ) :: {Nx.Tensor.t(), Nx.Tensor.t(), Nx.Tensor.t()}
  def evaluate(%Nx.Tensor{} = state, %Nx.Tensor{} = selector, %Nx.Tensor{} = signs, %Nx.Tensor{} = flipped_indices) do
    evaluate_kernel(state, selector, signs, flipped_indices)
  end

  defn evaluate_kernel(state, selector, signs, flipped_indices) do
    {wire_count, dim} = Nx.shape(selector)

    state_rows =
      state
      |> Nx.reshape({1, dim})
      |> Nx.broadcast({wire_count, dim})

    flipped = Nx.take(state, flipped_indices)
    overlap = Nx.multiply(Nx.conjugate(state_rows), flipped)

    probabilities =
      state
      |> Nx.multiply(Nx.conjugate(state))
      |> Nx.real()

    probability_rows =
      probabilities
      |> Nx.reshape({1, dim})
      |> Nx.broadcast({wire_count, dim})

    x =
      overlap
      |> Nx.real()
      |> Nx.multiply(selector)
      |> Nx.sum(axes: [1])
      |> Nx.multiply(2.0)

    y =
      overlap
      |> Nx.imag()
      |> Nx.multiply(selector)
      |> Nx.sum(axes: [1])
      |> Nx.multiply(2.0)

    z =
      probability_rows
      |> Nx.multiply(signs)
      |> Nx.sum(axes: [1])

    {x, y, z}
  end
end
