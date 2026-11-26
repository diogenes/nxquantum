defmodule NxQuantum.Estimator.StrategyObservability do
  @moduledoc false

  alias NxQuantum.Ports.Simulator

  @default_parallel_threshold 96
  @unreported_simulation %{method: nil, evolution_path: nil, state_backend: nil, expectation_path: nil}

  # The simulation facts arrive through `apply_opts[:simulation]`, the return value of the simulator port.
  # Nothing here reads or writes process state.
  @spec apply(keyword(), map(), [map()], keyword()) :: keyword()
  def apply(opts, selection, observable_specs, apply_opts \\ []) do
    observable_strategy = observable_strategy(observable_specs, opts)
    runtime_lane = runtime_lane(selection.selected_profile)
    executed? = Keyword.get(apply_opts, :executed?, true)
    facts = Keyword.get(apply_opts, :simulation, Simulator.unreported_facts())
    cache_status = cache_status(opts, facts)
    fused_kernel = facts.fused_kernel

    opts
    |> Keyword.put(:estimator_simulation, simulation(executed?, facts))
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

  # Combines the facts of several simulator calls that belong to one run. Equal values are kept;
  # differing values collapse to :mixed.
  @spec merge_facts([Simulator.simulation_facts()]) :: Simulator.simulation_facts()
  def merge_facts([]), do: Simulator.unreported_facts()
  def merge_facts([single]), do: single

  def merge_facts([first | _] = facts) do
    fused_source = Enum.find(facts, first, &(&1.fused_kernel.selected_kernel != :unknown))

    %{
      method: collapse(facts, :method),
      evolution_path: collapse(facts, :evolution_path),
      state_backend: collapse(facts, :state_backend),
      cache_status: collapse(facts, :cache_status),
      expectation_path: collapse(facts, :expectation_path),
      fused_kernel: fused_source.fused_kernel
    }
  end

  defp collapse(facts, key) do
    case facts |> Enum.map(&Map.fetch!(&1, key)) |> Enum.uniq() do
      [single] -> single
      _ -> :mixed
    end
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

  defp cache_status(opts, facts) do
    case cache_mode(opts) do
      :disabled ->
        :bypass

      :enabled ->
        case Keyword.fetch(opts, :estimator_cache_status) do
          {:ok, status} -> status
          :error -> facts.cache_status
        end
    end
  end

  # Reported only from the simulator's facts. A simulator that reports none leaves the fields nil.
  # expectation_path is nil when nothing was evaluated in this call.
  defp simulation(_executed?, %{method: nil}), do: @unreported_simulation

  defp simulation(executed?, facts) do
    %{
      method: facts.method,
      evolution_path: facts.evolution_path,
      state_backend: facts.state_backend,
      expectation_path: if(executed?, do: facts.expectation_path)
    }
  end
end
