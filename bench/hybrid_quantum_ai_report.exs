input = List.first(System.argv()) || "tmp/hybrid_bench"
output = List.last(System.argv()) || "tmp/hybrid_report.txt"

content = """
schema_version: v1
report_kind: hybrid_quantum_ai
input: #{input}
summary:
  - all metrics include classical baseline references
  - fallback behavior is explicitly tracked
  - caveats are required for every scenario
  - turboquant rerank scenarios include memory-per-vector and bit-width evidence
required_fields:
  - scenario_id
  - baseline_metrics
  - hybrid_metrics
  - delta_metrics
  - fallback_rate
  - memory_bytes_per_vector (turboquant lanes)
  - compression_ratio_vs_fp32 (turboquant lanes)
  - quality_drop (or derivable from quality_delta)
  - caveats
"""

File.mkdir_p!(Path.dirname(output))
File.write!(output, content)
IO.puts("NXQ_HYBRID_REPORT output=#{output}")
