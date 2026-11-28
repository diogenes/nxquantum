defmodule NxQuantum.AI.Result do
  @moduledoc """
  Canonical AI tool result envelope.
  """

  # v2: `execution.mode` reports the mode actually used. v1 results from the bundled
  # handlers reported `:quantum` for classical computation (KG-12). See
  # docs/quantum-ai-tool-contracts.md, "Result Envelope".
  @schema_version "v2"

  @enforce_keys [:schema_version, :request_id, :correlation_id, :status, :tool_name]
  defstruct [
    :schema_version,
    :request_id,
    :correlation_id,
    :status,
    :tool_name,
    :output,
    execution: %{},
    diagnostics: [],
    metadata: %{}
  ]

  @type status :: :ok | :degraded | :fallback | :error

  @type t :: %__MODULE__{
          schema_version: String.t(),
          request_id: String.t(),
          correlation_id: String.t(),
          status: status(),
          tool_name: String.t(),
          output: map() | nil,
          execution: map(),
          diagnostics: [map()],
          metadata: map()
        }

  @doc "The result envelope `schema_version` this module emits."
  @spec schema_version() :: String.t()
  def schema_version, do: @schema_version

  @spec ok(map()) :: t()
  def ok(attrs), do: build(attrs, :ok)

  @spec fallback(map()) :: t()
  def fallback(attrs), do: build(attrs, :fallback)

  @spec error(map()) :: t()
  def error(attrs), do: build(attrs, :error)

  defp build(attrs, status) when is_map(attrs) do
    %__MODULE__{
      schema_version: Map.get(attrs, :schema_version, @schema_version),
      request_id: Map.fetch!(attrs, :request_id),
      correlation_id: Map.fetch!(attrs, :correlation_id),
      status: status,
      tool_name: Map.fetch!(attrs, :tool_name),
      output: Map.get(attrs, :output),
      execution: Map.get(attrs, :execution, %{}),
      diagnostics: Map.get(attrs, :diagnostics, []),
      metadata: Map.get(attrs, :metadata, %{})
    }
  end
end
