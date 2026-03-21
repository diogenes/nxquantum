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
    with {:ok, config} <- Options.normalize(opts) do
      run_with_config(circuit, config)
    end
  end

  @spec batched_run((Nx.Tensor.t() -> Circuit.t()), Nx.Tensor.t(), keyword()) ::
          {:ok, [Result.t()]} | {:error, map()}
  def batched_run(circuit_builder, %Nx.Tensor{} = params_batch, opts \\ []) when is_function(circuit_builder, 1) do
    shape = Nx.shape(params_batch)

    if tuple_size(shape) == 1 do
      with {:ok, config} <- Options.normalize(opts) do
        estimator_opts = Options.estimator_opts(config)
        values = Nx.to_flat_list(params_batch)

        results =
          if Keyword.get(opts, :parallel, false) do
            max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

            values
            |> Task.async_stream(
              fn value ->
                value
                |> Nx.tensor()
                |> circuit_builder.()
                |> run_with_config(config, estimator_opts)
              end,
              max_concurrency: max_concurrency,
              ordered: true,
              timeout: :infinity
            )
            |> Enum.map(fn
              {:ok, result} -> result
              {:exit, reason} -> {:error, %{code: :batch_parallel_worker_crash, reason: reason}}
            end)
          else
            Enum.map(values, fn value ->
              value
              |> Nx.tensor()
              |> circuit_builder.()
              |> run_with_config(config, estimator_opts)
            end)
          end

        case Enum.find(results, &match?({:error, _}, &1)) do
          {:error, metadata} -> {:error, metadata}
          nil -> {:ok, Enum.map(results, fn {:ok, result} -> result end)}
        end
      end
    else
      {:error, %{code: :invalid_batch_shape, expected: {:batch}, received: shape}}
    end
  end

  defp run_with_config(%Circuit{} = circuit, config, estimator_opts \\ nil) do
    estimator_opts = estimator_opts || Options.estimator_opts(config)

    with {:ok, expectation} <- Estimator.expectation_result(circuit, estimator_opts) do
      value = Nx.to_number(expectation)
      {zero_count, one_count} = Engine.sample_counts(value, config.shots, config.seed)
      {:ok, ResultBuilder.build(config, zero_count, one_count)}
    end
  end
end
