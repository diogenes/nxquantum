defmodule NxQuantum.ProviderBridge do
  @moduledoc """
  Provider lifecycle facade with typed deterministic error mapping.
  """
  alias NxQuantum.ProviderBridge.Errors
  alias NxQuantum.Providers.Capabilities

  @spec submit_job(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def submit_job(provider_adapter, payload, opts \\ []) do
    with :ok <- preflight(provider_adapter, payload, opts) do
      provider_call(provider_adapter, :submit, [payload, opts], :submit)
    end
  end

  @spec poll_job(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def poll_job(provider_adapter, job, opts \\ []) do
    provider_call(provider_adapter, :poll, [job, opts], :poll)
  end

  @spec cancel_job(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def cancel_job(provider_adapter, job, opts \\ []) do
    provider_call(provider_adapter, :cancel, [job, opts], :cancel)
  end

  @spec fetch_result(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def fetch_result(provider_adapter, job, opts \\ []) do
    provider_call(provider_adapter, :fetch_result, [job, opts], :fetch_result)
  end

  @spec run_lifecycle(module(), map(), keyword()) :: {:ok, map()} | {:error, map()}
  def run_lifecycle(provider_adapter, payload, opts \\ []) do
    with {:ok, submitted} <- submit_job(provider_adapter, payload, opts),
         {:ok, polled} <- poll_job(provider_adapter, submitted, opts),
         {:ok, result} <- fetch_result(provider_adapter, polled, opts) do
      {:ok, %{submitted: submitted, polled: polled, result: result}}
    end
  end

  defp provider_call(provider_adapter, fun, args, operation) do
    provider_id = provider_id(provider_adapter)

    try do
      case apply(provider_adapter, fun, args) do
        {:ok, value} ->
          {:ok, value}

        {:error, reason} ->
          {:error, map_error(reason, operation, provider_id)}

        unexpected ->
          {:error, Errors.invalid_response(operation, provider_id, unexpected)}
      end
    rescue
      error ->
        {:error, Errors.transport_error(operation, provider_id, Exception.message(error))}
    end
  end

  defp provider_id(provider_adapter) do
    if function_exported?(provider_adapter, :provider_id, 0) do
      provider_adapter.provider_id()
    else
      provider_adapter
    end
  end

  defp map_error(:timeout, operation, provider) do
    Errors.transport_error(operation, provider, :timeout)
  end

  defp map_error({:provider_auth_error, reason}, operation, provider) do
    Errors.auth_error(operation, provider, reason)
  end

  defp map_error({:provider_rate_limited, reason}, operation, provider) do
    Errors.rate_limited(operation, provider, reason)
  end

  defp map_error({:provider_capability_mismatch, capability}, operation, provider) do
    Errors.capability_mismatch(operation, provider, capability)
  end

  defp map_error({:invalid_response, _source, response}, operation, provider) do
    Errors.invalid_response(operation, provider, response)
  end

  defp map_error({:invalid_state, state}, operation, provider) do
    Errors.invalid_state(operation, provider, state)
  end

  defp map_error(%{code: _} = error, operation, provider) do
    error
    |> Map.put_new(:operation, operation)
    |> Map.put_new(:provider, provider)
    |> Map.put_new(:metadata, %{})
  end

  defp map_error(reason, operation, provider) do
    Errors.execution_error(operation, provider, reason)
  end

  defp preflight(provider_adapter, payload, opts) do
    contract_version = Keyword.get(opts, :capability_contract, :v1)
    target = Keyword.get(opts, :target)
    provider = provider_id(provider_adapter)

    with {:ok, capabilities} <- fetch_capabilities(provider_adapter, target, opts),
         {:ok, validated} <- Capabilities.validate_contract(capabilities, provider, contract_version, target),
         :ok <- Capabilities.preflight(validated, request_envelope(payload, opts), provider, target) do
      :ok
    else
      :skip -> :ok
      {:error, _} = error -> error
    end
  end

  defp fetch_capabilities(provider_adapter, target, opts) do
    if function_exported?(provider_adapter, :capabilities, 2) do
      provider_adapter.capabilities(target, opts)
    else
      :skip
    end
  end

  defp request_envelope(payload, opts) do
    %{
      workflow: Map.get(payload, :workflow, Keyword.get(opts, :workflow)),
      dynamic: Map.get(payload, :dynamic, Keyword.get(opts, :dynamic, false)),
      batch: Map.get(payload, :batch, Keyword.get(opts, :batch, false)),
      calibration_payload: Map.get(payload, :calibration_payload, Keyword.get(opts, :calibration_payload))
    }
  end
end
