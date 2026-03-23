defmodule NxQuantum.Observability.Schema do
  @moduledoc false

  @required_lifecycle_spans [
    "nxq.workflow.run",
    "nxq.provider.submit",
    "nxq.provider.poll",
    "nxq.provider.fetch_result"
  ]

  @required_metric_names [
    "nxq.provider.request.latency_ms",
    "nxq.workflow.success.count"
  ]

  @required_log_keys [:event, :level, :trace_id, :span_id, :provider, :target, :workflow, :message]

  @allowed_high_level_label_keys [:provider, :target, :workflow, :visibility_profile]

  @sensitive_markers ["token", "secret", "credential", "authorization"]

  @spec validate_snapshot(map(), atom()) :: :ok | {:error, map()}
  def validate_snapshot(snapshot, profile) when profile in [:high_level, :granular, :forensics] do
    with :ok <- validate_span_names(snapshot),
         :ok <- validate_metric_names(snapshot),
         :ok <- validate_logs(snapshot),
         :ok <- validate_redaction(snapshot) do
      validate_profile_constraints(snapshot, profile)
    end
  end

  def validate_snapshot(_snapshot, profile) do
    {:error, %{code: :observability_invalid_profile, profile: profile}}
  end

  defp validate_span_names(%{spans: spans}) when is_list(spans) do
    names = spans |> Enum.filter(&(&1.event == :start)) |> Enum.map(& &1.name)
    missing = Enum.reject(@required_lifecycle_spans, &(&1 in names))

    if missing == [] do
      :ok
    else
      {:error, %{code: :observability_missing_spans, missing: missing}}
    end
  end

  defp validate_span_names(_), do: {:error, %{code: :observability_invalid_snapshot, field: :spans}}

  defp validate_metric_names(%{metrics: metrics}) when is_list(metrics) do
    names = Enum.map(metrics, & &1.name)
    missing = Enum.reject(@required_metric_names, &(&1 in names))

    if missing == [] do
      :ok
    else
      {:error, %{code: :observability_missing_metrics, missing: missing}}
    end
  end

  defp validate_metric_names(_), do: {:error, %{code: :observability_invalid_snapshot, field: :metrics}}

  defp validate_logs(%{logs: logs}) when is_list(logs) do
    case Enum.find(logs, fn log -> Enum.any?(@required_log_keys, &(not Map.has_key?(log, &1))) end) do
      nil -> :ok
      log -> {:error, %{code: :observability_missing_log_fields, log: log}}
    end
  end

  defp validate_logs(_), do: {:error, %{code: :observability_invalid_snapshot, field: :logs}}

  defp validate_redaction(%{logs: logs, metrics: metrics}) do
    bad_log = Enum.find(logs, &contains_sensitive?/1)
    bad_metric = Enum.find(metrics, &contains_sensitive?/1)

    cond do
      bad_log -> {:error, %{code: :observability_sensitive_log_field, entry: bad_log}}
      bad_metric -> {:error, %{code: :observability_sensitive_metric_field, entry: bad_metric}}
      true -> :ok
    end
  end

  defp validate_redaction(_), do: {:error, %{code: :observability_invalid_snapshot, field: :redaction}}

  defp validate_profile_constraints(%{metrics: metrics}, :high_level) do
    case Enum.find(metrics, fn metric ->
           labels = Map.get(metric, :labels, %{})
           Enum.any?(Map.keys(labels), &(&1 not in @allowed_high_level_label_keys))
         end) do
      nil -> :ok
      metric -> {:error, %{code: :observability_cardinality_violation, metric: metric}}
    end
  end

  defp validate_profile_constraints(_snapshot, _profile), do: :ok

  defp contains_sensitive?(value) when is_map(value) do
    Enum.any?(value, fn {key, nested} -> sensitive_key?(key) or contains_sensitive?(nested) end)
  end

  defp contains_sensitive?(value) when is_list(value), do: Enum.any?(value, &contains_sensitive?/1)
  defp contains_sensitive?(_), do: false

  defp sensitive_key?(key) when is_atom(key), do: sensitive_key?(Atom.to_string(key))

  defp sensitive_key?(key) when is_binary(key) do
    lowered = String.downcase(key)
    Enum.any?(@sensitive_markers, &String.contains?(lowered, &1))
  end

  defp sensitive_key?(_), do: false
end
