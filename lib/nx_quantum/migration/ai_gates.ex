defmodule NxQuantum.Migration.AIGates do
  @moduledoc """
  Deterministic rollout gate decisions for hybrid quantum-AI workflows.
  """

  @type decision :: :promote | :hold | :rollback

  @spec evaluate(map(), keyword()) :: {:ok, map()} | {:error, map()}
  def evaluate(evidence, opts \\ []) when is_map(evidence) and is_list(opts) do
    with :ok <- validate_inputs(evidence) do
      thresholds = threshold_snapshot(opts)
      snapshot = evidence_snapshot(evidence, thresholds.require_turboquant_metrics)
      {decision, code} = decide(snapshot, thresholds)
      payload = build_payload(evidence, decision, code, thresholds, snapshot)

      {:ok, payload}
    end
  end

  defp validate_inputs(evidence) do
    required = [:fallback_rate, :typed_error_rate, :quality_delta]
    missing = Enum.reject(required, &Map.has_key?(evidence, &1))

    if missing == [] do
      :ok
    else
      {:error, %{code: :ai_rollout_invalid_input, missing: missing}}
    end
  end

  defp turboquant_metrics_required?(evidence, require_turboquant_metrics) do
    require_turboquant_metrics or
      Map.get(evidence, :quantization_codec) == :turboquant or
      Map.has_key?(evidence, :memory_bytes_per_vector) or
      Map.has_key?(evidence, :compression_ratio_vs_fp32)
  end

  defp threshold_snapshot(opts) do
    %{
      max_fallback_rate: Keyword.get(opts, :max_fallback_rate, 0.10),
      max_error_rate: Keyword.get(opts, :max_error_rate, 0.05),
      min_quality_delta: Keyword.get(opts, :min_quality_delta, 0.0),
      max_quality_drop: Keyword.get(opts, :max_quality_drop, 0.05),
      max_memory_bytes_per_vector: Keyword.get(opts, :max_memory_bytes_per_vector, 96),
      min_compression_ratio: Keyword.get(opts, :min_compression_ratio, 4.0),
      require_turboquant_metrics: Keyword.get(opts, :require_turboquant_metrics, false)
    }
  end

  defp evidence_snapshot(evidence, require_turboquant_metrics) do
    quality_delta = Map.get(evidence, :quality_delta, 0.0)
    memory_bytes_per_vector = Map.get(evidence, :memory_bytes_per_vector)
    compression_ratio = Map.get(evidence, :compression_ratio_vs_fp32)
    turboquant_required = turboquant_metrics_required?(evidence, require_turboquant_metrics)

    %{
      fallback_rate: Map.get(evidence, :fallback_rate, 0.0),
      typed_error_rate: Map.get(evidence, :typed_error_rate, 0.0),
      quality_delta: quality_delta,
      quality_drop: Map.get(evidence, :quality_drop, max(0.0, -quality_delta)),
      memory_bytes_per_vector: memory_bytes_per_vector,
      compression_ratio_vs_fp32: compression_ratio,
      turboquant_metrics_required: turboquant_required,
      turboquant_metrics_present: is_number(memory_bytes_per_vector) and is_number(compression_ratio)
    }
  end

  defp decide(snapshot, thresholds) do
    checks = [
      &check_typed_error/2,
      &check_fallback_rate/2,
      &check_quality_delta/2,
      &check_turboquant_metrics_presence/2,
      &check_quality_drop/2,
      &check_memory_bytes_per_vector/2,
      &check_compression_ratio/2
    ]

    Enum.find_value(checks, {:promote, :ok}, fn check ->
      check.(snapshot, thresholds)
    end)
  end

  defp build_payload(evidence, decision, code, thresholds, snapshot) do
    %{
      schema_version: "v1",
      decision: decision,
      decision_id: decision_id(evidence, decision),
      threshold_snapshot: thresholds,
      evidence_digest: evidence_digest(evidence),
      evidence_snapshot: Map.drop(snapshot, [:turboquant_metrics_required, :turboquant_metrics_present]),
      turboquant_metrics_required: snapshot.turboquant_metrics_required,
      code: code
    }
  end

  defp check_typed_error(snapshot, thresholds) do
    if snapshot.typed_error_rate > thresholds.max_error_rate do
      {:rollback, :typed_error_rate_exceeded}
    end
  end

  defp check_fallback_rate(snapshot, thresholds) do
    if snapshot.fallback_rate > thresholds.max_fallback_rate do
      {:hold, :fallback_rate_exceeded}
    end
  end

  defp check_quality_delta(snapshot, thresholds) do
    if snapshot.quality_delta < thresholds.min_quality_delta do
      {:hold, :quality_delta_below_threshold}
    end
  end

  defp check_turboquant_metrics_presence(snapshot, _thresholds) do
    if snapshot.turboquant_metrics_required and not snapshot.turboquant_metrics_present do
      {:hold, :turboquant_metrics_missing}
    end
  end

  defp check_quality_drop(snapshot, thresholds) do
    if snapshot.turboquant_metrics_required and snapshot.quality_drop > thresholds.max_quality_drop do
      {:hold, :quality_drop_exceeded}
    end
  end

  defp check_memory_bytes_per_vector(snapshot, thresholds) do
    if snapshot.turboquant_metrics_required and
         snapshot.memory_bytes_per_vector > thresholds.max_memory_bytes_per_vector do
      {:hold, :memory_bytes_per_vector_exceeded}
    end
  end

  defp check_compression_ratio(snapshot, thresholds) do
    if snapshot.turboquant_metrics_required and
         snapshot.compression_ratio_vs_fp32 < thresholds.min_compression_ratio do
      {:hold, :compression_ratio_below_threshold}
    end
  end

  defp decision_id(evidence, decision) do
    digest =
      :sha256
      |> :crypto.hash(:erlang.term_to_binary({evidence, decision}, [:deterministic]))
      |> Base.encode16(case: :lower)
      |> binary_part(0, 12)

    "ai_gate_#{digest}"
  end

  defp evidence_digest(evidence) do
    :sha256
    |> :crypto.hash(:erlang.term_to_binary(evidence, [:deterministic]))
    |> Base.encode16(case: :lower)
  end
end
