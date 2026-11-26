defmodule NxQuantum.AI.ExecutionModeTruthTest do
  # KG-12: a bundled AI tool handler must report the execution mode it used.
  # The bundled handlers compute classically (sorting and TurboQuant dot products on
  # the BEAM, and a lowest-cost selection), so they must never report `:quantum`.
  # If a future handler really calls a simulator or provider, add that scenario here
  # with the mode it actually used and the module it calls.
  use ExUnit.Case, async: true

  alias NxQuantum.AI

  @bundled_handler_sources [
    "lib/nx_quantum/ai/tool_runner.ex",
    "lib/nx_quantum/ai/tools/kernel_rerank.ex"
  ]

  # Modules whose calls execute a circuit on a simulator or a provider.
  @quantum_backend_modules [
    "NxQuantum.Estimator",
    "NxQuantum.Sampler",
    "NxQuantum.Circuit",
    "NxQuantum.ProviderBridge",
    "NxQuantum.Adapters.Providers"
  ]

  @embedding_input %{
    candidate_ids: ["c1", "c2", "c3"],
    query_embedding: [0.8, 0.1, -0.2, 0.5],
    candidate_embeddings: %{
      "c1" => [0.9, 0.0, -0.3, 0.6],
      "c2" => [0.1, 0.6, 0.8, -0.2],
      "c3" => [0.7, 0.2, -0.1, 0.4]
    },
    quantization: %{codec: :turboquant, mode: :mse, bit_width: 3, seed: 1234}
  }

  test "rerank over caller scores reports the classical mode, with no provider or target" do
    assert {:ok, result} =
             AI.run_tool(
               request("quantum-kernel reranking", %{candidate_ids: ["b", "a"], scores: %{"a" => 0.8, "b" => 0.3}}),
               provider_capabilities: %{supports_kernel_rerank: true, provider: :ibm, target: "ibm_fake"}
             )

    assert result.status == :ok
    assert result.execution == %{mode: :classical, provider: :none, target: :none}
    assert result.schema_version == "v2"
  end

  test "rerank over TurboQuant embeddings reports the classical mode" do
    assert {:ok, result} =
             AI.run_tool(request("quantum_kernel_rerank.v1", @embedding_input),
               provider_capabilities: %{supports_kernel_rerank: true, provider: :ibm, target: "ibm_fake"}
             )

    assert result.status == :ok
    assert result.execution.mode == :classical
    assert result.execution.provider == :none
    assert result.execution.target == :none
    assert result.metadata.ranking.quantization_codec == :turboquant
  end

  test "rerank falls back to the fallback mode when its capability is unavailable" do
    assert {:ok, result} =
             AI.run_tool(
               request("quantum_kernel_rerank.v1", @embedding_input, :allow_classical_fallback),
               provider_capabilities: %{supports_kernel_rerank: false}
             )

    assert result.status == :fallback
    assert result.execution.mode == :classical_fallback
    assert result.schema_version == "v2"
  end

  test "constrained optimization reports the classical mode with status ok" do
    assert {:ok, result} =
             AI.run_tool(
               request("constrained optimization helper", optimize_input(), :allow_classical_fallback),
               provider_capabilities: %{supports_constrained_optimize: true, provider: :ibm}
             )

    assert result.status == :ok
    assert result.execution == %{mode: :classical, provider: :none, target: :none}
    assert result.output.selected_solution.id == "s2"
    assert result.schema_version == "v2"
  end

  test "constrained optimization reports the fallback mode when its capability is unavailable" do
    assert {:ok, result} =
             AI.run_tool(
               request("constrained optimization helper", optimize_input(), :allow_classical_fallback),
               provider_capabilities: %{supports_constrained_optimize: false}
             )

    assert result.status == :fallback
    assert result.execution.mode == :classical_fallback
    assert result.schema_version == "v2"
  end

  test "no bundled handler scenario reports the quantum mode" do
    scenarios = [
      request("quantum-kernel reranking", %{candidate_ids: ["a", "b"], scores: %{"a" => 1.0, "b" => 0.5}}),
      request("quantum_kernel_rerank.v1", @embedding_input),
      request("constrained optimization helper", optimize_input(), :allow_classical_fallback)
    ]

    for req <- scenarios do
      assert {:ok, result} = AI.run_tool(req, provider_capabilities: %{})
      refute result.execution.mode == :quantum, "#{req.tool_name} reported :quantum for a classical computation"
    end
  end

  # Smoke check on source text, not a behavior proof: it greps the handler sources for
  # `mode: :quantum`. The behavior tests above are the proof of the reported mode.
  test "a bundled handler source reports :quantum only when it makes a simulator or provider call" do
    for path <- @bundled_handler_sources do
      source = File.read!(path)
      reports_quantum? = Regex.match?(~r/mode:\s*:quantum\b/, source)
      calls_backend? = Enum.any?(@quantum_backend_modules, &String.contains?(source, &1))

      refute reports_quantum? and not calls_backend?,
             "#{path} reports execution mode :quantum without a simulator or provider call"
    end
  end

  defp request(tool_name, input, fallback_policy \\ :strict) do
    %{
      schema_version: "v1",
      request_id: "req-truth-#{System.unique_integer([:positive])}",
      correlation_id: "corr-truth",
      tool_name: tool_name,
      input: input,
      execution_policy: %{fallback_policy: fallback_policy}
    }
  end

  defp optimize_input do
    %{
      candidate_solutions: [
        %{id: "s1", feasible: true, cost: 10.0},
        %{id: "s2", feasible: true, cost: 3.0}
      ]
    }
  end
end
