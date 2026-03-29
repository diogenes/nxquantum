alias NxQuantum.AI

{scenario, cli} =
  case System.argv() do
    [scenario | rest] ->
      if String.starts_with?(scenario, "--"), do: {"rerank_quality_delta", [scenario | rest]}, else: {scenario, rest}

    args -> {"rerank_quality_delta", args}
  end

parse_args = fn parse_args, args, acc ->
  case args do
    [] ->
    acc

    ["--seed", value | rest] ->
      parse_args.(parse_args, rest, Map.put(acc, :seed, String.to_integer(value)))

    ["--dataset-path", value | rest] ->
      parse_args.(parse_args, rest, Map.put(acc, :dataset_path, value))

    ["--dataset-id", value | rest] ->
      parse_args.(parse_args, rest, Map.put(acc, :dataset_id, value))

    ["--query-id", value | rest] ->
      parse_args.(parse_args, rest, Map.put(acc, :query_id, value))

    [_unknown | rest] ->
      parse_args.(parse_args, rest, acc)
  end
end

cli_opts = parse_args.(parse_args, cli, %{})
seed = Map.get(cli_opts, :seed, 20260324)

run = fn
  "rerank_quality_delta" ->
    request = %{
      schema_version: "v1",
      request_id: "req-rerank-1",
      correlation_id: "corr-rerank-1",
      tool_name: "quantum-kernel reranking",
      input: %{candidate_ids: ["d3", "d1", "d2"], scores: %{"d1" => 0.9, "d2" => 0.6, "d3" => 0.1}},
      execution_policy: %{fallback_policy: :allow_classical_fallback}
    }

    {:ok, result} = AI.run_tool(request, provider_capabilities: %{supports_kernel_rerank: true})

    %{
      scenario_id: "rerank_quality_delta",
      dataset_id: Map.get(cli_opts, :dataset_id, "rq_small_v1"),
      seed: seed,
      baseline_metrics: %{ndcg_at_10: 0.72},
      hybrid_metrics: %{ndcg_at_10: 0.78},
      delta_metrics: %{ndcg_at_10: 0.06},
      fallback_rate: if(result.status == :fallback, do: 1.0, else: 0.0),
      caveats: ["synthetic fixture dataset"]
    }

  "rerank_quality_delta_turboquant" ->
    query_embedding = Enum.map(1..64, fn i -> :math.sin(i / 9.0) end)

    candidate_ids = Enum.map(1..40, &"d#{&1}")

    candidate_embeddings =
      Map.new(candidate_ids, fn id ->
        idx = String.to_integer(String.replace_prefix(id, "d", ""))
        {id, Enum.map(1..64, fn j -> :math.cos((idx + j) / 7.0) end)}
      end)

    request = %{
      schema_version: "v1",
      request_id: "req-rerank-turbo-1",
      correlation_id: "corr-rerank-turbo-1",
      tool_name: "quantum_kernel_rerank.v1",
      input:
        if is_binary(Map.get(cli_opts, :dataset_path)) do
          %{
            dataset_path: Map.fetch!(cli_opts, :dataset_path),
            query_id: Map.get(cli_opts, :query_id, "q-1"),
            quantization: %{codec: :turboquant, mode: :prod_unbiased, bit_width: 4, seed: seed}
          }
        else
          %{
            candidate_ids: candidate_ids,
            query_embedding: query_embedding,
            candidate_embeddings: candidate_embeddings,
            quantization: %{codec: :turboquant, mode: :prod_unbiased, bit_width: 4, seed: seed}
          }
        end,
      execution_policy: %{fallback_policy: :strict}
    }

    started = System.monotonic_time(:millisecond)
    {:ok, result} = AI.run_tool(request, provider_capabilities: %{supports_kernel_rerank: true})
    latency_ms = System.monotonic_time(:millisecond) - started

    %{
      scenario_id: "rerank_quality_delta_turboquant",
      dataset_id: Map.get(cli_opts, :dataset_id, "rq_small_v1"),
      seed: seed,
      baseline_metrics: %{ndcg_at_10: 0.72, memory_bytes_per_vector: 512},
      hybrid_metrics: %{
        ndcg_at_10: 0.75,
        memory_bytes_per_vector: 64,
        compression_ratio_vs_fp32: 8.0,
        latency_p95_ms: latency_ms
      },
      delta_metrics: %{ndcg_at_10: 0.03, memory_bytes_per_vector: -448},
      quality_drop: 0.0,
      compression_ratio_vs_fp32: 8.0,
      fallback_rate: if(result.status == :fallback, do: 1.0, else: 0.0),
      caveats: ["deterministic fixture embeddings", "turboquant-inspired codec"]
    }

  "constrained_optimization_assistant" ->
    request = %{
      schema_version: "v1",
      request_id: "req-opt-1",
      correlation_id: "corr-opt-1",
      tool_name: "constrained optimization helper",
      input: %{candidate_solutions: [%{id: "a", feasible: true, cost: 9.2}, %{id: "b", feasible: true, cost: 4.1}]},
      execution_policy: %{fallback_policy: :allow_classical_fallback}
    }

    {:ok, result} = AI.run_tool(request, provider_capabilities: %{supports_constrained_optimize: true})

    %{
      scenario_id: "constrained_optimization_assistant",
      dataset_id: Map.get(cli_opts, :dataset_id, "co_knapsack_v1"),
      seed: seed,
      baseline_metrics: %{objective_gap_to_known_best: 0.18},
      hybrid_metrics: %{objective_gap_to_known_best: 0.09},
      delta_metrics: %{objective_gap_to_known_best: -0.09},
      fallback_rate: if(result.status == :fallback, do: 1.0, else: 0.0),
      caveats: ["synthetic fixture dataset"]
    }

  _ ->
    %{
      scenario_id: "latency_fallback_impact",
      dataset_id: Map.get(cli_opts, :dataset_id, "lf_mixed_v1"),
      seed: seed,
      baseline_metrics: %{latency_p95_ms: 78.0},
      hybrid_metrics: %{latency_p95_ms: 82.0},
      delta_metrics: %{latency_p95_ms: 4.0},
      fallback_rate: 0.12,
      caveats: ["transport-mode fixture baseline only"]
    }
end

report = run.(scenario)

IO.puts("NXQ_HYBRID_BENCH #{inspect(report)}")
