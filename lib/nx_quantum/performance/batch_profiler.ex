defmodule NxQuantum.Performance.BatchProfiler do
  @moduledoc false

  alias NxQuantum.Estimator
  alias NxQuantum.Performance.Metrics
  alias NxQuantum.Performance.Model

  @spec compare((Nx.Tensor.t() -> NxQuantum.Circuit.t()), Nx.Tensor.t(), keyword()) ::
          {:ok, map()} | {:error, map()}
  def compare(circuit_builder, %Nx.Tensor{} = params_batch, opts \\ []) when is_function(circuit_builder, 1) do
    with {:ok, batched_values} <- Estimator.batched_expectation(circuit_builder, params_batch, opts),
         {:ok, scalar_values} <- scalar_values(circuit_builder, params_batch, opts) do
      batch_size = elem(Nx.shape(params_batch), 0)
      profile = Keyword.get(opts, :runtime_profile, :cpu_portable)
      metrics = deterministic_metrics(batch_size, profile)

      {:ok,
       %{
         batched_values: batched_values,
         scalar_values: scalar_values,
         metrics: metrics
       }}
    end
  end

  defp scalar_values(circuit_builder, params_batch, opts) do
    results = collect_scalar_results(circuit_builder, params_batch, opts)

    case Enum.find(results, &match?({:error, _}, &1)) do
      nil ->
        values =
          results
          |> Enum.map(fn {:ok, tensor} -> Nx.to_number(tensor) end)
          |> Nx.tensor(type: {:f, 32})

        {:ok, values}

      {:error, metadata} ->
        {:error, metadata}
    end
  end

  defp collect_scalar_results(circuit_builder, params_batch, opts) do
    params_batch
    |> Nx.to_flat_list()
    |> Enum.map(fn value ->
      value
      |> Nx.tensor()
      |> circuit_builder.()
      |> Estimator.expectation_result(opts)
    end)
  end

  defp deterministic_metrics(batch_size, profile) do
    scalar_latency_ms = Model.scalar_latency_ms(batch_size, profile)
    batched_latency_ms = Model.batched_latency_ms(batch_size, profile)

    %Metrics{
      batch_size: batch_size,
      scalar_latency_ms: scalar_latency_ms,
      batched_latency_ms: batched_latency_ms,
      scalar_throughput_ops_s: Model.throughput_ops_s(batch_size, scalar_latency_ms),
      batched_throughput_ops_s: Model.throughput_ops_s(batch_size, batched_latency_ms),
      estimated_memory_mb: Model.memory_mb(batch_size, :compare)
    }
  end
end
