defmodule NxQuantum.AI.Request do
  @moduledoc """
  Canonical AI tool request envelope.
  """

  @enforce_keys [:schema_version, :request_id, :correlation_id, :tool_name, :input]
  defstruct [
    :schema_version,
    :request_id,
    :correlation_id,
    :idempotency_key,
    :tool_name,
    :tool_version,
    :input,
    execution_policy: %{},
    trace_context: %{},
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          schema_version: String.t(),
          request_id: String.t(),
          correlation_id: String.t(),
          idempotency_key: String.t() | nil,
          tool_name: String.t(),
          tool_version: String.t() | nil,
          input: map(),
          execution_policy: map(),
          trace_context: map(),
          metadata: map()
        }

  @spec new(map() | keyword()) :: {:ok, t()} | {:error, map()}
  def new(attrs) when is_map(attrs) or is_list(attrs) do
    attrs_map = Map.new(attrs)

    with :ok <- required_binary(attrs_map, :schema_version),
         :ok <- required_binary(attrs_map, :request_id),
         :ok <- required_binary(attrs_map, :correlation_id),
         :ok <- required_binary(attrs_map, :tool_name),
         {:ok, input} <- fetch_input(attrs_map) do
      {:ok,
       struct(__MODULE__, %{
         schema_version: attrs_map.schema_version,
         request_id: attrs_map.request_id,
         correlation_id: attrs_map.correlation_id,
         idempotency_key: Map.get(attrs_map, :idempotency_key),
         tool_name: attrs_map.tool_name,
         tool_version: Map.get(attrs_map, :tool_version),
         input: input,
         execution_policy: Map.get(attrs_map, :execution_policy, %{}),
         trace_context: Map.get(attrs_map, :trace_context, %{}),
         metadata: Map.get(attrs_map, :metadata, %{})
       })}
    end
  end

  defp required_binary(map, key) do
    case Map.get(map, key) do
      value when is_binary(value) and value != "" -> :ok
      _ -> {:error, %{code: :ai_tool_invalid_request, field: key}}
    end
  end

  defp fetch_input(map) do
    case Map.get(map, :input) do
      value when is_map(value) -> {:ok, value}
      _ -> {:error, %{code: :ai_tool_invalid_request, field: :input}}
    end
  end
end
