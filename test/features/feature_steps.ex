defmodule NxQuantum.Features.FeatureSteps do
  @moduledoc false

  alias NxQuantum.Features.Parser.Step

  @callback feature() :: String.t()
  @callback execute(Step.t(), map()) :: map()
end
