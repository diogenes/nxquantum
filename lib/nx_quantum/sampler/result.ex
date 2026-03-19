defmodule NxQuantum.Sampler.Result do
  @moduledoc """
  Typed Sampler primitive result.
  """

  @enforce_keys [:probabilities, :counts, :metadata]
  defstruct [:probabilities, :counts, :metadata]

  @type t :: %__MODULE__{
          probabilities: Nx.Tensor.t(),
          counts: %{String.t() => non_neg_integer()},
          metadata: map()
        }
end
