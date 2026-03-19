defmodule NxQuantum.Sampler do
  @moduledoc """
  Sampler primitive facade.

  v0.3 scope:
  - deterministic shot sampling contract,
  - typed sampler result object,
  - simple probability/count outputs for foundational workflows.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Sampler.Engine
  alias NxQuantum.Sampler.Options
  alias NxQuantum.Sampler.Result
  alias NxQuantum.Sampler.ResultBuilder

  @spec run(Circuit.t(), keyword()) :: {:ok, Result.t()} | {:error, map()}
  def run(%Circuit{} = circuit, opts \\ []) do
    with {:ok, config} <- Options.normalize(opts),
         {:ok, expectation} <-
           Estimator.expectation_result(circuit, Options.estimator_opts(config)) do
      value = Nx.to_number(expectation)
      {zero_count, one_count} = Engine.sample_counts(value, config.shots, config.seed)
      {:ok, ResultBuilder.build(config, zero_count, one_count)}
    end
  end
end
