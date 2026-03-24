defmodule NxQuantum.Observability.TroubleshootingBundle do
  @moduledoc false

  @schema_version :v1
  @redaction_policy_version :v1

  @spec export(map(), keyword()) :: map()
  def export(snapshot, opts \\ []) when is_map(snapshot) and is_list(opts) do
    profile = Keyword.get(opts, :profile, :high_level)
    correlation_id = Keyword.get(opts, :correlation_id, "unknown_correlation_id")

    %{
      schema_version: @schema_version,
      redaction_policy_version: @redaction_policy_version,
      profile: profile,
      correlation_id: correlation_id,
      traces: Map.get(snapshot, :spans, []),
      logs: Map.get(snapshot, :logs, []),
      metrics: Map.get(snapshot, :metrics, [])
    }
  end
end
