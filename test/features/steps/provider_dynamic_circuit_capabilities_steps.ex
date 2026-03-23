defmodule NxQuantum.Features.Steps.ProviderDynamicCircuitCapabilitiesSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Ports.Provider
  alias NxQuantum.ProviderBridge
  alias NxQuantum.ProviderBridge.CapabilityContract
  alias NxQuantum.ProviderBridge.Job

  defmodule DynamicCapabilityProvider do
    @moduledoc false

    @behaviour Provider

    @impl true
    def provider_id, do: :dynamic_capability_provider

    @impl true
    def capabilities(_target, _opts) do
      {:ok,
       %CapabilityContract{
         supports_estimator: true,
         supports_sampler: true,
         supports_batch: true,
         supports_dynamic: true,
         supports_cancel_in_running: true,
         supports_calibration_payload: false,
         target_class: :gate_model
       }}
    end

    @impl true
    def submit(payload, opts) when is_map(payload) do
      target = Keyword.get(opts, :target, "dynamic.target")

      {:ok,
       %Job{
         id: job_id(payload, target),
         state: :submitted,
         provider: provider_id(),
         target: target,
         metadata: %{
           branch_decision: :feed_forward,
           dynamic_node: "mid_circuit_feed_forward",
           register_trace: ["q0", "q1"],
           provider_payload_version: "dynamic.v1"
         }
       }}
    end

    @impl true
    def poll(%Job{} = job, _opts), do: {:ok, %{job | state: :completed}}

    @impl true
    def cancel(%Job{} = job, _opts), do: {:ok, %{job | state: :cancelled}}

    @impl true
    def fetch_result(%Job{} = job, _opts),
      do: {:ok, %{job_id: job.id, state: :completed, provider: provider_id(), target: job.target, payload: %{}}}

    defp job_id(payload, target) do
      payload
      |> Map.put(:target, target)
      |> :erlang.phash2()
      |> Integer.to_string()
      |> then(&("dynamic_job_" <> &1))
    end
  end

  defmodule UnsupportedDynamicCapabilityProvider do
    @moduledoc false

    @behaviour Provider

    @impl true
    def provider_id, do: :legacy_dynamic_capability_provider

    @impl true
    def capabilities(_target, _opts) do
      {:ok,
       %CapabilityContract{
         supports_estimator: true,
         supports_sampler: true,
         supports_batch: true,
         supports_dynamic: false,
         supports_cancel_in_running: true,
         supports_calibration_payload: false,
         target_class: :gate_model
       }}
    end

    @impl true
    def submit(_payload, opts) do
      if pid = Keyword.get(opts, :notify_submit_pid) do
        send(pid, {:provider_submit_attempt, provider_id()})
      end

      raise "unsupported dynamic workflow should have failed during preflight"
    end

    @impl true
    def poll(job, _opts), do: {:ok, job}

    @impl true
    def cancel(job, _opts), do: {:ok, job}

    @impl true
    def fetch_result(_job, _opts), do: {:ok, %{}}
  end

  @impl true
  def feature, do: "provider_dynamic_circuit_capabilities.feature"

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
      text == "selected provider supports mid-circuit measurement and feed-forward control" ->
        {:handled,
         Map.merge(ctx, %{
           payload: %{workflow: :sampler, dynamic: true},
           provider: DynamicCapabilityProvider,
           submit_opts: [target: "dynamic-capability-target"]
         })}

      text == ~s(selected provider does not support dynamic circuit node "mid_circuit_feed_forward") ->
        {:handled,
         Map.merge(ctx, %{
           payload: %{workflow: :sampler, dynamic: true},
           provider: UnsupportedDynamicCapabilityProvider,
           submit_opts: [notify_submit_pid: self(), target: "legacy-dynamic-target"]
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: "a dynamic workflow is submitted"}, ctx) do
    submit_a = ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.submit_opts)
    submit_b = ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.submit_opts)

    {:handled, Map.merge(ctx, %{submit_a: submit_a, submit_b: submit_b})}
  end

  defp handle_execution(%{text: "a dynamic workflow is submitted twice"}, ctx) do
    submit_a = ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.submit_opts)
    submit_b = ProviderBridge.submit_job(ctx.provider, ctx.payload, ctx.submit_opts)

    {:handled, Map.merge(ctx, %{submit_a: submit_a, submit_b: submit_b})}
  end

  defp handle_execution(_step, _ctx), do: :unhandled

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "execution path remains typed and deterministic" ->
        assert {:ok, submitted_a} = ctx.submit_a
        assert {:ok, submitted_b} = ctx.submit_b
        assert submitted_a == submitted_b
        assert submitted_a.state == :submitted
        assert submitted_a.provider == :dynamic_capability_provider
        {:handled, ctx}

      text == "branch decision metadata is preserved" ->
        assert {:ok, submitted} = ctx.submit_a
        assert submitted.metadata.branch_decision == :feed_forward
        assert submitted.metadata.dynamic_node == "mid_circuit_feed_forward"
        {:handled, ctx}

      text == "register trace metadata is preserved" ->
        assert {:ok, submitted} = ctx.submit_a
        assert submitted.metadata.register_trace == ["q0", "q1"]
        {:handled, ctx}

      text == "error \"provider_capability_mismatch\" is returned before remote execution" ->
        candidate = Map.get(ctx, :submit_result) || Map.get(ctx, :submit_a)
        assert {:error, %{code: :provider_capability_mismatch, capability: :supports_dynamic}} = candidate
        {:handled, ctx}

      text == "no remote submit lifecycle call is attempted" ->
        refute_received {:provider_submit_attempt, :legacy_dynamic_capability_provider}
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
