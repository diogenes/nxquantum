defmodule NxQuantum.Estimator.StrategyObservability do
  @moduledoc false

  @default_parallel_threshold 96
  @cache_status_key :nxq_estimator_cache_status
  @fused_kernel_resolution_key :nxq_fused_kernel_resolution
  @simulation_key :nxq_estimator_simulation

  @spec begin_run() :: :ok
  def begin_run do
    Process.delete(@simulation_key)
    Process.delete(@fused_kernel_resolution_key)
    :ok
  end

  @spec apply(keyword(), map(), [map()], keyword()) :: keyword()
  def apply(opts, selection, observable_specs, apply_opts \\ []) do
    observable_strategy = observable_strategy(observable_specs, opts)
    runtime_lane = runtime_lane(selection.selected_profile)
    cache_status = cache_status(opts, apply_opts)
    fused_kernel = fused_kernel_resolution()
    executed? = Keyword.get(apply_opts, :executed?, true)

    opts
    |> Keyword.put(:estimator_simulation, simulation(executed?, fused_kernel))
    |> Keyword.put(:estimator_observable_strategy, observable_strategy)
    |> Keyword.put(:estimator_runtime_lane, runtime_lane)
    |> Keyword.put(:estimator_cache_mode, cache_mode(opts))
    |> Keyword.put(:estimator_cache_status, cache_status)
    |> Keyword.put(:estimator_fused_kernel_requested, fused_kernel.requested_kernel)
    |> Keyword.put(:estimator_fused_kernel_selected, fused_kernel.selected_kernel)
    |> Keyword.put(:estimator_fused_kernel_reason, fused_kernel.reason)
    |> Keyword.put(:estimator_strategy_tags, [
      observable_strategy,
      runtime_lane,
      cache_status,
      fused_kernel.selected_kernel
    ])
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

  # Reported only when the state-vector simulator recorded this run. Any other simulator
  # leaves the fields nil instead of guessing.
  defp simulation(executed?, fused_kernel) do
    recorded = Process.delete(@simulation_key) || %{evolution_paths: [], state_backends: []}

    case recorded.state_backends do
      [] ->
        %{method: nil, evolution_path: nil, state_backend: nil, expectation_path: nil}

      backends ->
        %{
          method: :state_vector,
          evolution_path: evolution_path(recorded.evolution_paths),
          state_backend: single_or_mixed(backends),
          expectation_path: expectation_path(executed?, fused_kernel)
        }
    end
  end

  defp evolution_path([]), do: nil
  defp evolution_path([path]), do: path
  defp evolution_path(_paths), do: :mixed

  defp single_or_mixed([backend]), do: backend
  defp single_or_mixed(_backends), do: :mixed

  defp expectation_path(false, _fused_kernel), do: nil
  defp expectation_path(true, %{selected_kernel: :unknown}), do: :generic
  defp expectation_path(true, _fused_kernel), do: :fused_single_wire

  defp fused_kernel_resolution do
    Process.delete(@fused_kernel_resolution_key) ||
      %{
        requested_kernel: :unknown,
        selected_kernel: :unknown,
        reason: :not_applicable
      }
  end
end
