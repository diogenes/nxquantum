defmodule NxQuantum.HybridQuantumAIBenchmarkGuardTest do
  use ExUnit.Case, async: true

  @bench_dir Path.expand("../../bench", __DIR__)

  test "hybrid benchmark scripts exist and expose required scenario ids" do
    benchmark_script = Path.join(@bench_dir, "hybrid_quantum_ai_benchmark.exs")
    baseline_script = Path.join(@bench_dir, "hybrid_quantum_ai_baseline.exs")
    report_script = Path.join(@bench_dir, "hybrid_quantum_ai_report.exs")
    turboquant_script = Path.join(@bench_dir, "turboquant_rerank_benchmark.exs")

    assert File.exists?(benchmark_script)
    assert File.exists?(baseline_script)
    assert File.exists?(report_script)
    assert File.exists?(turboquant_script)

    content = File.read!(benchmark_script)
    assert content =~ "rerank_quality_delta"
    assert content =~ "rerank_quality_delta_turboquant"
    assert content =~ "constrained_optimization_assistant"
    assert content =~ "latency_fallback_impact"
  end

  test "hybrid benchmark report contract includes baseline and caveat fields" do
    content = File.read!(Path.join(@bench_dir, "hybrid_quantum_ai_benchmark.exs"))
    assert content =~ "baseline_metrics"
    assert content =~ "delta_metrics"
    assert content =~ "fallback_rate"
    assert content =~ "caveats"
    assert content =~ "memory_bytes_per_vector"
  end
end
