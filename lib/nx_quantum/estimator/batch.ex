defmodule NxQuantum.Estimator.Batch do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator.Result
  alias NxQuantum.Estimator.Scalar

  @spec run(Circuit.t(), [map()], keyword()) :: {:ok, Result.t()} | {:error, map()}
  def run(circuit, observable_specs, opts) do
    results =
      Enum.map(observable_specs, fn %{observable: observable, wire: wire} ->
        Scalar.run(circuit, Keyword.merge(opts, observable: observable, wire: wire))
      end)

    case Enum.find(results, &match?({:error, _}, &1)) do
      {:error, metadata} ->
        {:error, metadata}

      nil ->
        values =
          results
          |> Enum.map(fn {:ok, tensor} -> Nx.to_number(tensor) end)
          |> Nx.tensor(type: {:f, 32})

        {:ok, build_result(values, observable_specs, opts)}
    end
  end

  defp build_result(values, observable_specs, opts) do
    %Result{
      values: values,
      metadata: %{
        mode: :estimator,
        observables: observable_specs,
        runtime_profile: Keyword.get(opts, :runtime_profile, :cpu_portable),
        shots: Keyword.get(opts, :shots),
        seed: Keyword.get(opts, :seed)
      }
    }
  end
end
