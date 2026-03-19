defmodule NxQuantum.Mitigation.Passes.Readout do
  @moduledoc false

  alias NxQuantum.Estimator.Result, as: EstimatorResult
  alias NxQuantum.Mitigation.Trace
  alias NxQuantum.Sampler.Result, as: SamplerResult

  @spec apply(EstimatorResult.t() | SamplerResult.t(), keyword()) ::
          {:ok, EstimatorResult.t() | SamplerResult.t()} | {:error, map()}
  def apply(%SamplerResult{} = result, opts) do
    calibration = Keyword.get(opts, :calibration)

    with {:ok, matrix} <- normalize_calibration(calibration),
         {:ok, corrected} <- apply_readout_matrix(result.probabilities, matrix) do
      shots = Map.get(result.metadata, :shots, 0)
      [p0, _p1] = Nx.to_flat_list(corrected)
      zero_count = round(p0 * shots)
      one_count = max(shots - zero_count, 0)

      {:ok,
       %{
         result
         | probabilities: corrected,
           counts: %{"0" => zero_count, "1" => one_count},
           metadata: Trace.append(result.metadata, %{pass: :readout})
       }}
    end
  end

  def apply(%EstimatorResult{} = _result, _opts) do
    {:error, %{code: :invalid_mitigation_input, reason: :readout_requires_sampler_result}}
  end

  def apply(_result, _opts) do
    {:error, %{code: :invalid_mitigation_input, reason: :readout_requires_sampler_result}}
  end

  defp normalize_calibration(%Nx.Tensor{} = matrix) do
    if Nx.shape(matrix) == {2, 2} do
      {:ok, matrix}
    else
      {:error, %{code: :invalid_mitigation_input, reason: :invalid_calibration_shape, shape: Nx.shape(matrix)}}
    end
  end

  defp normalize_calibration(_invalid) do
    {:error, %{code: :invalid_mitigation_input, reason: :missing_calibration_matrix}}
  end

  defp apply_readout_matrix(%Nx.Tensor{} = probabilities, matrix) do
    inverse = Nx.LinAlg.invert(matrix)
    corrected = Nx.dot(inverse, probabilities)
    clipped = Nx.clip(corrected, 0.0, 1.0)
    total = Nx.sum(clipped)
    normalized = Nx.divide(clipped, total)
    {:ok, normalized}
  rescue
    _ -> {:error, %{code: :invalid_mitigation_input, reason: :non_invertible_calibration}}
  end
end
