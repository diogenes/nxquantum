defmodule NxQuantum.Features.Steps.DynamicExecutionHardwareBridgesSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Adapters.Providers.InMemory
  alias NxQuantum.DynamicIR
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Mitigation.CalibrationPayload
  alias NxQuantum.ProviderBridge
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "dynamic_execution_hardware_bridges.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2, &handle_errors/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "dynamic execution mode is enabled for the supported v0.4 subset" ->
        {:handled, Map.put(ctx, :dynamic_mode, :supported_v0_4_subset)}

      text =~ ~r/^runtime profile / ->
        {:handled, Map.put(ctx, :runtime_profile, Helpers.parse_quoted(text))}

      text == "a dynamic IR graph with one measurement and one conditional gate branch" ->
        {:handled, Map.put(ctx, :ir, build_dynamic_ir(:supported))}

      text == "a dynamic IR graph containing an unsupported dynamic node type" ->
        {:handled, Map.put(ctx, :ir, build_dynamic_ir(:unsupported))}

      text == "a provider adapter implementing submit, poll, cancel, and fetch_result" ->
        {:handled, ctx |> Map.put(:provider_adapter, InMemory) |> Map.put(:job_payload, %{circuit_id: "c1", shots: 1024})}

      text == "a provider adapter experiences a transport timeout during poll" ->
        {:handled,
         ctx
         |> Map.put(:provider_adapter, InMemory)
         |> Map.put(:simulate_timeout, true)
         |> Map.put(:submit_result, {:ok, submitted_timeout_job()})}

      text == "a provider readout calibration payload with valid schema" ->
        {:handled, Map.put(ctx, :calibration_payload, build_calibration_payload(:valid))}

      text == "a provider readout calibration payload with invalid shape" ->
        {:handled, Map.put(ctx, :calibration_payload, build_calibration_payload(:invalid_shape))}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I execute the dynamic circuit twice with the same seed and inputs" ->
        mode = Map.get(ctx, :dynamic_mode, :supported_v0_4_subset)
        a = DynamicIR.execute(ctx.ir, mode: mode, seed: 77)
        b = DynamicIR.execute(ctx.ir, mode: mode, seed: 77)
        {:handled, ctx |> Map.put(:dynamic_a, a) |> Map.put(:dynamic_b, b)}

      text == "I execute the dynamic circuit" ->
        mode = Map.get(ctx, :dynamic_mode, :supported_v0_4_subset)
        {:handled, Map.put(ctx, :dynamic_result, DynamicIR.execute(ctx.ir, mode: mode, seed: 77))}

      text == "I submit a circuit execution job" ->
        {:handled, submit_and_collect_job_lifecycle(ctx)}

      text == "I poll job status" ->
        assert {:ok, submitted} = ctx.submit_result

        result =
          ProviderBridge.poll_job(
            ctx.provider_adapter,
            submitted,
            simulate_timeout: Map.get(ctx, :simulate_timeout, false)
          )

        {:handled, Map.put(ctx, :poll_result, result)}

      text == "I execute mitigation-aware hardware workflow" ->
        result = CalibrationPayload.validate(ctx.calibration_payload)
        {:handled, Map.put(ctx, :calibration_result, result)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "both outputs are identical within tolerance" ->
        assert {:ok, a} = ctx.dynamic_a
        assert {:ok, b} = ctx.dynamic_b
        assert a == b
        {:handled, ctx}

      text == "execution metadata includes branch decisions and register trace" ->
        assert {:ok, %{metadata: metadata}} = ctx.dynamic_a
        assert is_list(metadata.branch_decisions)
        assert is_list(metadata.register_trace)
        assert metadata.branch_decisions != []
        {:handled, ctx}

      text == "the initial state is \"submitted\"" ->
        assert {:ok, %{state: :submitted}} = ctx.submit_result
        {:handled, ctx}

      text == "polling transitions through typed lifecycle states deterministically" ->
        assert {:ok, %{state: :completed}} = ctx.poll_result

        {:handled, ctx}

      text == "final result retrieval returns a typed payload contract" ->
        assert {:ok, %{state: :completed, payload: payload}} = ctx.fetch_result
        assert is_map(payload)
        {:handled, ctx}

      text == "calibration payload is accepted" ->
        assert {:ok, _payload} = ctx.calibration_result
        {:handled, ctx}

      text == "mitigation metadata includes calibration version and source" ->
        assert {:ok, payload} = ctx.calibration_result
        metadata = CalibrationPayload.metadata(payload)
        assert metadata.calibration_version == "v1"
        assert metadata.calibration_source == "provider"
        {:handled, ctx}

      text == "error metadata includes the unsupported node type" ->
        assert {:error, %{node_type: _}} = ctx.dynamic_result
        {:handled, ctx}

      text == "error metadata includes operation \"poll\" and provider identifier" ->
        assert {:error, %{operation: :poll, provider: _}} = ctx.poll_result
        {:handled, ctx}

      text == "error metadata includes expected and received calibration shapes" ->
        assert {:error, %{expected_shape: _, received_shape: _}} = ctx.calibration_result
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_errors(%{text: text}, ctx) do
    if text =~ ~r/^error / and text =~ ~r/ is returned$/ do
      code = text |> Helpers.parse_quoted() |> String.to_atom()
      candidate = Map.get(ctx, :dynamic_result) || Map.get(ctx, :poll_result) || Map.get(ctx, :calibration_result)
      assert {:error, %{code: ^code}} = candidate
      {:handled, ctx}
    else
      :unhandled
    end
  end

  defp build_dynamic_ir(:supported) do
    %{
      nodes: [%{type: :measure, register: "c0", value: 1}, %{type: :conditional_gate, register: "c0", gate: :x}],
      registers: MapSet.new(["c0"])
    }
  end

  defp build_dynamic_ir(:unsupported) do
    %{nodes: [%{type: :measure, register: "c0"}, %{type: :phase_kickback}], registers: MapSet.new(["c0"])}
  end

  defp build_calibration_payload(:valid) do
    %{matrix: Nx.tensor([[0.95, 0.05], [0.06, 0.94]], type: {:f, 32}), version: "v1", source: "provider"}
  end

  defp build_calibration_payload(:invalid_shape) do
    %{matrix: Nx.tensor([1.0, 0.0], type: {:f, 32}), version: "v1", source: "provider"}
  end

  defp submitted_timeout_job do
    %{id: "job_timeout", state: :submitted, payload: %{circuit_id: "c1"}, simulate_timeout: true}
  end

  defp submit_and_collect_job_lifecycle(ctx) do
    submit_result =
      ProviderBridge.submit_job(ctx.provider_adapter, ctx.job_payload,
        simulate_timeout: Map.get(ctx, :simulate_timeout, false)
      )

    {poll_result, fetch_result} = poll_and_fetch(ctx, submit_result)

    ctx
    |> Map.put(:submit_result, submit_result)
    |> Map.put(:poll_result, poll_result)
    |> Map.put(:fetch_result, fetch_result)
  end

  defp poll_and_fetch(_ctx, {:error, _}), do: {nil, nil}

  defp poll_and_fetch(ctx, {:ok, submitted}) do
    poll_result = ProviderBridge.poll_job(ctx.provider_adapter, submitted)

    fetch_result =
      case poll_result do
        {:ok, polled} -> ProviderBridge.fetch_result(ctx.provider_adapter, polled)
        _ -> nil
      end

    {poll_result, fetch_result}
  end
end
