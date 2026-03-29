defmodule NxQuantum.Migration.AIGatesTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Migration.AIGates
  alias NxQuantum.Migration.AIReport

  test "evaluate/2 emits deterministic promote decision when thresholds are met" do
    evidence = %{fallback_rate: 0.02, typed_error_rate: 0.0, quality_delta: 0.12}

    assert {:ok, promote_a} = AIGates.evaluate(evidence)
    assert {:ok, promote_b} = AIGates.evaluate(evidence)

    assert promote_a.decision == :promote
    assert promote_a.decision_id == promote_b.decision_id
    assert promote_a.code == :ok
  end

  test "evaluate/2 emits hold and rollback with typed codes" do
    assert {:ok, hold} =
             AIGates.evaluate(%{fallback_rate: 0.5, typed_error_rate: 0.01, quality_delta: 0.2},
               max_fallback_rate: 0.1
             )

    assert hold.decision == :hold
    assert hold.code == :fallback_rate_exceeded

    assert {:ok, rollback} =
             AIGates.evaluate(%{fallback_rate: 0.01, typed_error_rate: 0.2, quality_delta: 0.5},
               max_error_rate: 0.05
             )

    assert rollback.decision == :rollback
    assert rollback.code == :typed_error_rate_exceeded
  end

  test "evaluate/2 enforces TurboQuant production thresholds when metrics are required" do
    promote_evidence = %{
      fallback_rate: 0.02,
      typed_error_rate: 0.0,
      quality_delta: 0.01,
      quantization_codec: :turboquant,
      memory_bytes_per_vector: 64,
      compression_ratio_vs_fp32: 8.0
    }

    assert {:ok, promote} = AIGates.evaluate(promote_evidence, require_turboquant_metrics: true)
    assert promote.decision == :promote
    assert promote.turboquant_metrics_required == true

    hold_evidence = %{
      fallback_rate: 0.02,
      typed_error_rate: 0.0,
      quality_delta: 0.01,
      quality_drop: 0.06,
      quantization_codec: :turboquant,
      memory_bytes_per_vector: 64,
      compression_ratio_vs_fp32: 8.0
    }

    assert {:ok, hold_quality} = AIGates.evaluate(hold_evidence, require_turboquant_metrics: true)
    assert hold_quality.decision == :hold
    assert hold_quality.code == :quality_drop_exceeded

    assert {:ok, hold_memory} =
             AIGates.evaluate(%{hold_evidence | quality_drop: 0.01, memory_bytes_per_vector: 192},
               require_turboquant_metrics: true,
               max_memory_bytes_per_vector: 96
             )

    assert hold_memory.decision == :hold
    assert hold_memory.code == :memory_bytes_per_vector_exceeded

    assert {:ok, hold_compression} =
             AIGates.evaluate(
               %{
                 hold_evidence
                 | quality_drop: 0.01,
                   memory_bytes_per_vector: 64,
                   compression_ratio_vs_fp32: 1.5
               },
               require_turboquant_metrics: true,
               min_compression_ratio: 4.0
             )

    assert hold_compression.decision == :hold
    assert hold_compression.code == :compression_ratio_below_threshold
  end

  test "evaluate/2 emits hold when required TurboQuant metrics are missing" do
    assert {:ok, hold_missing} =
             AIGates.evaluate(%{fallback_rate: 0.01, typed_error_rate: 0.0, quality_delta: 0.1},
               require_turboquant_metrics: true
             )

    assert hold_missing.decision == :hold
    assert hold_missing.code == :turboquant_metrics_missing
  end

  test "AI report map is machine-readable and stable" do
    request = %{request_id: "req-99", correlation_id: "corr-99", tool_name: "quantum-kernel reranking"}
    evidence = %{fallback_rate: 0.02, typed_error_rate: 0.0, quality_delta: 0.12}
    {:ok, decision} = AIGates.evaluate(evidence)

    report = AIReport.to_map(request, evidence, decision)
    assert report.schema_version == "v1"
    assert report.request_id == "req-99"
    assert report.decision.decision in [:promote, :hold, :rollback]
  end
end
