defmodule NxQuantum.Adapters.Providers.Common.LifecycleSupport do
  @moduledoc false

  alias NxQuantum.ProviderBridge.Job
  alias NxQuantum.ProviderBridge.Result

  @spec maybe_notify_submit(atom(), keyword()) :: :ok
  def maybe_notify_submit(provider_id, opts) do
    if pid = opts[:notify_submit_pid] do
      send(pid, {:provider_submit_attempt, provider_id})
    end

    :ok
  end

  @spec validate_terminal_state(Job.state()) :: :ok | {:error, {:invalid_state, Job.state()}}
  def validate_terminal_state(state) when state in [:completed, :cancelled, :failed], do: :ok
  def validate_terminal_state(state), do: {:error, {:invalid_state, state}}

  @spec maybe_force_error(atom(), keyword()) :: :ok | {:error, term()}
  def maybe_force_error(operation, opts) do
    case opts[:force_error] do
      {^operation, reason} -> {:error, reason}
      _ -> :ok
    end
  end

  @spec raw_state(atom(), keyword(), (atom() -> String.t())) :: {:ok, String.t()} | {:error, term()}
  def raw_state(operation, opts, default_fun) when is_function(default_fun, 1) do
    raw_states = opts[:raw_states] || %{}

    case Map.get(raw_states, operation, default_fun.(operation)) do
      state when is_binary(state) -> {:ok, state}
      other -> {:error, {:invalid_response, operation, other}}
    end
  end

  @spec submitted_at(keyword()) :: String.t() | nil
  def submitted_at(opts), do: Keyword.get(opts, :submitted_at)

  @spec deterministic_job_id(String.t(), map(), String.t(), keyword()) :: String.t()
  def deterministic_job_id(prefix, payload, target, opts) do
    Keyword.get_lazy(opts, :job_id, fn ->
      digest =
        :sha256
        |> :crypto.hash(:erlang.term_to_binary(%{payload: payload, target: target}, [:deterministic]))
        |> Base.encode16(case: :lower)
        |> binary_part(0, 12)

      "#{prefix}_#{digest}"
    end)
  end

  @spec target(keyword(), atom(), String.t()) :: String.t()
  def target(opts, config_key, fallback) do
    Keyword.get_lazy(opts, :target, fn ->
      opts
      |> Keyword.get(:provider_config, %{})
      |> Map.get(config_key, fallback)
    end)
  end

  @spec default_sampler_payload(Job.t()) :: map()
  def default_sampler_payload(job) do
    shots = normalized_shots(job.metadata)
    zero_count = div(shots, 2)

    %{
      workflow: "sampler",
      counts: %{"00" => zero_count, "11" => shots - zero_count},
      metadata: %{job_id: job.id, source: "fixture", shots: shots}
    }
  end

  @spec result(Job.t(), atom(), String.t(), map(), keyword()) :: Result.t()
  def result(job, provider, version, payload, opts \\ []) do
    %Result{
      job_id: job.id,
      state: job.state,
      provider: provider,
      target: job.target,
      payload: payload,
      metadata: %{
        raw_payload: payload,
        raw_state: (job.metadata || %{})[:raw_state],
        provider_payload_version: version,
        caveats: Keyword.get(opts, :caveats, [])
      }
    }
  end

  defp normalized_shots(metadata) do
    metadata
    |> Kernel.||(%{})
    |> Map.get(:shots)
    |> case do
      shots when is_integer(shots) and shots >= 0 -> shots
      _ -> 0
    end
  end
end
