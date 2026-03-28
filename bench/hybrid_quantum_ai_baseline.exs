scenario = List.first(System.argv()) || "latency_fallback_impact"

baseline =
  case scenario do
    "rerank_quality_delta" -> %{ndcg_at_10: 0.72, map_at_10: 0.65}
    "rerank_quality_delta_turboquant" -> %{ndcg_at_10: 0.72, map_at_10: 0.65, memory_bytes_per_vector: 512}
    "constrained_optimization_assistant" -> %{objective_gap_to_known_best: 0.18, feasible_solution_rate: 0.84}
    _ -> %{request_success_rate: 0.98, fallback_rate: 0.08, latency_p95_ms: 78.0}
  end

IO.puts("NXQ_HYBRID_BASELINE scenario=#{scenario} metrics=#{inspect(baseline)}")
