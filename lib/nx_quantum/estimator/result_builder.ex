defmodule NxQuantum.Estimator.ResultBuilder do
  @moduledoc false

  alias NxQuantum.Estimator.Result

  @spec build(Nx.Tensor.t(), [map()], keyword()) :: Result.t()
  def build(values, observable_specs, opts) do
    resolved_runtime_profile = runtime_profile_id(opts)
    requested_runtime_profile = Keyword.get(opts, :runtime_profile_requested, resolved_runtime_profile)
    selection_reason = Keyword.get(opts, :runtime_profile_selection_reason, :explicit_request)

    %Result{
      values: values,
      metadata: %{
        mode: :estimator,
        observables: observable_specs,
        runtime_profile: resolved_runtime_profile,
        runtime_selection: %{
          requested_profile: requested_runtime_profile,
          selected_profile: Keyword.get(opts, :runtime_profile_resolved, resolved_runtime_profile),
          source: Keyword.get(opts, :runtime_profile_selection_source, :explicit),
          reason: selection_reason
        },
        strategy_observability: %{
          requested_runtime_profile: requested_runtime_profile,
          resolved_runtime_profile: resolved_runtime_profile,
          selection_reason: selection_reason,
          observable_strategy: Keyword.get(opts, :estimator_observable_strategy, :scalar),
          runtime_lane: Keyword.get(opts, :estimator_runtime_lane, runtime_lane(resolved_runtime_profile)),
          cache_mode: Keyword.get(opts, :estimator_cache_mode, :enabled),
          cache_status: Keyword.get(opts, :estimator_cache_status, :unknown),
          fused_kernel_requested: Keyword.get(opts, :estimator_fused_kernel_requested, :unknown),
          fused_kernel_selected: Keyword.get(opts, :estimator_fused_kernel_selected, :unknown),
          fused_kernel_reason: Keyword.get(opts, :estimator_fused_kernel_reason, :not_applicable),
          strategy_tags: Keyword.get(opts, :estimator_strategy_tags, [])
        },
        shots: Keyword.get(opts, :shots),
        seed: Keyword.get(opts, :seed)
      }
    }
  end

  defp runtime_lane(profile) when profile in [:cpu_compiled, :nvidia_gpu_compiled], do: :compiled
  defp runtime_lane(_profile), do: :portable

  defp runtime_profile_id(opts) do
    case Keyword.get(opts, :runtime_profile, :cpu_portable) do
      %{id: id} when is_atom(id) -> id
      id when is_atom(id) -> id
      _ -> :cpu_portable
    end
  end
end
