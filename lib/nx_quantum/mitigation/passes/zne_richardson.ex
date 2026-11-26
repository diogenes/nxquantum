defmodule NxQuantum.Mitigation.Passes.ZneRichardson do
  @moduledoc false

  alias NxQuantum.Estimator.Result, as: EstimatorResult
  alias NxQuantum.Mitigation.Extrapolation
  alias NxQuantum.Sampler.Result, as: SamplerResult

  @spec apply(EstimatorResult.t() | SamplerResult.t(), keyword()) ::
          {:ok, EstimatorResult.t() | SamplerResult.t()} | {:error, map()}
  def apply(result, opts) do
    Extrapolation.apply(result, opts, :zne_richardson, :richardson)
  end
end
