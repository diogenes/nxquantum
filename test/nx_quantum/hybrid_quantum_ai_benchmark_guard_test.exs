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
    assert content =~ "dataset_id"
    assert content =~ "--dataset-path"
  end

  test "hybrid benchmark report contract includes baseline and caveat fields" do
    content = File.read!(Path.join(@bench_dir, "hybrid_quantum_ai_benchmark.exs"))
    report_content = File.read!(Path.join(@bench_dir, "hybrid_quantum_ai_report.exs"))
    assert content =~ "baseline_metrics"
    assert content =~ "delta_metrics"
    assert content =~ "fallback_rate"
    assert content =~ "caveats"
    assert content =~ "memory_bytes_per_vector"
    assert content =~ "compression_ratio_vs_fp32"
    assert report_content =~ "compression_ratio_vs_fp32"
  end

  test "rerank dataset files are present for benchmark and user dataset onboarding" do
    rerank_dir = Path.join(@bench_dir, "datasets/rerank")
    assert File.exists?(Path.join(rerank_dir, "rq_small_v1.csv"))
    assert File.exists?(Path.join(rerank_dir, "rq_medium_v1.csv"))
    assert File.exists?(Path.join(rerank_dir, "rq_small_v1.manifest.json"))
    assert File.exists?(Path.join(rerank_dir, "rq_medium_v1.manifest.json"))

    small_manifest = File.read!(Path.join(rerank_dir, "rq_small_v1.manifest.json"))
    assert small_manifest =~ ~s("dataset_id": "rq_small_v1")
    assert small_manifest =~ "\"sha256\""
  end
end
