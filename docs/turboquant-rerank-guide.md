# TurboQuant Rerank Guide

## Purpose

Use deterministic TurboQuant-inspired compression in `NxQuantum.AI` rerank flows to reduce vector-memory footprint and leverage BEAM parallel scoring.

## Scope Boundary

1. Supported scope:
   - AI reranking input path (`quantum-kernel reranking` and `quantum_kernel_rerank.v1`).
2. Not supported:
   - state-vector simulator core quantization.
   - circuit execution kernels.

## Request Shape

TurboQuant is used when `scores` are not provided and embedding inputs are present:

```elixir
request = %{
  schema_version: "v1",
  request_id: "req-1",
  correlation_id: "corr-1",
  tool_name: "quantum_kernel_rerank.v1",
  input: %{
    candidate_ids: ["d1", "d2", "d3"],
    query_embedding: [0.8, 0.1, -0.2, 0.5],
    candidate_embeddings: %{
      "d1" => [0.9, 0.0, -0.3, 0.6],
      "d2" => [0.1, 0.6, 0.8, -0.2],
      "d3" => [0.7, 0.2, -0.1, 0.4]
    },
    quantization: %{
      codec: :turboquant,
      mode: :prod_unbiased,
      bit_width: 4,
      seed: 20260328,
      parallel_mode: :auto,
      max_concurrency: System.schedulers_online()
    }
  },
  execution_policy: %{fallback_policy: :strict}
}

{:ok, result} = NxQuantum.AI.run_tool(request)
```

## Bring Your Own Dataset (CSV)

You can supply a local CSV dataset instead of in-memory embedding maps.

Required columns:

1. `query_id`
2. `candidate_id`
3. `query_embedding` (pipe-delimited float list, e.g. `0.1|0.2|0.3`)
4. `candidate_embedding` (pipe-delimited float list)

Optional columns are ignored (for example `label`, `classical_score`).

```elixir
request = %{
  schema_version: "v1",
  request_id: "req-dataset-1",
  correlation_id: "corr-dataset-1",
  tool_name: "quantum_kernel_rerank.v1",
  input: %{
    dataset_path: "bench/datasets/rerank/rq_small_v1.csv",
    query_id: "q-1",
    candidate_ids: ["d-2", "d-1", "d-3"],
    quantization: %{codec: :turboquant, mode: :prod_unbiased, bit_width: 4, seed: 20260329}
  },
  execution_policy: %{fallback_policy: :strict}
}

{:ok, result} = NxQuantum.AI.run_tool(request)
```

## Determinism Rules

1. Fix `seed` for repeated experiments.
2. Keep identical `candidate_ids` ordering when comparing runs.
3. Use fixed datasets and fixed quantization parameters in benchmark runs.
4. Parallel mode preserves deterministic ordering (`Task.async_stream` with `ordered: true`).

## Parallel Processing Guidance

1. `parallel_mode: :auto` chooses scalar or parallel based on workload.
2. `parallel_mode: :force_scalar` is useful for debugging/reference runs.
3. `parallel_mode: :force_parallel` maximizes BEAM scheduler usage.
4. Set `max_concurrency` explicitly in CI for stable performance comparisons.

## Benchmark Commands

```bash
mise exec -- mix run bench/hybrid_quantum_ai_benchmark.exs rerank_quality_delta_turboquant
mise exec -- mix run bench/turboquant_rerank_benchmark.exs
```

The TurboQuant-specific benchmark output includes:

1. `latency_ms`
2. `memory_bytes_per_vector`
3. `compression_ratio_vs_fp32`
4. deterministic top-k lane parity (`scalar` vs `parallel`)
5. cache and strategy diagnostics in tool metadata (`cache_hit`, `strategy_reason`, `estimated_work`)

## Rollout Gate Evidence Mapping

For production promotion checks using `NxQuantum.Migration.AIGates.evaluate/2`, include:

1. `fallback_rate`
2. `typed_error_rate`
3. `quality_delta`
4. `quality_drop` (or omit and let gates derive from `quality_delta`)
5. `memory_bytes_per_vector`
6. `compression_ratio_vs_fp32`

Recommended options:

1. `require_turboquant_metrics: true`
2. `max_quality_drop: 0.05`
3. `max_memory_bytes_per_vector: 96`
4. `min_compression_ratio: 4.0`
