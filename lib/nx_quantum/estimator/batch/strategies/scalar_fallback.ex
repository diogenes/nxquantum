defmodule NxQuantum.Estimator.Batch.Strategies.ScalarFallback do
  @moduledoc false

  @behaviour NxQuantum.Estimator.Batch.Strategy

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator.ResultBuilder
  alias NxQuantum.Estimator.RuntimeProfile
  alias NxQuantum.Estimator.Scalar
  alias NxQuantum.Estimator.StrategyObservability

  @impl true
  @spec run(Circuit.t(), [map()], keyword()) :: {:ok, NxQuantum.Estimator.Result.t()} | {:error, map()}
  def run(circuit, observable_specs, opts) do
    with {:ok, selection} <-
           RuntimeProfile.resolve_with_context(
             opts,
             kind: :batch,
             qubits: circuit.qubits,
             observable_specs: observable_specs
           ) do
      resolved_opts = RuntimeProfile.apply_selection_metadata(opts, selection)
      scalar_opts = Keyword.put(resolved_opts, :runtime_profile, selection.selected_profile)
      results = scalar_results(observable_specs, circuit, scalar_opts)
      resolved_opts = StrategyObservability.apply(resolved_opts, selection, observable_specs)

      to_batch_result(results, observable_specs, resolved_opts)
    end
  end

  defp scalar_results(observable_specs, circuit, opts) do
    Enum.map(observable_specs, fn %{observable: observable, wire: wire} ->
      Scalar.run(circuit, Keyword.merge(opts, observable: observable, wire: wire))
    end)
  end

  defp to_batch_result(results, observable_specs, opts) do
    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, metadata} ->
        {:error, metadata}

      nil ->
        values =
          results
          |> Enum.map(fn {:ok, tensor} -> Nx.to_number(tensor) end)
          |> Nx.tensor(type: {:f, 32})

        {:ok, ResultBuilder.build(values, observable_specs, opts)}
    end
  end
end
