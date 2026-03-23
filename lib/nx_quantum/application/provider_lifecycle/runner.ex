defmodule NxQuantum.Application.ProviderLifecycle.Runner do
  @moduledoc false

  alias NxQuantum.Application.ProviderLifecycle.Commands.Cancel
  alias NxQuantum.Application.ProviderLifecycle.Commands.FetchResult
  alias NxQuantum.Application.ProviderLifecycle.Commands.Poll
  alias NxQuantum.Application.ProviderLifecycle.Commands.Submit
  alias NxQuantum.Application.ProviderLifecycle.Dispatcher
  alias NxQuantum.Application.ProviderLifecycle.Preflight
  alias NxQuantum.Observability
  alias NxQuantum.ProviderBridge.Job
  alias NxQuantum.ProviderBridge.ProviderError
  alias NxQuantum.ProviderBridge.Result
  alias NxQuantum.ProviderBridge.Serialization

  @spec submit_job(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def submit_job(provider_adapter, payload, opts) do
    provider = Dispatcher.provider_id(provider_adapter)

    with :ok <- Preflight.run(provider_adapter, payload, opts),
         {:ok, submitted} <- Dispatcher.dispatch(provider_adapter, Submit, [payload, opts], opts) do
      {:ok, attach_contract_context(submitted, :submit, provider, payload, opts)}
    else
      {:error, error} -> {:error, attach_contract_context(error, :submit, provider, payload, opts)}
    end
  end

  @spec poll_job(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def poll_job(provider_adapter, job, opts) do
    provider = Dispatcher.provider_id(provider_adapter)
    normalized_job = normalize_job(job)

    case Dispatcher.dispatch(provider_adapter, Poll, [normalized_job, opts], opts) do
      {:ok, polled} -> {:ok, attach_contract_context(polled, :poll, provider, normalized_job, opts)}
      {:error, error} -> {:error, attach_contract_context(error, :poll, provider, normalized_job, opts)}
    end
  end

  @spec cancel_job(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def cancel_job(provider_adapter, job, opts) do
    provider = Dispatcher.provider_id(provider_adapter)
    normalized_job = normalize_job(job)

    case Dispatcher.dispatch(provider_adapter, Cancel, [normalized_job, opts], opts) do
      {:ok, cancelled} -> {:ok, attach_contract_context(cancelled, :cancel, provider, normalized_job, opts)}
      {:error, error} -> {:error, attach_contract_context(error, :cancel, provider, normalized_job, opts)}
    end
  end

  @spec fetch_result(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def fetch_result(provider_adapter, job, opts) do
    provider = Dispatcher.provider_id(provider_adapter)
    normalized_job = normalize_job(job)

    case Dispatcher.dispatch(provider_adapter, FetchResult, [normalized_job, opts], opts) do
      {:ok, result} -> {:ok, attach_contract_context(result, :fetch_result, provider, normalized_job, opts)}
      {:error, error} -> {:error, attach_contract_context(error, :fetch_result, provider, normalized_job, opts)}
    end
  end

  @spec run_lifecycle(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def run_lifecycle(provider_adapter, payload, opts) do
    provider = Dispatcher.provider_id(provider_adapter)
    target = Keyword.get(opts, :target, "unknown_target")
    workflow = Map.get(payload, :workflow, :unknown_workflow)

    Observability.trace_workflow(provider, target, workflow, Keyword.get(opts, :observability, []), fn ->
      with {:ok, submitted} <- submit_job(provider_adapter, payload, opts),
           {:ok, polled} <- poll_job(provider_adapter, submitted, opts),
           {:ok, result} <- fetch_result(provider_adapter, polled, opts) do
        {:ok, %{submitted: submitted, polled: polled, result: result}}
      end
    end)
  end

  defp normalize_job(%Job{} = job), do: job

  defp normalize_job(%{} = map) do
    metadata =
      map
      |> Map.get(:metadata, %{})
      |> ensure_metadata_map()
      |> maybe_put_legacy(:simulate_timeout, map)
      |> maybe_put_legacy(:payload, map)

    map
    |> Map.put(:metadata, metadata)
    |> then(&struct(Job, &1))
  end

  defp ensure_metadata_map(value) when is_map(value), do: value
  defp ensure_metadata_map(_), do: %{}

  defp maybe_put_legacy(metadata, key, map) do
    case {Map.has_key?(metadata, key), Map.fetch(map, key)} do
      {false, {:ok, value}} -> Map.put(metadata, key, value)
      _ -> metadata
    end
  end

  defp attach_contract_context(%Job{} = job, operation, provider, source, opts) do
    correlation_id = resolve_correlation_id(job.correlation_id, operation, provider, source, opts)
    idempotency_key = resolve_idempotency_key(job.idempotency_key, operation, provider, source, opts)

    %{
      job
      | schema_version: Serialization.schema_version(),
        correlation_id: correlation_id,
        idempotency_key: idempotency_key,
        metadata: Map.put(job.metadata || %{}, :contract_schema_version, Serialization.schema_version())
    }
  end

  defp attach_contract_context(%Result{} = result, operation, provider, source, opts) do
    correlation_id = resolve_correlation_id(result.correlation_id, operation, provider, source, opts)
    idempotency_key = resolve_idempotency_key(result.idempotency_key, operation, provider, source, opts)

    %{
      result
      | schema_version: Serialization.schema_version(),
        correlation_id: correlation_id,
        idempotency_key: idempotency_key,
        metadata: Map.put(result.metadata || %{}, :contract_schema_version, Serialization.schema_version())
    }
  end

  defp attach_contract_context(%ProviderError{} = error, operation, provider, source, opts) do
    correlation_id = resolve_correlation_id(error.correlation_id, operation, provider, source, opts)
    idempotency_key = resolve_idempotency_key(error.idempotency_key, operation, provider, source, opts)

    %{
      error
      | schema_version: Serialization.schema_version(),
        correlation_id: correlation_id,
        idempotency_key: idempotency_key,
        metadata: Map.put(error.metadata || %{}, :contract_schema_version, Serialization.schema_version())
    }
  end

  defp attach_contract_context(other, _operation, _provider, _source, _opts), do: other

  defp resolve_correlation_id(existing, _operation, _provider, _source, _opts)
       when is_binary(existing) and existing != "", do: existing

  defp resolve_correlation_id(_existing, operation, provider, source, opts) do
    if value = Keyword.get(opts, :correlation_id) do
      value
    else
      deterministic_token("corr", operation, provider, source)
    end
  end

  defp resolve_idempotency_key(existing, _operation, _provider, _source, _opts)
       when is_binary(existing) and existing != "", do: existing

  defp resolve_idempotency_key(_existing, operation, provider, source, opts) do
    if value = Keyword.get(opts, :idempotency_key) do
      value
    else
      deterministic_token("idem", operation, provider, source)
    end
  end

  defp deterministic_token(prefix, operation, provider, source) do
    digest =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary(%{operation: operation, provider: provider, source: source}))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 16)

    "#{prefix}_#{digest}"
  end
end
