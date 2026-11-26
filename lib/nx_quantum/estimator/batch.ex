defmodule NxQuantum.Estimator.Batch do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator.Batch.Strategies.Deterministic
  alias NxQuantum.Estimator.Batch.Strategies.ScalarFallback
  alias NxQuantum.Estimator.ExecutionMode

  @spec run(Circuit.t(), [map()], keyword()) :: {:ok, NxQuantum.Estimator.Result.t()} | {:error, map()}
  def run(circuit, observable_specs, opts) do
    strategy_for(opts).run(circuit, observable_specs, opts)
  end

  defp strategy_for(opts) do
    case ExecutionMode.classify(opts) do
      :deterministic -> Deterministic
      :stochastic -> ScalarFallback
    end
  end
end
