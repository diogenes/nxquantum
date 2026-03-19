defmodule NxQuantum.Features.Steps.ErrorMitigationSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Mitigation
  alias NxQuantum.Sampler
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "error_mitigation.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "primitive output tensors from Sampler or Estimator" ->
        circuit = Circuit.new(qubits: 1)
        {:ok, sample} = Sampler.run(circuit, shots: 256, seed: 9)
        {:ok, estimate} = Estimator.run(circuit, observables: [:pauli_z], wire: 0)
        {:handled, ctx |> Map.put(:sample, sample) |> Map.put(:estimate, estimate)}

      text == "mitigation pipeline API is enabled" ->
        {:handled, ctx}

      text == "a calibration matrix for readout mitigation" ->
        calibration = Nx.tensor([[0.95, 0.05], [0.04, 0.96]], type: {:f, 32})
        {:handled, Map.put(ctx, :calibration, calibration)}

      text =~ ~r/^noise scaling factors / ->
        scales = text |> Helpers.parse_quoted() |> Helpers.parse_list_of_numbers()
        {:handled, Map.put(ctx, :scales, scales)}

      text =~ ~r/^mitigation pipeline / ->
        calibration =
          Map.get(
            ctx,
            :calibration,
            Nx.tensor([[0.95, 0.05], [0.04, 0.96]], type: {:f, 32})
          )

        updated =
          ctx
          |> Map.put(:calibration, calibration)
          |> Map.put(:pipeline, [{:readout, calibration: calibration}, {:zne_linear, scales: [1.0, 2.0, 3.0]}])

        {:handled, updated}

      text == "a non-invertible or shape-mismatched calibration matrix" ->
        {:handled, Map.put(ctx, :bad_calibration, Nx.tensor([1.0, 0.0]))}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I apply readout mitigation twice to the same input" ->
        {:ok, a} = Mitigation.pipeline(ctx.sample, [{:readout, calibration: ctx.calibration}])
        {:ok, b} = Mitigation.pipeline(ctx.sample, [{:readout, calibration: ctx.calibration}])
        {:handled, ctx |> Map.put(:mit_a, a) |> Map.put(:mit_b, b)}

      text == "I apply ZNE linear extrapolation" ->
        {:ok, out} = Mitigation.pipeline(ctx.estimate, [{:zne_linear, scales: ctx.scales}])
        {:handled, Map.put(ctx, :zne_out, out)}

      text == "I execute the pipeline" ->
        {:ok, out} = Mitigation.pipeline(ctx.sample, ctx.pipeline)
        {:handled, Map.put(ctx, :pipeline_out, out)}

      text == "I apply readout mitigation" ->
        error = Mitigation.pipeline(ctx.sample, [{:readout, calibration: ctx.bad_calibration}])
        {:handled, Map.put(ctx, :error_result, error)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "both mitigated outputs are identical" ->
        assert Nx.to_flat_list(ctx.mit_a.probabilities) == Nx.to_flat_list(ctx.mit_b.probabilities)
        {:handled, ctx}

      text == "output probability mass remains normalized within tolerance" ->
        total = ctx.mit_a.probabilities |> Nx.sum() |> Nx.to_number()
        assert_in_delta total, 1.0, 1.0e-5
        {:handled, ctx}

      text == "corrected expectation is deterministic for fixed seed and inputs" ->
        {:ok, out2} = Mitigation.pipeline(ctx.estimate, [{:zne_linear, scales: ctx.scales}])
        assert ctx.zne_out.metadata == out2.metadata
        {:handled, ctx}

      text == "extrapolation metadata includes scale factors and fit diagnostics" ->
        trace = List.last(ctx.zne_out.metadata.mitigation_trace)
        assert trace.scales == ctx.scales
        {:handled, ctx}

      text == "pass execution order matches the declared pipeline order" ->
        names = Enum.map(ctx.pipeline_out.metadata.mitigation_trace, & &1.pass)
        assert names == [:readout, :zne_linear]
        {:handled, ctx}

      text == "output includes per-pass trace metadata" ->
        assert length(ctx.pipeline_out.metadata.mitigation_trace) == 2
        {:handled, ctx}

      text == "error \"invalid_mitigation_input\" is returned" ->
        assert {:error, %{code: :invalid_mitigation_input}} = ctx.error_result
        {:handled, ctx}

      text == "error metadata includes matrix shape diagnostics" ->
        assert {:error, %{reason: _}} = ctx.error_result
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
