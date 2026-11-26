defmodule NxQuantum.OptionKeys do
  @moduledoc false

  # Boundary allow-list for top-level option keys (KG-25, phase 1).
  #
  # An unknown key never changes a result. The call computes exactly as it did, logs one
  # Logger.warning, and, where the result has a metadata map, gains an `:unknown_options`
  # entry. Phase 2 turns the warning into a typed error in a later minor release.
  #
  # A key belongs here when a function reached from NxQuantum.Estimator.run/2,
  # expectation_result/2 or NxQuantum.Sampler.run/2 reads it from the caller's options,
  # or when the KG-22 cache and concurrency keys are named. Add a key in the same change
  # that starts reading it. Nested contents of `noise:` and `backend_opts:` are not checked.
  # Adapter-specific keys are an exception recorded in docs/adr/0013-option-keys-adapter-exception.md.

  require Logger

  # Exception (ADR 0013, owner: user): the five simulator and KG-22 cache keys below are adapter
  # detail that the application allow-list names until a port carries the adapter's key list.
  # Estimator path: ObservableSpecs, Measurement, RuntimeProfile, ExecutionMode,
  # Stochastic, StrategyObservability, ResultBuilder, ExecuteCircuit, and the StateVector
  # simulator with its evolved-state cache and Pauli-expectation concurrency.
  @estimator_keys [
    :observable,
    :observables,
    :wire,
    :shots,
    :seed,
    :noise,
    :runtime_profile,
    :fallback_policy,
    :runtime_available?,
    :capabilities,
    :simulator,
    :backend_opts,
    :cache_evolved_state,
    :cache_parsed_counts,
    :cache_mask_lookup_plan,
    :evolved_state_cache_ttl_ms,
    :evolved_state_cache_max_bytes,
    :fused_compiled_kernel_policy,
    :parallel_observables,
    :parallel_observables_threshold,
    :observable_max_concurrency,
    :max_concurrency,
    :sampled_parallel_mode,
    # Keys the result builders read back from opts after the runtime and strategy
    # selection has put them there.
    :runtime_profile_requested,
    :runtime_profile_resolved,
    :runtime_profile_selection_source,
    :runtime_profile_selection_reason,
    :estimator_observable_strategy,
    :estimator_runtime_lane,
    :estimator_cache_mode,
    :estimator_cache_status,
    :estimator_fused_kernel_requested,
    :estimator_fused_kernel_selected,
    :estimator_fused_kernel_reason,
    :estimator_strategy_tags
  ]

  # Sampler.run/2 reads only these from the caller and forwards estimator options built
  # from a subset of them. Other keys are ignored, so they are unknown here.
  @sampler_keys [
    :shots,
    :seed,
    :observable,
    :wire,
    :runtime_profile,
    :fallback_policy,
    :runtime_available?
  ]

  @type scope :: :estimator | :sampler

  @spec estimator_keys() :: [atom()]
  def estimator_keys, do: @estimator_keys

  @spec sampler_keys() :: [atom()]
  def sampler_keys, do: @sampler_keys

  @doc """
  Returns the unknown top-level keys of `opts` (each once, in order of appearance) and logs one
  warning naming them. The warning names `entrypoint`, for example `"NxQuantum.Sampler.run/2"`.
  """
  @spec validate(keyword(), scope(), String.t()) :: [atom()]
  def validate(opts, scope, entrypoint) do
    allowed = allowed_keys(scope)

    unknown = for {key, _value} when is_atom(key) <- opts, key not in allowed, uniq: true, do: key

    if unknown != [] do
      Logger.warning(
        "#{entrypoint} ignores unknown option keys #{inspect(unknown)}; see docs/api-stability.md (option validation)"
      )
    end

    unknown
  end

  @doc false
  @spec put_unknown(map(), [atom()]) :: map()
  def put_unknown(result, []), do: result

  def put_unknown(%{metadata: metadata} = result, unknown) do
    %{result | metadata: Map.put(metadata, :unknown_options, unknown)}
  end

  defp allowed_keys(:estimator), do: @estimator_keys
  defp allowed_keys(:sampler), do: @sampler_keys
end
