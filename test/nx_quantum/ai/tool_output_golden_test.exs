defmodule NxQuantum.AI.ToolOutputGoldenTest do
  # KG-12 golden test: the bundled AI handlers return the same output for the same input
  # and seed. Each scenario runs three times: twice in this process and once in a fresh
  # process. The rerank path runs its TurboQuant dot products with `max_concurrency` set
  # from `System.schedulers_online()`, so the fresh-process run also checks that the
  # ordering does not depend on how work is scheduled. Requests use a fixed `request_id`,
  # since the output echoes it. Acceptance is exact equality: the classical path is
  # deterministic, so no tolerance applies.
  use ExUnit.Case, async: true

  alias NxQuantum.AI

  @provider_capabilities %{supports_kernel_rerank: true, supports_constrained_optimize: true, provider: :ibm}

  @embedding_input %{
    candidate_ids: ["c1", "c2", "c3", "c4"],
    query_embedding: [0.8, 0.1, -0.2, 0.5],
    candidate_embeddings: %{
      "c1" => [0.9, 0.0, -0.3, 0.6],
      "c2" => [0.1, 0.6, 0.8, -0.2],
      "c3" => [0.7, 0.2, -0.1, 0.4],
      "c4" => [0.3, 0.3, 0.3, 0.3]
    },
    quantization: %{codec: :turboquant, mode: :mse, bit_width: 3, seed: 1234}
  }

  @optimize_input %{
    candidate_solutions: [
      %{id: "s1", feasible: true, cost: 10.0},
      %{id: "s2", feasible: true, cost: 3.0},
      %{id: "s3", feasible: false, cost: 1.0},
      %{id: "s4", feasible: true, cost: 3.0}
    ]
  }

  test "rerank over caller scores gives the same output for the same input" do
    input = %{candidate_ids: ["b", "a", "c"], scores: %{"a" => 0.8, "b" => 0.3, "c" => 0.8}}
    assert_golden("quantum-kernel reranking", input)
  end

  test "rerank over TurboQuant embeddings with a fixed seed gives the same output" do
    assert_golden("quantum_kernel_rerank.v1", @embedding_input)
  end

  test "constrained optimization gives the same output for the same input" do
    assert_golden("constrained optimization helper", @optimize_input)
  end

  defp assert_golden(tool_name, input) do
    first = run(tool_name, input)
    second = run(tool_name, input)
    task = Task.async(fn -> run(tool_name, input) end)
    fresh_process = Task.await(task)

    assert {:ok, %{status: status}} = first
    assert status in [:ok, :fallback]
    assert first == second
    assert first == fresh_process
  end

  defp run(tool_name, input) do
    AI.run_tool(request(tool_name, input), provider_capabilities: @provider_capabilities)
  end

  defp request(tool_name, input) do
    %{
      schema_version: "v1",
      request_id: "req-golden-#{tool_name}",
      correlation_id: "corr-golden",
      tool_name: tool_name,
      input: input,
      execution_policy: %{fallback_policy: :strict}
    }
  end
end
