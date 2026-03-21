defmodule NxQuantum.Adapters.Providers.AzureQuantum do
  @moduledoc """
  Deterministic Azure Quantum adapter behind `NxQuantum.Ports.Provider`.
  """

  @behaviour NxQuantum.Ports.Provider

  alias NxQuantum.Adapters.Providers.Common.StateMapper
  alias NxQuantum.ProviderBridge.Errors
  alias NxQuantum.Providers.Config

  @submit_states %{"SUBMITTED" => :submitted, "WAITING" => :queued, "EXECUTING" => :running}
  @poll_states Map.merge(@submit_states, %{"SUCCEEDED" => :completed, "CANCELLED" => :cancelled, "FAILED" => :failed})

  @capabilities %{
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

  @impl true
  def submit(payload, opts \\ []) when is_map(payload) do
    with :ok <- maybe_force_error(:submit, opts),
         {:ok, config} <-
           Config.fetch_required(provider_id(), opts, [:workspace, :auth_context, :target_id, :provider_name], :submit),
         :ok <- validate_target_provider_match(config, opts),
         {:ok, raw_state} <- raw_state(:submit, opts),
         {:ok, state, metadata} <-
           StateMapper.map(:submit, provider_id(), @submit_states, raw_state, target(opts), %{
             workflow: Map.get(payload, :workflow),
             shots: Map.get(payload, :shots)
           }) do
      {:ok,
       %{
         id: job_id(payload, opts),
         state: state,
         provider: provider_id(),
         target: target(opts),
         submitted_at: submitted_at(opts),
         metadata:
           Map.merge(metadata, %{
             provider_payload_version: "azure.v1",
             workspace: config.workspace,
             provider_name: config.provider_name
           })
       }}
    end
  end

  @impl true
  def poll(job, opts \\ []) when is_map(job) do
    with :ok <- maybe_force_error(:poll, opts),
         {:ok, raw_state} <- raw_state(:poll, opts),
         {:ok, state, metadata} <-
           StateMapper.map(:poll, provider_id(), @poll_states, raw_state, job[:target], %{job_id: job[:id]}) do
      {:ok, %{job | state: state, metadata: Map.merge(job[:metadata] || %{}, metadata)}}
    end
  end

  @impl true
  def cancel(job, opts \\ []) when is_map(job) do
    with :ok <- maybe_force_error(:cancel, opts),
         {:ok, raw_state} <- raw_state(:cancel, opts),
         {:ok, state, metadata} <-
           StateMapper.map(:cancel, provider_id(), %{"CANCELLED" => :cancelled}, raw_state, job[:target], %{
             job_id: job[:id]
           }) do
      caveat = Keyword.get(opts, :cancellation_caveat, nil)

      {:ok,
       %{job | state: state, metadata: Map.merge(job[:metadata] || %{}, Map.put(metadata, :cancellation_caveat, caveat))}}
    end
  end

  @impl true
  def fetch_result(%{state: state} = job, opts \\ []) do
    with :ok <- maybe_force_error(:fetch_result, opts),
         :ok <- validate_terminal_state(state) do
      payload = Keyword.get(opts, :fixture_payload, default_payload(job))

      {:ok,
       %{
         job_id: job.id,
         state: state,
         provider: provider_id(),
         target: job.target,
         payload: payload,
         metadata: %{
           raw_payload: payload,
           raw_state: (job.metadata || %{})[:raw_state],
           provider_payload_version: "azure.v1",
           caveats: caveats(opts)
         }
       }}
    end
  end

  defp validate_target_provider_match(config, opts) do
    mismatch? = Keyword.get(opts, :provider_target_mismatch, false)

    if mismatch? do
      {:error,
       Errors.capability_mismatch(:submit, provider_id(), :target_provider_match,
         metadata: %{workspace: config.workspace, target: config.target_id, provider_name: config.provider_name}
       )}
    else
      :ok
    end
  end

  defp validate_terminal_state(state) when state in [:completed, :cancelled, :failed], do: :ok
  defp validate_terminal_state(state), do: {:error, {:invalid_state, state}}

  defp maybe_force_error(operation, opts) do
    case opts[:force_error] do
      {^operation, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  defp raw_state(operation, opts) do
    raw_states = opts[:raw_states] || %{}

    case Map.get(raw_states, operation, default_raw_state(operation)) do
      state when is_binary(state) -> {:ok, state}
      other -> {:error, {:invalid_response, operation, other}}
    end
  end

  defp default_raw_state(:submit), do: "SUBMITTED"
  defp default_raw_state(:poll), do: "SUCCEEDED"
  defp default_raw_state(:cancel), do: "CANCELLED"

  defp default_payload(job) do
    shots = get_in(job, [:metadata, :shots]) || 0
    zero_count = div(shots, 2)

    %{
      workflow: "sampler",
      counts: %{"00" => zero_count, "11" => shots - zero_count},
      metadata: %{job_id: job.id, source: "fixture", shots: shots}
    }
  end

  defp caveats(opts) do
    case Keyword.get(opts, :cancellation_caveat) do
      nil -> []
      caveat -> [caveat]
    end
  end

  defp submitted_at(opts), do: Keyword.get(opts, :submitted_at)

  defp job_id(payload, opts) do
    Keyword.get_lazy(opts, :job_id, fn ->
      digest =
        :sha256
        |> :crypto.hash(:erlang.term_to_binary(%{payload: payload, target: target(opts)}))
        |> Base.encode16(case: :lower)
        |> binary_part(0, 12)

      "azure_job_#{digest}"
    end)
  end

  defp target(opts) do
    Keyword.get_lazy(opts, :target, fn ->
      opts
      |> Keyword.get(:provider_config, %{})
      |> Map.get(:target_id, "unknown_target")
    end)
  end
end
