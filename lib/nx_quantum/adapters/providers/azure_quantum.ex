defmodule NxQuantum.Adapters.Providers.AzureQuantum do
  @moduledoc """
  Deterministic Azure Quantum adapter behind `NxQuantum.Ports.Provider`.
  """

  @behaviour NxQuantum.Ports.Provider

  alias NxQuantum.Adapters.Providers.Common.LifecycleSupport
  alias NxQuantum.Adapters.Providers.Common.StateMapper
  alias NxQuantum.Adapters.Providers.Common.TransportSupport
  alias NxQuantum.ProviderBridge.Job
  alias NxQuantum.Providers.Config

  @submit_states %{"SUBMITTED" => :submitted, "WAITING" => :queued, "EXECUTING" => :running}
  @poll_states Map.merge(@submit_states, %{"SUCCEEDED" => :completed, "CANCELLED" => :cancelled, "FAILED" => :failed})
  @transport_required_config_keys [:workspace, :auth_context, :target_id, :provider_name]

  @capabilities %NxQuantum.ProviderBridge.CapabilityContract{
    supports_estimator: true,
    supports_sampler: true,
    supports_batch: true,
    supports_dynamic: false,
    supports_cancel_in_running: true,
    supports_calibration_payload: true,
    target_class: :gate_model
  }

  @impl true
  def provider_id, do: :azure_quantum

  @impl true
  def capabilities(_target, _opts), do: {:ok, @capabilities}

  @spec transport_readiness(keyword()) :: {:ok, map()}
  def transport_readiness(opts \\ []),
    do: {:ok, TransportSupport.readiness(provider_id(), opts, @transport_required_config_keys, :submit)}

  @impl true
  def submit(payload, opts \\ []) when is_map(payload) do
    with :ok <- LifecycleSupport.maybe_force_error(:submit, opts),
         {:ok, config} <-
           Config.fetch_required(provider_id(), opts, @transport_required_config_keys, :submit),
         {:ok, raw_state} <- LifecycleSupport.raw_state(:submit, opts, &default_raw_state/1),
         {:ok, state, metadata} <-
           StateMapper.map(:submit, provider_id(), @submit_states, raw_state, target(opts), %{
             workflow: Map.get(payload, :workflow),
             shots: Map.get(payload, :shots)
           }) do
      transport = TransportSupport.readiness(provider_id(), opts, @transport_required_config_keys, :submit)

      {:ok,
       %Job{
         id: job_id(payload, opts),
         state: state,
         provider: provider_id(),
         target: target(opts),
         submitted_at: LifecycleSupport.submitted_at(opts),
         metadata:
           Map.merge(metadata, %{
             provider_payload_version: "azure.v1",
             workspace: config.workspace,
             provider_name: config.provider_name,
             transport: transport
           })
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
      caveat = Keyword.get(opts, :cancellation_caveat, nil)
      transport = TransportSupport.readiness(provider_id(), opts, [], :cancel)

      {:ok,
       %{
         job
         | state: state,
           metadata:
             Map.merge(
               job.metadata || %{},
               Map.put(Map.put(metadata, :cancellation_caveat, caveat), :transport, transport)
             )
       }}
    end
  end

  @impl true
  def fetch_result(%Job{state: state} = job, opts \\ []) do
    with :ok <- LifecycleSupport.maybe_force_error(:fetch_result, opts),
         :ok <- LifecycleSupport.validate_terminal_state(state) do
      payload = Keyword.get(opts, :fixture_payload, default_payload(job))
      transport = TransportSupport.readiness(provider_id(), opts, [], :fetch_result)
      result = LifecycleSupport.result(job, provider_id(), "azure.v1", payload, caveats: caveats(opts))

      {:ok, %{result | metadata: Map.put(result.metadata, :transport, transport)}}
    end
  end

  defp default_raw_state(:submit), do: "SUBMITTED"
  defp default_raw_state(:poll), do: "SUCCEEDED"
  defp default_raw_state(:cancel), do: "CANCELLED"

  defp default_payload(%Job{} = job), do: LifecycleSupport.default_sampler_payload(job)

  defp caveats(opts) do
    case Keyword.get(opts, :cancellation_caveat) do
      nil -> []
      caveat -> [caveat]
    end
  end

  defp job_id(payload, opts) do
    LifecycleSupport.deterministic_job_id("azure_job", payload, target(opts), opts)
  end

  defp target(opts) do
    LifecycleSupport.target(opts, :target_id, "unknown_target")
  end
end
