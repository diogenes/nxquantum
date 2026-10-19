defmodule NxQuantum.ProviderBridge.Serialization do
  @moduledoc """
  Deterministic external-operations serialization helpers for provider envelopes.
  """

  alias NxQuantum.ProviderBridge.Job
  alias NxQuantum.ProviderBridge.ProviderError
  alias NxQuantum.ProviderBridge.Result

  @schema_version :v1

  @spec schema_version() :: :v1
  def schema_version, do: @schema_version

  @spec to_external_map(Job.t() | Result.t() | ProviderError.t() | map()) :: map()
  def to_external_map(%Job{} = job) do
    %{
      "schema_version" => version_string(job.schema_version || @schema_version),
      "type" => "job",
      "id" => job.id,
      "state" => to_string(job.state),
      "provider" => provider_value(job.provider),
      "target" => job.target,
      "submitted_at" => job.submitted_at,
      "request_id" => job.request_id,
      "correlation_id" => job.correlation_id,
      "idempotency_key" => job.idempotency_key,
      "metadata" => stringify_keys(job.metadata || %{})
    }
  end

  def to_external_map(%Result{} = result) do
    %{
      "schema_version" => version_string(result.schema_version || @schema_version),
      "type" => "result",
      "job_id" => result.job_id,
      "state" => to_string(result.state),
      "provider" => provider_value(result.provider),
      "target" => result.target,
      "request_id" => result.request_id,
      "correlation_id" => result.correlation_id,
      "idempotency_key" => result.idempotency_key,
      "payload" => stringify_keys(result.payload || %{}),
      "metadata" => stringify_keys(result.metadata || %{})
    }
  end

  def to_external_map(%ProviderError{} = error) do
    %{
      "schema_version" => version_string(error.schema_version || @schema_version),
      "type" => "error",
      "code" => to_string(error.code),
      "operation" => to_string(error.operation),
      "provider" => provider_value(error.provider),
      "reason" => stringify_value(error.reason),
      "state" => stringify_value(error.state),
      "capability" => stringify_value(error.capability),
      "response" => stringify_value(error.response),
      "request_id" => error.request_id,
      "correlation_id" => error.correlation_id,
      "idempotency_key" => error.idempotency_key,
      "metadata" => stringify_keys(error.metadata || %{})
    }
  end

  def to_external_map(%{} = envelope), do: stringify_keys(envelope)

  @job_states %{
    "submitted" => :submitted,
    "queued" => :queued,
    "running" => :running,
    "completed" => :completed,
    "cancelled" => :cancelled,
    "failed" => :failed
  }

  @error_codes %{
    "provider_transport_error" => :provider_transport_error,
    "provider_auth_error" => :provider_auth_error,
    "provider_invalid_state" => :provider_invalid_state,
    "provider_invalid_response" => :provider_invalid_response,
    "provider_capability_mismatch" => :provider_capability_mismatch,
    "provider_execution_error" => :provider_execution_error,
    "provider_rate_limited" => :provider_rate_limited
  }

  @operations %{
    "submit" => :submit,
    "poll" => :poll,
    "cancel" => :cancel,
    "fetch_result" => :fetch_result
  }

  @doc """
  Decodes a versioned external envelope map (as produced by `to_external_map/1`) back into a typed envelope.

  Only `schema_version` `"v1"` is accepted. Unknown versions, envelope types, states, codes, and operations
  return a typed error instead of creating atoms from input. The provider is kept as its external string id,
  because the external form does not carry the adapter module.

  Contract: `to_external_map(from_external_map(map)) == map` for every map this module emits.
  """
  @spec from_external_map(map()) ::
          {:ok, Job.t() | Result.t() | ProviderError.t()} | {:error, map()}
  def from_external_map(%{"schema_version" => "v1", "type" => "job"} = map) do
    with {:ok, state} <- decode_state(map["state"]) do
      {:ok,
       %Job{
         id: map["id"],
         state: state,
         provider: map["provider"],
         target: map["target"],
         submitted_at: map["submitted_at"],
         schema_version: @schema_version,
         request_id: map["request_id"],
         correlation_id: map["correlation_id"],
         idempotency_key: map["idempotency_key"],
         metadata: map["metadata"] || %{}
       }}
    end
  end

  def from_external_map(%{"schema_version" => "v1", "type" => "result"} = map) do
    with {:ok, state} <- decode_state(map["state"]) do
      {:ok,
       %Result{
         job_id: map["job_id"],
         state: state,
         provider: map["provider"],
         target: map["target"],
         payload: map["payload"] || %{},
         schema_version: @schema_version,
         request_id: map["request_id"],
         correlation_id: map["correlation_id"],
         idempotency_key: map["idempotency_key"],
         metadata: map["metadata"] || %{}
       }}
    end
  end

  def from_external_map(%{"schema_version" => "v1", "type" => "error"} = map) do
    with {:ok, code} <- decode_enum(map["code"], @error_codes, :invalid_envelope_code),
         {:ok, operation} <- decode_enum(map["operation"], @operations, :invalid_envelope_operation) do
      {:ok,
       %ProviderError{
         code: code,
         operation: operation,
         provider: map["provider"],
         reason: map["reason"],
         state: map["state"],
         capability: map["capability"],
         response: map["response"],
         schema_version: @schema_version,
         request_id: map["request_id"],
         correlation_id: map["correlation_id"],
         idempotency_key: map["idempotency_key"],
         metadata: map["metadata"] || %{}
       }}
    end
  end

  def from_external_map(%{"schema_version" => version}) when version != "v1" do
    {:error, %{code: :unsupported_envelope_schema_version, schema_version: version, supported: ["v1"]}}
  end

  def from_external_map(%{"type" => type}) do
    {:error, %{code: :unsupported_envelope_type, type: type}}
  end

  def from_external_map(_other) do
    {:error, %{code: :invalid_envelope_shape}}
  end

  defp decode_state(state), do: decode_enum(state, @job_states, :invalid_envelope_state)

  defp decode_enum(value, table, error_code) do
    case Map.fetch(table, value) do
      {:ok, atom} -> {:ok, atom}
      :error -> {:error, %{code: error_code, value: value}}
    end
  end

  @spec serialize(Job.t() | Result.t() | ProviderError.t() | map()) :: {:ok, String.t()}
  def serialize(envelope) do
    encoded =
      envelope
      |> to_external_map()
      |> :erlang.term_to_binary([:deterministic])
      |> Base.url_encode64(padding: false)

    {:ok, encoded}
  end

  defp version_string(version) when is_atom(version), do: Atom.to_string(version)
  defp version_string(version) when is_binary(version), do: version

  defp provider_value(provider) when is_atom(provider), do: Atom.to_string(provider)
  defp provider_value(provider) when is_binary(provider), do: provider
  defp provider_value(provider), do: inspect(provider)

  defp stringify_keys(%{} = map) do
    map
    |> Enum.sort_by(fn {key, _value} -> to_string(key) end)
    |> Map.new(fn {key, value} -> {to_string(key), stringify_value(value)} end)
  end

  defp stringify_value(%{} = map), do: stringify_keys(map)
  defp stringify_value(list) when is_list(list), do: Enum.map(list, &stringify_value/1)
  defp stringify_value(value) when is_atom(value), do: Atom.to_string(value)
  defp stringify_value(%Nx.Tensor{} = tensor), do: inspect(tensor)
  defp stringify_value(value), do: value
end
