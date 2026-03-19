defmodule NxQuantum.Estimator.Result do
  @moduledoc """
  Typed Estimator primitive result.
  """

  @enforce_keys [:values, :metadata]
  defstruct [:values, :metadata]

  @type t :: %__MODULE__{
          values: Nx.Tensor.t(),
          metadata: map()
        }
end
