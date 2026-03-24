defmodule NxQuantum.AI.ToolRunner do
  @moduledoc """
  Deterministic AI tool handler dispatcher for the public `NxQuantum.AI` surface.
  """

  alias NxQuantum.AI.Request
  alias NxQuantum.AI.Result

  @kernel_tool "quantum-kernel reranking"
  @opt_tool "constrained optimization helper"

  @spec run(Request.t(), keyword()) :: {:ok, Result.t()} | {:error, map()}
  def run(%Request{} = request, opts \\ []) do
    case request.tool_name do
      @kernel_tool -> run_kernel_rerank(request, opts)
      @opt_tool -> run_constrained_optimize(request, opts)
      _ -> {:error, typed_error(request, :ai_tool_unsupported, :capability, "unsupported tool handler")}
    end
  end

  defp run_kernel_rerank(%Request{} = request, opts) do
    capabilities = Keyword.get(opts, :provider_capabilities, %{})
    fallback_policy = request.execution_policy[:fallback_policy] || :allow_classical_fallback

    cond do
      Map.get(capabilities, :supports_kernel_rerank, true) ->
        candidate_ids = Map.get(request.input, :candidate_ids, [])
        score_map = Map.get(request.input, :scores, %{})
        ranked = rank_candidates(candidate_ids, score_map)

        {:ok,
         Result.ok(%{
           request_id: request.request_id,
           correlation_id: request.correlation_id,
           tool_name: request.tool_name,
           output: %{ranked_candidate_ids: ranked},
           execution: %{
             mode: :quantum,
             provider: Map.get(capabilities, :provider, :none),
             target: Map.get(capabilities, :target, :none)
           }
         })}

      fallback_policy == :allow_classical_fallback ->
        candidate_ids = Map.get(request.input, :candidate_ids, [])

        {:ok,
         Result.fallback(%{
           request_id: request.request_id,
           correlation_id: request.correlation_id,
           tool_name: request.tool_name,
           output: %{ranked_candidate_ids: Enum.sort(candidate_ids)},
           execution: %{mode: :classical_fallback, provider: :none, target: :none},
           diagnostics: [%{code: :kernel_rerank_fallback, reason: :provider_capability_unavailable}]
         })}

      true ->
        {:error,
         typed_error(request, :ai_tool_fallback_blocked, :policy, "kernel rerank requires unavailable capability")}
    end
  end

  defp run_constrained_optimize(%Request{} = request, opts) do
    capabilities = Keyword.get(opts, :provider_capabilities, %{})
    fallback_policy = request.execution_policy[:fallback_policy] || :allow_classical_fallback
    candidates = Map.get(request.input, :candidate_solutions, [])

    cond do
      Map.get(capabilities, :supports_constrained_optimize, true) ->
        {:ok, optimized_result(request, candidates, :quantum, [])}

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

    status = if mode == :quantum, do: :ok, else: :fallback

    %Result{
      schema_version: "v1",
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

  defp rank_candidates(candidate_ids, score_map) do
    candidate_ids
    |> Enum.map(fn id -> {id, Map.get(score_map, id, 0.0)} end)
    |> Enum.sort_by(fn {id, score} -> {-score, id} end)
    |> Enum.map(&elem(&1, 0))
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
