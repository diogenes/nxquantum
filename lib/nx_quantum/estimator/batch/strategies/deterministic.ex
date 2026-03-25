defmodule NxQuantum.Estimator.Batch.Strategies.Deterministic do
  @moduledoc false

  @behaviour NxQuantum.Estimator.Batch.Strategy

  alias NxQuantum.Application.ExecuteCircuit
  alias NxQuantum.Circuit
  alias NxQuantum.Estimator.ResultBuilder
  alias NxQuantum.Estimator.RuntimeProfile
  alias NxQuantum.Estimator.StrategyObservability

  @impl true
  @spec run(Circuit.t(), [map()], keyword()) :: {:ok, NxQuantum.Estimator.Result.t()} | {:error, map()}
  def run(circuit, [], opts) do
    with {:ok, selection} <-
           RuntimeProfile.resolve_with_context(
             opts,
             kind: :batch,
             qubits: circuit.qubits,
             observable_specs: []
           ) do
      result_opts = RuntimeProfile.apply_selection_metadata(opts, selection)
      result_opts = StrategyObservability.apply(result_opts, selection, [], executed?: false)
      {:ok, ResultBuilder.build(Nx.tensor([], type: {:f, 32}), [], result_opts)}
    end
  end

  def run(circuit, observable_specs, opts) do
    measured_circuit = %{circuit | measurement: hd(observable_specs)}

    with {:ok, selection} <-
           RuntimeProfile.resolve_with_context(
             opts,
             kind: :batch,
             qubits: circuit.qubits,
             observable_specs: observable_specs
           ) do
      result_opts = RuntimeProfile.apply_selection_metadata(opts, selection)

      values =
        measured_circuit
        |> ExecuteCircuit.expectations(observable_specs, [runtime_profile: selection.profile] ++ result_opts)
        |> Nx.as_type({:f, 32})

      result_opts = StrategyObservability.apply(result_opts, selection, observable_specs)
      {:ok, ResultBuilder.build(values, observable_specs, result_opts)}
    end
  end
end
