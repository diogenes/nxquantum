defmodule NxQuantum.Features.Steps.ProviderIbmRuntimeBridgeSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.ProviderBridge

  defmodule BrokenIbmPayloadProvider do
    @moduledoc false

    @behaviour NxQuantum.Ports.Provider

    @impl true
    def provider_id, do: :ibm_runtime

    @impl true
    def capabilities(_target, _opts) do
      {:ok,
       %{
         supports_estimator: true,
         supports_sampler: true,
         supports_batch: true,
         supports_dynamic: false,
         supports_cancel_in_running: true,
         supports_calibration_payload: true,
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
  def feature, do: "provider_ibm_runtime_bridge.feature"

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
      text == "IBM Runtime provider integration is configured" ->
        {:handled,
         Map.merge(ctx, %{
           provider: IBMRuntime,
           payload: %{workflow: :estimator, shots: 1024},
           opts: [
             target: "ibm_backend_simulator",
             provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
           ]
         })}

      text == "IBM Runtime supports estimator and sampler workflow intents" ->
        {:handled,
         Map.merge(ctx, %{
           provider: IBMRuntime,
           opts: [
             target: "ibm_backend_simulator",
             provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
           ]
         })}

      text == "an IBM Runtime lifecycle operation fails with auth or backend error" ->
        {:handled,
         Map.merge(ctx, %{
           provider: IBMRuntime,
           auth_failure_payload: %{workflow: :sampler},
           auth_failure_opts: [
             target: "ibm_backend_simulator",
             provider_config: %{auth_token: "ibm-secret-token", backend: "ibm_backend_simulator"}
           ]
         })}

      text == "an IBM Runtime job is in non-terminal state \"submitted\"" ->
        {:handled,
         Map.put(ctx, :non_terminal_job, %{
           id: "ibm_job_1",
           state: :submitted,
           provider: :ibm_runtime,
           target: "ibm_backend_simulator",
           metadata: %{raw_state: "SUBMITTED"}
         })}

      text == "an IBM Runtime poll operation reaches a transport timeout" ->
        {:handled,
         Map.merge(ctx, %{
           timeout_job: %{
             id: "ibm_job_2",
             state: :submitted,
             provider: :ibm_runtime,
             target: "ibm_backend_simulator",
             metadata: %{raw_state: "SUBMITTED"}
           },
           timeout_opts: [
             force_error: {:poll, :timeout},
             target: "ibm_backend_simulator",
             provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
           ]
         })}

      text == "IBM Runtime adapter returns an unexpected payload for submit" ->
        {:handled,
         Map.merge(ctx, %{
           provider: BrokenIbmPayloadProvider,
           payload: %{workflow: :estimator},
           opts: [
             target: "ibm_backend_simulator",
             provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
           ]
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I execute submit, poll, cancel, and fetch_result lifecycle operations" ->
        {:ok, submitted} = ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.opts)
        {:ok, polled} = ProviderBridge.poll_job(ctx.provider, submitted, ctx.opts)
        {:ok, cancelled} = ProviderBridge.cancel_job(ctx.provider, submitted, ctx.opts)
        {:ok, result} = ProviderBridge.fetch_result(ctx.provider, polled, ctx.opts)

        {:handled,
         ctx
         |> Map.put(:submit_result, {:ok, submitted})
         |> Map.put(:poll_result, {:ok, polled})
         |> Map.put(:cancel_result, {:ok, cancelled})
         |> Map.put(:fetch_result, {:ok, result})}

      text == "I submit estimator and sampler workflow requests" ->
        estimator =
          ProviderBridge.submit_job(ctx.provider, %{workflow: :estimator},
            target: "ibm_backend_simulator",
            provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
          )

        sampler =
          ProviderBridge.submit_job(ctx.provider, %{workflow: :sampler},
            target: "ibm_backend_simulator",
            provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
          )

        unsupported =
          ProviderBridge.submit_job(ctx.provider, %{workflow: :sampler, dynamic: true},
            target: "ibm_backend_simulator",
            provider_config: %{auth_token: "ibm-secret-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
          )

        estimator_fetch =
          with {:ok, job} <- estimator,
               {:ok, polled} <- ProviderBridge.poll_job(ctx.provider, job, ctx.opts) do
            ProviderBridge.fetch_result(ctx.provider, polled, ctx.opts)
          end

        {:handled,
         ctx
         |> Map.put(:estimator_submit_result, estimator)
         |> Map.put(:sampler_submit_result, sampler)
         |> Map.put(:unsupported_result, unsupported)
         |> Map.put(:estimator_fetch_result, estimator_fetch)}

      text == "error mapping is applied" ->
        auth_result = ProviderBridge.submit_job(IBMRuntime, ctx.auth_failure_payload, ctx.auth_failure_opts)
        {:handled, Map.put(ctx, :auth_result, auth_result)}

      text == "fetch_result is requested" and Map.has_key?(ctx, :non_terminal_job) ->
        {:handled,
         Map.put(ctx, :non_terminal_fetch_result, ProviderBridge.fetch_result(IBMRuntime, ctx.non_terminal_job, []))}

      text == "poll is requested" ->
        {:handled, Map.put(ctx, :timeout_result, ProviderBridge.poll_job(IBMRuntime, ctx.timeout_job, ctx.timeout_opts))}

      text == "response normalization is applied" and ctx.provider == BrokenIbmPayloadProvider ->
        {:handled,
         Map.put(ctx, :unexpected_response_result, ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.opts))}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "lifecycle operations are exposed through ProviderBridge contract" ->
        assert {:ok, %{id: _}} = ctx.submit_result
        assert {:ok, %{state: _}} = ctx.poll_result
        assert {:ok, %{state: :cancelled}} = ctx.cancel_result
        assert {:ok, %{job_id: _}} = ctx.fetch_result
        {:handled, ctx}

      text == "IBM lifecycle states are normalized deterministically" ->
        assert {:ok, %{state: :submitted}} = ctx.submit_result
        assert {:ok, %{state: :completed}} = ctx.poll_result
        {:handled, ctx}

      text == "raw provider states are preserved under metadata" ->
        assert {:ok, %{metadata: %{raw_state: "SUBMITTED"}}} = ctx.submit_result
        assert {:ok, %{metadata: %{raw_state: "COMPLETED"}}} = ctx.poll_result
        {:handled, ctx}

      text == "requests are validated against typed capability contract" ->
        assert {:ok, %{state: :submitted}} = ctx.estimator_submit_result
        assert {:ok, %{state: :submitted}} = ctx.sampler_submit_result
        {:handled, ctx}

      text == "unsupported capability requests fail fast with typed errors" ->
        assert {:error, %{code: :provider_capability_mismatch, capability: :supports_dynamic}} = ctx.unsupported_result
        {:handled, ctx}

      text == "result payloads preserve typed shape guarantees" ->
        assert {:ok, %{job_id: _, provider: :ibm_runtime, payload: payload}} = ctx.estimator_fetch_result
        assert is_map(payload)
        {:handled, ctx}

      text == "a typed provider error code is returned" ->
        assert {:error, %{code: :provider_auth_error}} = ctx.auth_result
        {:handled, ctx}

      text == "error metadata includes provider and operation context" ->
        assert {:error, %{provider: :ibm_runtime, operation: :submit}} = ctx.auth_result
        {:handled, ctx}

      text == "sensitive fields are deterministically redacted" ->
        assert {:error, %{metadata: %{provider_config: redacted}}} = ctx.auth_result
        assert redacted[:auth_token] == "[REDACTED]"
        {:handled, ctx}

      text == "error metadata includes operation \"fetch_result\" and current job state" ->
        assert {:error, %{operation: :fetch_result, state: :submitted}} = ctx.non_terminal_fetch_result
        {:handled, ctx}

      text == "error metadata includes operation \"poll\" and provider identifier" ->
        assert {:error, %{operation: :poll, provider: :ibm_runtime}} = ctx.timeout_result
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
        Map.get(ctx, :auth_result) ||
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
