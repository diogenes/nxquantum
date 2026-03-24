defmodule NxQuantum.Observability do
  @moduledoc """
  Observability helpers for provider lifecycle and cross-provider comparability.
  """

  alias NxQuantum.Observability.Fingerprint
  alias NxQuantum.Observability.MetadataPolicy
  alias NxQuantum.Observability.PortabilityDelta
  alias NxQuantum.Observability.Profile
  alias NxQuantum.Observability.ProfileStrategy.Forensics
  alias NxQuantum.Observability.ProfileStrategy.Granular
  alias NxQuantum.Observability.ProfileStrategy.HighLevel
  alias NxQuantum.Observability.TroubleshootingBundle

  @default_adapter NxQuantum.Adapters.Observability.Noop

  @spec reset(keyword()) :: :ok
  def reset(opts \\ []) do
    adapter(opts).reset()
  end

  @spec snapshot(keyword()) :: map()
  def snapshot(opts \\ []) do
    adapter(opts).snapshot()
  end

  @spec trace_lifecycle(atom(), atom() | String.t(), String.t(), atom(), keyword(), (-> any())) :: any()
  def trace_lifecycle(operation, provider, target, workflow, opts, fun) when is_function(fun, 0) do
    profile = Profile.normalize(Keyword.get(opts, :profile, :high_level))

    if Profile.enabled?(opts) do
      adapter = adapter(opts)
      span_name = "nxq.provider.#{operation}"
      correlation_metadata = correlation_metadata(opts)
      custom_metadata = custom_metadata(opts)

      attrs =
        %{
          nxq_provider: provider,
          nxq_target: target,
          nxq_workflow: workflow,
          nxq_runtime_profile: Keyword.get(opts, :runtime_profile, :cpu_portable),
          nxq_visibility_profile: profile,
          nxq_retry_count: Keyword.get(opts, :retry_count, 0),
          nxq_poll_cycle_count: Keyword.get(opts, :poll_cycle_count, 0),
          nxq_phase: Keyword.get(opts, :phase, operation),
          nxq_terminal_attribution: Keyword.get(opts, :terminal_attribution, :unknown)
        }
        |> Map.merge(correlation_metadata)
        |> Map.merge(custom_metadata)

      span_ctx = adapter.span_start(span_name, attrs, opts)

      result = fun.()
      status = if match?({:ok, _}, result), do: :ok, else: :error

      adapter.span_stop(span_ctx, Map.put(attrs, :status, status), opts)
      emit_standard_metrics(adapter, operation, provider, target, workflow, status, opts)

      adapter.log_emit(
        %{
          event: "nxq.lifecycle.transition",
          level: :info,
          message: "provider lifecycle operation executed",
          provider: provider,
          target: target,
          workflow: workflow,
          trace_id: span_ctx.trace_id,
          span_id: span_ctx.span_id,
          custom_metadata: custom_metadata,
          correlation_metadata: correlation_metadata
        },
        opts
      )

      result
    else
      fun.()
    end
  end

  @spec trace_workflow(atom() | String.t(), String.t(), atom(), keyword(), (-> any())) :: any()
  def trace_workflow(provider, target, workflow, opts, fun) when is_function(fun, 0) do
    if Profile.enabled?(opts) do
      adapter = adapter(opts)

      attrs = %{
        nxq_provider: provider,
        nxq_target: target,
        nxq_workflow: workflow,
        nxq_visibility_profile: Profile.normalize(Keyword.get(opts, :profile, :high_level))
      }

      span_ctx = adapter.span_start("nxq.workflow.run", attrs, opts)
      result = fun.()
      status = if match?({:ok, _}, result), do: :ok, else: :error
      adapter.span_stop(span_ctx, Map.put(attrs, :status, status), opts)
      result
    else
      fun.()
    end
  end

  @spec fingerprint(map(), keyword()) :: String.t()
  def fingerprint(input, opts \\ []), do: Fingerprint.generate(input, opts)

  @spec portability_delta(map(), map()) :: map()
  def portability_delta(reference, candidate), do: PortabilityDelta.compute(reference, candidate)

  @spec troubleshooting_bundle(keyword()) :: map()
  def troubleshooting_bundle(opts \\ []) do
    opts
    |> adapter()
    |> then(& &1.snapshot())
    |> TroubleshootingBundle.export(opts)
  end

  defp emit_standard_metrics(adapter, operation, provider, target, workflow, status, opts) do
    labels = %{
      provider: provider,
      target: target,
      workflow: workflow,
      visibility_profile: Profile.normalize(Keyword.get(opts, :profile, :high_level))
    }

    profile_strategy(opts).emit_metrics(adapter, operation, labels, status, opts)
  end

  defp adapter(opts) do
    Keyword.get(opts, :adapter, @default_adapter)
  end

  defp custom_metadata(opts) do
    opts
    |> Keyword.get(:custom_metadata, %{})
    |> MetadataPolicy.validate_and_redact()
    |> case do
      {:ok, metadata} ->
        metadata

      {:error, reason} ->
        %{"custom_metadata_policy_rejected" => true, "custom_metadata_policy_reason" => inspect(reason)}
    end
  end

  defp correlation_metadata(opts) do
    opts
    |> Keyword.get(:correlation_metadata, %{})
    |> Map.new(fn {k, v} -> {"correlation.#{k}", v} end)
  end

  defp profile_strategy(opts) do
    case Profile.normalize(Keyword.get(opts, :profile, :high_level)) do
      :high_level -> HighLevel
      :granular -> Granular
      :forensics -> Forensics
    end
  end
end
