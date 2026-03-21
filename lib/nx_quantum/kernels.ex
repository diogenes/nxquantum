defmodule NxQuantum.Kernels do
  @moduledoc """
  Quantum kernel matrix generation facade.

  v0.2 implementation notes:
  - deterministic explicit feature-map encoding,
  - optional seeded phase offsets for reproducible experiments,
  - PSD/symmetric kernel matrix by construction (`phi(x) * phi(x)^T`).
  """

  import Nx.Defn

  alias NxQuantum.Random.Seed

  @type opts :: [
          gamma: number(),
          seed: integer() | nil
        ]

  @doc """
  Builds a deterministic kernel matrix for a 2D dataset tensor.

  The feature map is:

    phi(x) = [cos(gamma * x + phase), sin(gamma * x + phase)]

  where `phase` is deterministic and can be seeded via `:seed`.
  """
  @spec matrix(Nx.Tensor.t(), keyword()) :: Nx.Tensor.t()
  def matrix(%Nx.Tensor{} = x, opts \\ []) when is_list(opts) do
    ensure_2d!(x)

    gamma = Keyword.get(opts, :gamma, 1.0)
    feature_count = x |> Nx.shape() |> elem(1)
    phase_offsets = phase_offsets(feature_count, Keyword.get(opts, :seed))
    mapped = feature_map_kernel(x, Nx.tensor(gamma), phase_offsets)
    gram = gram_kernel(mapped)

    Nx.as_type(gram, {:f, 64})
  end

  defnp feature_map_kernel(x, gamma, phase_offsets) do
    scaled = Nx.add(Nx.multiply(x, gamma), phase_offsets)
    Nx.concatenate([Nx.cos(scaled), Nx.sin(scaled)], axis: 1)
  end

  defnp gram_kernel(mapped) do
    Nx.dot(mapped, [1], Nx.transpose(mapped), [0])
  end

  defp phase_offsets(feature_count, nil), do: Nx.broadcast(Nx.tensor(0.0), {1, feature_count})

  defp phase_offsets(feature_count, seed) when is_integer(seed) do
    Seed.seed(seed, :kernels_phase)

    values =
      Enum.map(1..feature_count, fn _ ->
        :rand.uniform() * (2.0 * :math.pi())
      end)

    Nx.tensor([values], type: {:f, 64})
  end

  defp ensure_2d!(%Nx.Tensor{} = x) do
    case tuple_size(Nx.shape(x)) do
      2 -> :ok
      rank -> raise ArgumentError, "expected rank-2 tensor for kernel matrix input, got rank #{rank}"
    end
  end
end
