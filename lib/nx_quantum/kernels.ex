defmodule NxQuantum.Kernels do
  @moduledoc """
  Quantum kernel matrix generation facade.

  Current version is a planning scaffold for v0.2.
  """

  @spec matrix(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def matrix(%Nx.Tensor{} = x, opts \\ []) do
    gamma = Keyword.get(opts, :gamma, 1.0)
    {rows, cols} = Nx.shape(x)

    row_at = fn idx ->
      x
      |> Nx.slice([idx, 0], [1, cols])
      |> Nx.reshape({cols})
    end

    entries =
      for i <- 0..(rows - 1) do
        xi = row_at.(i)

        for j <- 0..(rows - 1) do
          xj = row_at.(j)

          sq_dist =
            xi
            |> Nx.subtract(xj)
            |> Nx.pow(2)
            |> Nx.sum()
            |> Nx.to_number()

          :math.exp(-gamma * sq_dist)
        end
      end

    Nx.tensor(entries, type: {:f, 64})
  end
end
