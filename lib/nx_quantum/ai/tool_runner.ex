defmodule NxQuantum.AI.ToolRunner do
  @moduledoc """
  Deterministic AI tool handler dispatcher for the public `NxQuantum.AI` surface.
  """

  alias NxQuantum.AI.Request
  alias NxQuantum.AI.Result
  alias NxQuantum.AI.Tools.KernelRerank

  @kernel_tools ["quantum-kernel reranking", "quantum_kernel_rerank.v1"]
  @opt_tool "constrained optimization helper"

  @spec run(Request.t(), keyword()) :: {:ok, Result.t()} | {:error, map()}
  def run(%Request{} = request, opts \\ []) do
    case request.tool_name do
      tool_name when tool_name in @kernel_tools -> run_kernel_rerank(request, opts)
      @opt_tool -> run_constrained_optimize(request, opts)
      _ -> {:error, typed_error(request, :ai_tool_unsupported, :capability, "unsupported tool handler")}
    end
  end

  defp run_kernel_rerank(%Request{} = request, opts) do
    KernelRerank.run(request, opts)
  end

  defp run_constrained_optimize(%Request{} = request, opts) do
    capabilities = Keyword.get(opts, :provider_capabilities, %{})
    fallback_policy = request.execution_policy[:fallback_policy] || :allow_classical_fallback
    candidates = Map.get(request.input, :candidate_solutions, [])

    cond do
      Map.get(capabilities, :supports_constrained_optimize, true) ->
        {:ok, optimized_result(request, candidates, :classical, [])}

      fallback_policy == :allow_classical_fallback ->
        {:ok,
         optimized_result(request, candidates, :classical_fallback, [
           %{code: :optimize_fallback, reason: :provider_capability_unavailable}
         ])}

      true ->
        {:error,
         typed_error(
           request,
           :ai_tool_fallback_blocked,
           :policy,
           "constrained optimization requires unavailable capability"
         )}
    end
  end

  defp optimized_result(request, candidates, mode, diagnostics) do
    chosen =
      candidates
      |> Enum.filter(&(Map.get(&1, :feasible, false) == true))
      |> Enum.sort_by(&{Map.get(&1, :cost, 1.0e18), Map.get(&1, :id, "")})
      |> List.first()
      |> Kernel.||(%{id: "none", cost: nil, feasible: false})

    status = if mode == :classical_fallback, do: :fallback, else: :ok

    %Result{
      schema_version: Result.schema_version(),
      request_id: request.request_id,
      correlation_id: request.correlation_id,
      status: status,
      tool_name: request.tool_name,
      output: %{selected_solution: chosen},
      execution: %{mode: mode, provider: :none, target: :none},
      diagnostics: diagnostics,
      metadata: %{}
    }
  end

  defp typed_error(%Request{} = request, code, category, message) do
    %{
      schema_version: "v1",
      request_id: request.request_id,
      correlation_id: request.correlation_id,
      code: code,
      category: category,
      retryable: false,
      message: message,
      details: %{tool_name: request.tool_name}
    }
  end
end
