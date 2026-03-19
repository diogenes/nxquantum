defmodule NxQuantum.Mitigation do
  @moduledoc """
  Functional mitigation pipeline for primitive outputs.

  v0.3 scope:
  - deterministic pass composition,
  - baseline readout mitigation,
  - baseline ZNE metadata-aware correction path.
  """

  alias NxQuantum.Estimator.Result, as: EstimatorResult
  alias NxQuantum.Mitigation.PassPipeline
  alias NxQuantum.Sampler.Result, as: SamplerResult

  @type pass :: {:readout, keyword()} | {:zne_linear, keyword()}

  @spec pipeline(EstimatorResult.t() | SamplerResult.t(), [pass()]) ::
          {:ok, EstimatorResult.t() | SamplerResult.t()} | {:error, map()}
  def pipeline(result, passes) when is_list(passes) do
    PassPipeline.run(result, passes)
  end
end
