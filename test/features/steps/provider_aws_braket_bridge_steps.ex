defmodule NxQuantum.Features.Steps.ProviderAwsBraketBridgeSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Adapters.Providers.AwsBraket
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.ProviderBridge

  defmodule BrokenBraketPayloadProvider do
    @moduledoc false

    @behaviour NxQuantum.Ports.Provider

    @impl true
    def provider_id, do: :aws_braket

    @impl true
    def capabilities(_target, _opts) do
      {:ok,
       %{
         supports_estimator: false,
         supports_sampler: true,
         supports_batch: true,
         supports_dynamic: false,
         supports_cancel_in_running: true,
         supports_calibration_payload: false,
         target_class: :gate_model
       }}
    end

    @impl true
    def submit(_payload, _opts), do: :unexpected

    @impl true
    def poll(job, _opts), do: {:ok, job}

    @impl true
    def cancel(job, _opts), do: {:ok, job}

    @impl true
    def fetch_result(_job, _opts), do: {:ok, %{}}
  end

  @impl true
  def feature, do: "provider_aws_braket_bridge.feature"

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
      text == "AWS Braket provider integration is configured for a gate-model target" ->
        {:handled,
         Map.merge(ctx, %{
           provider: AwsBraket,
           payload: %{workflow: :sampler, shots: 1024},
           opts: [
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             provider_config: %{
               region: "us-east-1",
               credentials_profile: "default",
               device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
             }
           ]
         })}

      text == "selected Braket target class is unsupported for requested workflow" ->
        {:handled,
         Map.merge(ctx, %{
           provider: AwsBraket,
           payload: %{workflow: :sampler, dynamic: true},
           opts: [
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             provider_config: %{
               region: "us-east-1",
               credentials_profile: "default",
               device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
             }
           ]
         })}

      text == "Braket adapter capability profile is explicitly declared" ->
        {:handled, Map.put(ctx, :provider, AwsBraket)}

      text == "an AWS Braket task is in non-terminal state \"submitted\"" ->
        {:handled,
         Map.put(ctx, :non_terminal_job, %{
           id: "braket_task_1",
           state: :submitted,
           provider: :aws_braket,
           target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
           metadata: %{raw_state: "CREATED"}
         })}

      text == "an AWS Braket poll operation reaches a transport timeout" ->
        {:handled,
         Map.merge(ctx, %{
           timeout_job: %{
             id: "braket_task_2",
             state: :submitted,
             provider: :aws_braket,
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             metadata: %{raw_state: "CREATED"}
           },
           timeout_opts: [
             force_error: {:poll, :timeout},
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             provider_config: %{
               region: "us-east-1",
               credentials_profile: "default",
               device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
             }
           ]
         })}

      text == "AWS Braket adapter returns an unexpected payload for submit" ->
        {:handled,
         Map.merge(ctx, %{
           provider: BrokenBraketPayloadProvider,
           payload: %{workflow: :sampler},
           opts: [
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             provider_config: %{
               region: "us-east-1",
               credentials_profile: "default",
               device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
             }
           ]
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I execute submit, poll, cancel, and fetch_result operations" ->
        {:ok, submitted} = ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.opts)
        {:ok, polled} = ProviderBridge.poll_job(ctx.provider, submitted, ctx.opts)
        {:ok, cancelled} = ProviderBridge.cancel_job(ctx.provider, submitted, ctx.opts)
        {:ok, result} = ProviderBridge.fetch_result(ctx.provider, polled, ctx.opts)

        unknown_status_result =
          ProviderBridge.poll_job(ctx.provider, submitted, Keyword.put(ctx.opts, :raw_states, %{poll: "UNKNOWN_STATUS"}))

        {:handled,
         ctx
         |> Map.put(:submit_result, {:ok, submitted})
         |> Map.put(:poll_result, {:ok, polled})
         |> Map.put(:cancel_result, {:ok, cancelled})
         |> Map.put(:fetch_result, {:ok, result})
         |> Map.put(:unknown_status_result, unknown_status_result)}

      text == "I run capability preflight" ->
        {:handled, Map.put(ctx, :preflight_result, ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.opts))}

      text == "an unsupported workflow class is submitted" ->
        result =
          ProviderBridge.submit_job(ctx.provider, %{workflow: :analog_program},
            target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
            provider_config: %{
              region: "us-east-1",
              credentials_profile: "default",
              device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
            }
          )

        {:handled, Map.put(ctx, :unsupported_workflow_result, result)}

      text == "fetch_result is requested" and Map.has_key?(ctx, :non_terminal_job) ->
        {:handled,
         Map.put(ctx, :non_terminal_fetch_result, ProviderBridge.fetch_result(AwsBraket, ctx.non_terminal_job, []))}

      text == "poll is requested" ->
        {:handled, Map.put(ctx, :timeout_result, ProviderBridge.poll_job(AwsBraket, ctx.timeout_job, ctx.timeout_opts))}

      text == "response normalization is applied" and ctx.provider == BrokenBraketPayloadProvider ->
        {:handled,
         Map.put(ctx, :unexpected_response_result, ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.opts))}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "Braket task states are normalized into NxQuantum lifecycle states" ->
        assert {:ok, %{state: :submitted}} = ctx.submit_result
        assert {:ok, %{state: :completed}} = ctx.poll_result
        {:handled, ctx}

      text == "terminal states include typed metadata with provider context" ->
        assert {:ok, %{metadata: %{raw_state: "COMPLETED", job_id: _}}} = ctx.poll_result
        {:handled, ctx}

      text == "unknown status payloads return error \"provider_invalid_response\"" ->
        assert {:error, %{code: :provider_invalid_response}} = ctx.unknown_status_result
        {:handled, ctx}

      text == "error metadata includes provider and target identifiers" ->
        assert {:error, %{provider: :aws_braket, metadata: metadata}} = ctx.preflight_result
        assert metadata.provider == :aws_braket
        assert metadata.target == "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
        {:handled, ctx}

      text == "no fallback target is selected automatically" ->
        assert {:error, %{metadata: metadata}} = ctx.preflight_result
        assert metadata.target == "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
        {:handled, ctx}

      text == "the request is rejected deterministically" ->
        assert {:error, %{code: :provider_capability_mismatch}} = ctx.unsupported_workflow_result
        {:handled, ctx}

      text == "typed diagnostics explain the unsupported workflow class" ->
        assert {:error, %{metadata: %{workflow: :analog_program, reason: :unsupported_workflow_class}}} =
                 ctx.unsupported_workflow_result

        {:handled, ctx}

      text == "capability metadata indicates how support can be introduced without breaking existing contracts" ->
        assert {:error, %{metadata: metadata}} = ctx.unsupported_workflow_result
        assert metadata.reason == :unsupported_workflow_class
        {:handled, ctx}

      text == "error metadata includes operation \"fetch_result\" and current task state" ->
        assert {:error, %{operation: :fetch_result, state: :submitted}} = ctx.non_terminal_fetch_result
        {:handled, ctx}

      text == "error metadata includes operation \"poll\" and provider identifier" ->
        assert {:error, %{operation: :poll, provider: :aws_braket}} = ctx.timeout_result
        {:handled, ctx}

      text == "diagnostics include operation \"submit\"" ->
        assert {:error, %{operation: :submit}} = ctx.unexpected_response_result
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_errors(%{text: text}, ctx) do
    if text =~ ~r/^error / and text =~ ~r/ is returned$/ do
      expected = text |> NxQuantum.TestSupport.Helpers.parse_quoted() |> String.to_atom()

      candidate =
        Map.get(ctx, :preflight_result) ||
          Map.get(ctx, :unsupported_workflow_result) ||
          Map.get(ctx, :non_terminal_fetch_result) ||
          Map.get(ctx, :timeout_result) ||
          Map.get(ctx, :unexpected_response_result)

      assert {:error, %{code: ^expected}} = candidate
      {:handled, ctx}
    else
      :unhandled
    end
  end
end
