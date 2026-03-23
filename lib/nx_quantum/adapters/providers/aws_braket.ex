defmodule NxQuantum.Adapters.Providers.AwsBraket do
  @moduledoc """
  Deterministic AWS Braket provider adapter behind `NxQuantum.Ports.Provider`.
  """

  @behaviour NxQuantum.Ports.Provider

  alias NxQuantum.Adapters.Providers.Common.LifecycleSupport
  alias NxQuantum.Adapters.Providers.Common.StateMapper
  alias NxQuantum.Adapters.Providers.Common.TransportSupport
  alias NxQuantum.ProviderBridge.Job
  alias NxQuantum.Providers.Config

  @submit_states %{"CREATED" => :submitted, "QUEUED" => :queued, "RUNNING" => :running}
  @poll_states Map.merge(@submit_states, %{"COMPLETED" => :completed, "CANCELLED" => :cancelled, "FAILED" => :failed})
  @transport_required_config_keys [:region, :credentials_profile, :device_arn]

  @capabilities %NxQuantum.ProviderBridge.CapabilityContract{
    supports_estimator: false,
    supports_sampler: true,
    supports_batch: true,
    supports_dynamic: false,
    supports_cancel_in_running: true,
    supports_calibration_payload: false,
    target_class: :gate_model
  }

  @impl true
  def provider_id, do: :aws_braket

  @impl true
  def capabilities(_target, _opts), do: {:ok, @capabilities}

  @spec transport_readiness(keyword()) :: {:ok, map()}
  def transport_readiness(opts \\ []),
    do: {:ok, TransportSupport.readiness(provider_id(), opts, @transport_required_config_keys, :submit)}

  @impl true
  def submit(payload, opts \\ []) when is_map(payload) do
    with :ok <- LifecycleSupport.maybe_force_error(:submit, opts),
         {:ok, _config} <-
           Config.fetch_required(provider_id(), opts, @transport_required_config_keys, :submit),
         {:ok, raw_state} <- LifecycleSupport.raw_state(:submit, opts, &default_raw_state/1),
         {:ok, state, metadata} <-
           StateMapper.map(:submit, provider_id(), @submit_states, raw_state, target(opts), %{
             workflow: Map.get(payload, :workflow),
             shots: Map.get(payload, :shots)
           }) do
      transport = TransportSupport.readiness(provider_id(), opts, @transport_required_config_keys, :submit)

      LifecycleSupport.maybe_notify_submit(provider_id(), opts)

      {:ok,
       %Job{
         id: job_id(payload, opts),
         state: state,
         provider: provider_id(),
         target: target(opts),
         submitted_at: LifecycleSupport.submitted_at(opts),
         metadata:
           metadata
           |> Map.put(:provider_payload_version, "braket.v1")
           |> Map.put(:transport, transport)
       }}
    end
  end

  @impl true
  def poll(%Job{} = job, opts \\ []) do
    with :ok <- LifecycleSupport.maybe_force_error(:poll, opts),
         {:ok, raw_state} <- LifecycleSupport.raw_state(:poll, opts, &default_raw_state/1),
         {:ok, state, metadata} <-
           StateMapper.map(:poll, provider_id(), @poll_states, raw_state, job.target, %{job_id: job.id}) do
      transport = TransportSupport.readiness(provider_id(), opts, [], :poll)

      {:ok, %{job | state: state, metadata: Map.merge(job.metadata || %{}, Map.put(metadata, :transport, transport))}}
    end
  end

  @impl true
  def cancel(%Job{} = job, opts \\ []) do
    with :ok <- LifecycleSupport.maybe_force_error(:cancel, opts),
         {:ok, raw_state} <- LifecycleSupport.raw_state(:cancel, opts, &default_raw_state/1),
         {:ok, state, metadata} <-
           StateMapper.map(:cancel, provider_id(), %{"CANCELLED" => :cancelled}, raw_state, job.target, %{
             job_id: job.id
           }) do
      transport = TransportSupport.readiness(provider_id(), opts, [], :cancel)

      {:ok, %{job | state: state, metadata: Map.merge(job.metadata || %{}, Map.put(metadata, :transport, transport))}}
    end
  end

  @impl true
  def fetch_result(%Job{state: state} = job, opts \\ []) do
    with :ok <- LifecycleSupport.maybe_force_error(:fetch_result, opts),
         :ok <- LifecycleSupport.validate_terminal_state(state) do
      payload = Keyword.get(opts, :fixture_payload, default_payload(job))
      transport = TransportSupport.readiness(provider_id(), opts, [], :fetch_result)
      result = LifecycleSupport.result(job, provider_id(), "braket.v1", payload)

      {:ok, %{result | metadata: Map.put(result.metadata, :transport, transport)}}
    end
  end

  defp default_raw_state(:submit), do: "CREATED"
  defp default_raw_state(:poll), do: "COMPLETED"
  defp default_raw_state(:cancel), do: "CANCELLED"

  defp default_payload(%Job{} = job), do: LifecycleSupport.default_sampler_payload(job)

  defp job_id(payload, opts) do
    LifecycleSupport.deterministic_job_id("braket_task", payload, target(opts), opts)
  end

  defp target(opts) do
    LifecycleSupport.target(opts, :device_arn, "unknown_target")
  end
end
