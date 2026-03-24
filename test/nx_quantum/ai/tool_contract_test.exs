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
end
