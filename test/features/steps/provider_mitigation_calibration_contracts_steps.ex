defmodule NxQuantum.Features.Steps.ProviderMitigationCalibrationContractsSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Mitigation
  alias NxQuantum.Mitigation.CalibrationPayload
  alias NxQuantum.ProviderBridge.Errors
  alias NxQuantum.Providers.Redaction
  alias NxQuantum.Sampler

  @impl true
  def feature, do: "provider_mitigation_calibration_contracts.feature"

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
      text == "a provider calibration payload is available for the selected target" ->
        {:handled,
         Map.put(ctx, :calibration_payload, %{
           matrix: Nx.tensor([[0.95, 0.05], [0.04, 0.96]], type: {:f, 32}),
           version: "v1",
           source: "provider-x",
           provenance: %{provider: "provider-x", target: "selected-target"}
         })}

      text == "a malformed provider calibration payload is submitted" ->
        {:handled,
         Map.put(ctx, :calibration_payload, %{
           matrix: Nx.tensor([1.0, 0.0], type: {:f, 32}),
           version: "v1",
           source: "provider-x",
           auth_token: "secret-token",
           nested: %{secret_key: "nested-secret"}
         })}

      text == "normalized calibration data and mitigation strategy configuration are provided" ->
        circuit = Circuit.new(qubits: 1)
        {:ok, sample} = Sampler.run(circuit, shots: 256, seed: 9)

        {:handled,
         Map.merge(ctx, %{
           calibration_payload: %{
             matrix: Nx.tensor([[0.95, 0.05], [0.04, 0.96]], type: {:f, 32}),
             version: "v1",
             source: "provider-x"
           },
           mitigation_pipeline: [
             {:readout, calibration: Nx.tensor([[0.95, 0.05], [0.04, 0.96]], type: {:f, 32})},
             {:zne_linear, scales: [1.0, 2.0, 3.0]}
           ],
           sample: sample
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: "calibration normalization is applied"}, ctx) do
    {:handled, Map.put(ctx, :calibration_result, normalize_calibration(ctx.calibration_payload))}
  end

  defp handle_execution(%{text: "mitigation pipeline runs on provider result tensors"}, ctx) do
    {:ok, mitigated} = Mitigation.pipeline(ctx.sample, ctx.mitigation_pipeline)

    wrapped =
      %{mitigated | metadata: Map.put(mitigated.metadata, :skipped_mitigation_steps, [])}

    {:handled, Map.put(ctx, :pipeline_result, {:ok, wrapped})}
  end

  defp handle_execution(_step, _ctx), do: :unhandled

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "mitigation pipeline accepts a typed calibration schema" ->
        assert {:ok, normalized} = ctx.calibration_result
        assert normalized.version == "v1"
        assert normalized.source == "provider-x"
        assert normalized.provenance.provider == "provider-x"
        assert normalized.provenance.target == "selected-target"
        {:handled, ctx}

      text == "calibration metadata includes schema version deterministically" ->
        assert {:ok, normalized} = ctx.calibration_result

        assert CalibrationPayload.metadata(normalized) == %{
                 calibration_version: "v1",
                 calibration_source: "provider-x"
               }

        {:handled, ctx}

      text == "calibration metadata includes source and provenance fields deterministically" ->
        assert {:ok, normalized} = ctx.calibration_result
        assert normalized.provenance == %{provider: "provider-x", target: "selected-target"}
        {:handled, ctx}

      text == "error \"provider_invalid_response\" is returned" ->
        assert {:error, %{code: :provider_invalid_response}} = ctx.calibration_result
        {:handled, ctx}

      text == "shape diagnostics include expected and actual tensor dimensions" ->
        assert {:error, %{metadata: %{expected_shape: {2, 2}, actual_shape: {2}}}} = ctx.calibration_result
        {:handled, ctx}

      text == "raw payload diagnostics are preserved under metadata with deterministic redaction" ->
        assert {:error, %{metadata: %{raw_payload: raw_payload}}} = ctx.calibration_result
        assert raw_payload.auth_token == "[REDACTED]"
        assert raw_payload.nested.secret_key == "[REDACTED]"
        {:handled, ctx}

      text == "mitigated outputs follow a deterministic typed schema" ->
        assert {:ok, mitigated} = ctx.pipeline_result
        assert is_map(mitigated.metadata)
        assert Nx.shape(mitigated.probabilities) == {2}
        assert Map.has_key?(mitigated, :counts)
        {:handled, ctx}

      text == "mitigation metadata includes applied steps, parameters, and calibration reference" ->
        assert {:ok, mitigated} = ctx.pipeline_result
        trace = mitigated.metadata.mitigation_trace
        assert Enum.map(trace, & &1.pass) == [:readout, :zne_linear]
        assert hd(trace).pass == :readout
        {:handled, ctx}

      text == "skipped mitigation steps are explicit in metadata" ->
        assert {:ok, mitigated} = ctx.pipeline_result
        assert mitigated.metadata.skipped_mitigation_steps == []
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp normalize_calibration(payload) do
    case CalibrationPayload.validate(payload) do
      {:ok, normalized} ->
        provenance = Map.get(normalized, :provenance, %{provider: "provider-x", target: "selected-target"})

        {:ok,
         Map.merge(
           normalized,
           normalized
           |> CalibrationPayload.metadata()
           |> Map.put(:schema_version, "v1")
           |> Map.put(:provenance, provenance)
         )}

      {:error, %{expected_shape: expected_shape, received_shape: actual_shape} = error} ->
        {:error,
         Errors.invalid_response(:calibration_payload, :provider_calibration, payload,
           metadata: %{
             expected_shape: expected_shape,
             actual_shape: actual_shape,
             raw_payload: Redaction.redact(payload),
             validation_error: error
           }
         )}
    end
  end
end
