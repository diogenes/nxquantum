defmodule NxQuantum.Estimator.StrategyObservability do
  @moduledoc false

  @default_parallel_threshold 96
  @cache_status_key :nxq_estimator_cache_status

  @spec apply(keyword(), map(), [map()], keyword()) :: keyword()
  def apply(opts, selection, observable_specs, apply_opts \\ []) do
    observable_strategy = observable_strategy(observable_specs, opts)
    runtime_lane = runtime_lane(selection.selected_profile)
    cache_status = cache_status(opts, apply_opts)

    opts
    |> Keyword.put(:estimator_observable_strategy, observable_strategy)
    |> Keyword.put(:estimator_runtime_lane, runtime_lane)
    |> Keyword.put(:estimator_cache_mode, cache_mode(opts))
    |> Keyword.put(:estimator_cache_status, cache_status)
    |> Keyword.put(:estimator_strategy_tags, [observable_strategy, runtime_lane, cache_status])
  end

  defp observable_strategy(observable_specs, opts) do
    term_count = length(observable_specs)
    threshold = Keyword.get(opts, :parallel_observables_threshold, @default_parallel_threshold)
    parallel? = Keyword.get(opts, :parallel_observables, true)

    if parallel? and term_count >= threshold do
      :parallel
    else
      :scalar
    end
  end

  defp runtime_lane(profile) when profile in [:cpu_compiled, :nvidia_gpu_compiled], do: :compiled
  defp runtime_lane(_profile), do: :portable

  defp cache_mode(opts) do
    if Keyword.get(opts, :cache_evolved_state, true) do
      :enabled
    else
      :disabled
    end
  end

  defp cache_status(opts, apply_opts) do
    executed? = Keyword.get(apply_opts, :executed?, true)

    case cache_mode(opts) do
      :disabled ->
        consume_runtime_cache_status()
        :bypass

      :enabled ->
        case Keyword.fetch(opts, :estimator_cache_status) do
          {:ok, status} ->
            status

          :error ->
            if executed? do
              consume_runtime_cache_status()
            else
              :unknown
            end
        end
    end
  end

  defp consume_runtime_cache_status do
    Process.delete(@cache_status_key) || :unknown
  end
end
