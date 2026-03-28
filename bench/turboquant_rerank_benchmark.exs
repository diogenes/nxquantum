alias NxQuantum.AI

seed = 20260328
bit_width = 4

query_embedding = Enum.map(1..128, fn i -> :math.sin(i / 13.0) end)
candidate_ids = Enum.map(1..128, &"c#{&1}")

candidate_embeddings =
  Map.new(candidate_ids, fn id ->
    idx = String.to_integer(String.replace_prefix(id, "c", ""))
    {id, Enum.map(1..128, fn j -> :math.cos((idx + j) / 17.0) end)}
  end)

run_lane = fn lane, parallel_mode, max_concurrency ->
  request = %{
    schema_version: "v1",
    request_id: "req-turboquant-#{lane}",
    correlation_id: "corr-turboquant-#{lane}",
    tool_name: "quantum_kernel_rerank.v1",
    input: %{
      candidate_ids: candidate_ids,
      query_embedding: query_embedding,
      candidate_embeddings: candidate_embeddings,
      quantization: %{
        codec: :turboquant,
        mode: :prod_unbiased,
        bit_width: bit_width,
        seed: seed,
        parallel_mode: parallel_mode,
        max_concurrency: max_concurrency
      }
    },
    execution_policy: %{fallback_policy: :strict}
  }

  started_ns = System.monotonic_time()
  {:ok, result} = AI.run_tool(request, provider_capabilities: %{supports_kernel_rerank: true})
  elapsed_ms = System.convert_time_unit(System.monotonic_time() - started_ns, :native, :millisecond)

  %{
    lane: lane,
    status: result.status,
    ranked_top_10: result.output.ranked_candidate_ids |> Enum.take(10),
    latency_ms: elapsed_ms,
    bit_width: bit_width,
    vector_dim: 128,
    candidate_count: 128,
    memory_bytes_per_vector: div(128 * bit_width, 8),
    compression_ratio_vs_fp32: Float.round((128 * 4.0) / max(1.0, div(128 * bit_width, 8)), 3)
  }
end

scalar = run_lane.(:scalar, :force_scalar, 1)
parallel = run_lane.(:parallel, :force_parallel, System.schedulers_online())

output = %{
  schema_version: "v1",
  benchmark: "turboquant_rerank",
  seed: seed,
  lanes: [scalar, parallel],
  deterministic_match: scalar.ranked_top_10 == parallel.ranked_top_10
}

IO.puts("NXQ_TURBOQUANT_BENCH #{inspect(output)}")
