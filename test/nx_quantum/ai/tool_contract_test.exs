defmodule NxQuantum.AI.ToolContractTest do
  use ExUnit.Case, async: true

  alias NxQuantum.AI

  test "quantum-kernel reranking handler returns deterministic typed result" do
    req = %{
      schema_version: "v1",
      request_id: "req-1",
      correlation_id: "corr-1",
      tool_name: "quantum-kernel reranking",
      input: %{candidate_ids: ["b", "a", "c"], scores: %{"a" => 0.8, "b" => 0.3, "c" => 0.8}},
      execution_policy: %{fallback_policy: :strict}
    }

    assert {:ok, result} = AI.run_tool(req, provider_capabilities: %{supports_kernel_rerank: true})
    assert result.status == :ok
    assert result.output.ranked_candidate_ids == ["a", "c", "b"]
  end

  test "versioned rerank handler supports quantized embedding mode with deterministic output" do
    req = %{
      schema_version: "v1",
      request_id: "req-1b",
      correlation_id: "corr-1b",
      tool_name: "quantum_kernel_rerank.v1",
      input: %{
        candidate_ids: ["c1", "c2", "c3"],
        query_embedding: [0.8, 0.1, -0.2, 0.5],
        candidate_embeddings: %{
          "c1" => [0.9, 0.0, -0.3, 0.6],
          "c2" => [0.1, 0.6, 0.8, -0.2],
          "c3" => [0.7, 0.2, -0.1, 0.4]
        },
        quantization: %{codec: :turboquant, mode: :mse, bit_width: 3, seed: 1234}
      },
      execution_policy: %{fallback_policy: :strict}
    }

    assert {:ok, first} = AI.run_tool(req, provider_capabilities: %{supports_kernel_rerank: true})
    assert {:ok, second} = AI.run_tool(req, provider_capabilities: %{supports_kernel_rerank: true})
    assert first.status == :ok
    assert first.output.ranked_candidate_ids == second.output.ranked_candidate_ids
    assert first.metadata.ranking.quantization_codec == :turboquant
  end

  test "parallel and scalar quantized lanes preserve deterministic ranking order" do
    base_input = %{
      candidate_ids: Enum.map(1..40, &"d#{&1}"),
      query_embedding: Enum.map(1..64, fn i -> :math.sin(i / 5.0) end),
      candidate_embeddings:
        Map.new(1..40, fn i ->
          {"d#{i}", Enum.map(1..64, fn j -> :math.cos((i + j) / 7.0) end)}
        end)
    }

    scalar_req = %{
      schema_version: "v1",
      request_id: "req-1c-scalar",
      correlation_id: "corr-1c",
      tool_name: "quantum_kernel_rerank.v1",
      input:
        Map.put(base_input, :quantization, %{
          codec: :turboquant,
          mode: :prod_unbiased,
          bit_width: 4,
          seed: 2026,
          parallel_mode: :force_scalar
        }),
      execution_policy: %{fallback_policy: :strict}
    }

    parallel_req = %{
      schema_version: "v1",
      request_id: "req-1c-parallel",
      correlation_id: "corr-1c",
      tool_name: "quantum_kernel_rerank.v1",
      input:
        Map.put(base_input, :quantization, %{
          codec: :turboquant,
          mode: :prod_unbiased,
          bit_width: 4,
          seed: 2026,
          parallel_mode: :force_parallel,
          max_concurrency: 4
        }),
      execution_policy: %{fallback_policy: :strict}
    }

    assert {:ok, scalar_result} = AI.run_tool(scalar_req, provider_capabilities: %{supports_kernel_rerank: true})
    assert {:ok, parallel_result} = AI.run_tool(parallel_req, provider_capabilities: %{supports_kernel_rerank: true})
    assert scalar_result.output.ranked_candidate_ids == parallel_result.output.ranked_candidate_ids
  end

  test "quantized rerank metadata includes cache and compression diagnostics" do
    cache_table = :ets.new(:nxq_kernel_rerank_cache_test, [:set, :public])

    request = %{
      schema_version: "v1",
      request_id: "req-cache-1",
      correlation_id: "corr-cache-1",
      tool_name: "quantum_kernel_rerank.v1",
      input: %{
        candidate_ids: ["x1", "x2", "x3", "x4"],
        query_embedding: [0.2, 0.7, -0.1, 0.5],
        candidate_embeddings: %{
          "x1" => [0.1, 0.8, -0.2, 0.4],
          "x2" => [0.3, 0.4, 0.5, -0.1],
          "x3" => [-0.3, 0.2, 0.7, 0.1],
          "x4" => [0.6, -0.2, 0.1, 0.7]
        },
        quantization: %{
          codec: :turboquant,
          mode: :prod_unbiased,
          bit_width: 4,
          seed: 20_260_329,
          calibration_id: "calib-rerank-v1"
        }
      },
      execution_policy: %{fallback_policy: :strict}
    }

    assert {:ok, first} =
             AI.run_tool(
               request,
               provider_capabilities: %{supports_kernel_rerank: true},
               quantized_batch_cache: cache_table
             )

    assert {:ok, second} =
             AI.run_tool(
               request,
               provider_capabilities: %{supports_kernel_rerank: true},
               quantized_batch_cache: cache_table
             )

    assert first.metadata.ranking.quantization_codec == :turboquant
    assert first.metadata.ranking.codec_version == "v1"
    assert first.metadata.ranking.calibration_id == "calib-rerank-v1"
    assert first.metadata.ranking.cache_hit == false
    assert second.metadata.ranking.cache_hit == true
    assert first.metadata.ranking.quantized_bytes_per_vector > 0
    assert first.metadata.ranking.compression_ratio_vs_fp32 >= 1.0
  end

  test "versioned rerank handler supports loading embeddings from dataset_path" do
    dataset_path =
      write_dataset!(
        "tool_contract_rerank_dataset.csv",
        """
        query_id,candidate_id,query_embedding,candidate_embedding,label,classical_score
        q-42,d-1,0.7|0.2|-0.1|0.9,0.8|0.1|-0.2|0.8,3,0.91
        q-42,d-2,0.7|0.2|-0.1|0.9,0.6|0.2|-0.3|0.7,2,0.77
        q-42,d-3,0.7|0.2|-0.1|0.9,0.1|0.8|0.4|-0.1,0,0.21
        """
      )

    req = %{
      schema_version: "v1",
      request_id: "req-ds-1",
      correlation_id: "corr-ds-1",
      tool_name: "quantum_kernel_rerank.v1",
      input: %{
        dataset_path: dataset_path,
        query_id: "q-42",
        candidate_ids: ["d-2", "d-1", "d-3"],
        quantization: %{codec: :turboquant, mode: :mse, bit_width: 3, seed: 20_260_329}
      },
      execution_policy: %{fallback_policy: :strict}
    }

    assert {:ok, result} = AI.run_tool(req, provider_capabilities: %{supports_kernel_rerank: true})
    assert result.status == :ok
    assert Enum.sort(result.output.ranked_candidate_ids) == ["d-1", "d-2", "d-3"]
    assert result.metadata.ranking.dataset_source == "tool_contract_rerank_dataset.csv"
    assert result.metadata.ranking.dataset_query_id == "q-42"
  end

  test "constrained optimization helper falls back deterministically when capability is unavailable" do
    req = %{
      schema_version: "v1",
      request_id: "req-2",
      correlation_id: "corr-2",
      tool_name: "constrained optimization helper",
      input: %{
        candidate_solutions: [
          %{id: "s1", feasible: true, cost: 10.0},
          %{id: "s2", feasible: true, cost: 3.0}
        ]
      },
      execution_policy: %{fallback_policy: :allow_classical_fallback}
    }

    assert {:ok, result} = AI.run_tool(req, provider_capabilities: %{supports_constrained_optimize: false})
    assert result.status == :fallback
    assert result.output.selected_solution.id == "s2"
  end

  test "unsupported handler returns typed deterministic error envelope" do
    req = %{
      schema_version: "v1",
      request_id: "req-3",
      correlation_id: "corr-3",
      tool_name: "unknown_handler",
      input: %{}
    }

    assert {:error, error} = AI.run_tool(req)
    assert error.code == :ai_tool_unsupported
    assert error.category == :capability
  end

  test "invalid quantized embedding payload falls back deterministically when fallback is allowed" do
    req = %{
      schema_version: "v1",
      request_id: "req-4",
      correlation_id: "corr-4",
      tool_name: "quantum_kernel_rerank.v1",
      input: %{
        candidate_ids: ["x", "y"],
        query_embedding: [0.1, 0.2],
        candidate_embeddings: %{"x" => [0.2, 0.1]}
      },
      execution_policy: %{fallback_policy: :allow_classical_fallback}
    }

    assert {:ok, result} = AI.run_tool(req, provider_capabilities: %{supports_kernel_rerank: true})
    assert result.status == :fallback
    assert result.output.ranked_candidate_ids == ["x", "y"]
  end

  defp write_dataset!(filename, body) do
    path = Path.join(System.tmp_dir!(), filename)
    File.write!(path, body)
    path
  end
end
