defmodule NxQuantum.Mitigation.Passes.ZneLinear do
  @moduledoc false

  alias NxQuantum.Estimator.Result, as: EstimatorResult
  alias NxQuantum.Mitigation.Trace
  alias NxQuantum.Sampler.Result, as: SamplerResult

  @spec apply(EstimatorResult.t() | SamplerResult.t(), keyword()) ::
          {:ok, EstimatorResult.t() | SamplerResult.t()} | {:error, map()}
  def apply(%EstimatorResult{} = result, opts) do
    append_scales_trace(result, opts)
  end

  def apply(%SamplerResult{} = result, opts) do
    append_scales_trace(result, opts)
  end

  def apply(_result, opts) do
    scales = Keyword.get(opts, :scales, [1.0, 2.0, 3.0])
    {:error, %{code: :invalid_mitigation_input, reason: :invalid_scales, scales: scales}}
  end

  defp append_scales_trace(result, opts) do
    scales = Keyword.get(opts, :scales, [1.0, 2.0, 3.0])

    if valid_scales?(scales) do
      {:ok, %{result | metadata: Trace.append(result.metadata, %{pass: :zne_linear, scales: scales})}}
    else
      {:error, %{code: :invalid_mitigation_input, reason: :invalid_scales, scales: scales}}
    end
  end

  defp valid_scales?(scales) when is_list(scales) and length(scales) >= 2 do
    Enum.all?(scales, &is_number/1)
  end

  defp valid_scales?(_), do: false
end
