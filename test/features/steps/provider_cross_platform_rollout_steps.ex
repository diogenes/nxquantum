defmodule NxQuantum.Features.Steps.ProviderCrossPlatformRolloutSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Ports.Provider
  alias NxQuantum.ProviderBridge
  alias NxQuantum.TestSupport.ProviderMatrix

  defmodule RaisingProvider do
    @moduledoc false
    @behaviour Provider

    @impl true
    def provider_id, do: :raising_provider

    @impl true
    def capabilities(_target, _opts),
      do:
        {:ok,
         %{
           supports_estimator: true,
           supports_sampler: true,
           supports_batch: true,
           supports_dynamic: true,
           supports_cancel_in_running: true,
           supports_calibration_payload: true,
           target_class: :gate_model
         }}

    @impl true
    def submit(_payload, _opts), do: raise("provider unavailable")

    @impl true
    def poll(_job, _opts), do: {:ok, %{}}

    @impl true
    def cancel(_job, _opts), do: {:ok, %{}}

    @impl true
    def fetch_result(_job, _opts), do: {:ok, %{}}
  end

  defmodule NoProviderIdProvider do
    @moduledoc false

    def submit(_payload, _opts), do: {:error, {:invalid_state, :submitted}}
    def poll(_job, _opts), do: {:ok, %{}}
    def cancel(job, _opts), do: {:ok, Map.put(job, :state, :cancelled)}
    def fetch_result(_job, _opts), do: {:ok, %{}}
  end

  defmodule BrokenPayloadProvider do
    @moduledoc false
    @behaviour Provider

    @impl true
    def provider_id, do: :broken_payload_provider

    @impl true
    def capabilities(_target, _opts),
      do:
        {:ok,
         %{
           supports_estimator: true,
           supports_sampler: true,
           supports_batch: true,
           supports_dynamic: true,
           supports_cancel_in_running: true,
           supports_calibration_payload: true,
           target_class: :gate_model
         }}

    @impl true
    def submit(_payload, _opts), do: :unexpected_shape

    @impl true
    def poll(_job, _opts), do: {:ok, %{}}

    @impl true
    def cancel(_job, _opts), do: {:ok, %{}}

    @impl true
    def fetch_result(_job, _opts), do: {:ok, %{}}
  end

  @impl true
  def feature, do: "provider_cross_platform_rollout.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2, &handle_errors/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "equivalent workflow intents are executed across the registered provider set" ->
        {:handled, Map.put(ctx, :payload, %{workflow: :sampler, shots: 1024})}

      text == "a workflow requires capabilities that differ across providers" ->
        {:handled, Map.put(ctx, :non_portable_payload, %{workflow: :sampler, dynamic: true})}

      text == "provider-specific migration packs and benchmark reports are published" ->
        {:handled,
         Map.put(ctx, :evidence_paths, [
           "docs/migration-packs.md",
           "docs/provider-benchmark-matrix.md",
           "docs/provider-support-catalog.md",
           "examples/livebook/provider_bridge_side_by_side.livemd",
           "docs/observability-dashboards.md"
         ])}

      text == "a provider adapter supports submit, poll, and fetch_result" ->
        lifecycle_entry = :cross_platform |> ProviderMatrix.entries_for() |> List.first()

        {:handled,
         Map.merge(ctx, %{
           lifecycle_provider: lifecycle_entry.adapter,
           lifecycle_payload: %{workflow: :sampler, shots: 512},
           lifecycle_opts: provider_opts(lifecycle_entry)
         })}

      text == "adapters in the registered provider set are configured" ->
        {:handled,
         Map.put(
           ctx,
           :provider_opts,
           :cross_platform
           |> ProviderMatrix.entries_for()
           |> Map.new(fn entry -> {entry.id, provider_opts(entry)} end)
         )}

      text == "a provider adapter raises an exception during a lifecycle operation" ->
        {:handled, Map.merge(ctx, %{raising_provider: RaisingProvider, raising_payload: %{workflow: :sampler}})}

      text == "a provider adapter does not implement provider_id callback" ->
        {:handled, Map.put(ctx, :no_provider_id_provider, NoProviderIdProvider)}

      text == "a provider job is already in terminal cancelled state" ->
        {:handled,
         Map.put(ctx, :cancelled_job, %{
           id: "job_cancelled",
           state: :cancelled,
           target: "test_target",
           metadata: %{workflow: :sampler}
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text, table: _table}, ctx) do
    cond do
      text == "terminal results are normalized by ProviderBridge" ->
        {:handled, Map.put(ctx, :cross_provider_lifecycle, cross_provider_lifecycle(ctx.payload))}

      text == "capability preflight and execution rules are applied" ->
        {:handled, Map.put(ctx, :non_portable_results, cross_provider_non_portable(ctx.non_portable_payload))}

      text == "readiness evidence is reviewed for release" ->
        {:handled, Map.put(ctx, :evidence_check, Enum.map(ctx.evidence_paths, &{&1, File.exists?(&1)}))}

      text == "run_lifecycle is executed for an equivalent workflow intent" ->
        {:handled,
         Map.put(
           ctx,
           :run_lifecycle_result,
           ProviderBridge.run_lifecycle(ctx.lifecycle_provider, ctx.lifecycle_payload, ctx.lifecycle_opts)
         )}

      text == "equivalent failure classes occur across providers" ->
        {:handled, ctx}

      text == "ProviderBridge handles the failed operation" ->
        {:handled, Map.put(ctx, :raising_result, ProviderBridge.submit_job(ctx.raising_provider, ctx.raising_payload))}

      text == "lifecycle operation error metadata is emitted" ->
        {:handled,
         Map.put(
           ctx,
           :no_provider_id_result,
           ProviderBridge.submit_job(ctx.no_provider_id_provider, %{workflow: :sampler})
         )}

      text == "cancel is requested again" ->
        {:handled,
         Map.put(ctx, :repeated_cancel_result, ProviderBridge.cancel_job(NoProviderIdProvider, ctx.cancelled_job))}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text, table: table}, ctx) do
    cond do
      text == "common envelope fields remain stable across providers" ->
        assert Enum.all?(ctx.cross_provider_lifecycle, fn {_provider, {:ok, %{result: result}}} ->
                 Enum.all?([:job_id, :state, :provider, :target, :payload, :metadata], &Map.has_key?(result, &1))
               end)

        {:handled, ctx}

      text == "provider-specific fields are isolated under metadata extensions" ->
        assert Enum.all?(ctx.cross_provider_lifecycle, fn {_provider, {:ok, %{result: result}}} ->
                 is_map(result.metadata)
               end)

        {:handled, ctx}

      text == "structural parity is deterministic for equivalent workflow classes" ->
        [{_, {:ok, %{result: first}}} | rest] = Enum.to_list(ctx.cross_provider_lifecycle)
        assert Enum.all?(rest, fn {_, {:ok, %{result: result}}} -> Map.keys(result) == Map.keys(first) end)
        {:handled, ctx}

      text == "non-portable differences are represented via typed metadata" ->
        assert Enum.all?(ctx.non_portable_results, fn {_provider, {:error, %{metadata: metadata}}} -> is_map(metadata) end)

        {:handled, ctx}

      text == "unsupported requests fail fast and deterministically" ->
        assert Enum.all?(ctx.non_portable_results, fn {_provider, {:error, %{code: :provider_capability_mismatch}}} ->
                 true
               end)

        {:handled, ctx}

      text == "no silent provider reroute or fallback occurs" ->
        assert Enum.all?(ctx.non_portable_results, fn {provider, {:error, %{provider: error_provider}}} ->
                 provider == error_provider
               end)

        {:handled, ctx}

      text == "each migration path maps to explicit acceptance criteria" ->
        assert Enum.all?(ctx.evidence_check, fn {_path, exists?} -> exists? end)
        {:handled, ctx}

      text == "each claim references benchmark or deterministic fixture evidence" ->
        benchmark_doc = File.read!("docs/provider-benchmark-matrix.md")
        assert benchmark_doc =~ "bench/milestone_k.exs"
        assert benchmark_doc =~ "Provider Caveats"
        {:handled, ctx}

      text == "support tiers and known limits are documented per provider" ->
        support_tiers = File.read!("docs/provider-support-catalog.md")
        assert support_tiers =~ "stable"
        assert support_tiers =~ "beta"
        assert support_tiers =~ "Known limits"
        {:handled, ctx}

      text == ~s(response includes "submitted", "polled", and "result" sections) ->
        assert {:ok, %{submitted: _, polled: _, result: _}} = ctx.run_lifecycle_result
        {:handled, ctx}

      text == "each section follows normalized provider contract shape" ->
        assert {:ok, %{submitted: submitted, polled: polled, result: result}} = ctx.run_lifecycle_result
        assert Map.has_key?(submitted, :provider)
        assert Map.has_key?(polled, :provider)
        assert Map.has_key?(result, :provider)
        {:handled, ctx}

      text == "lifecycle sequencing remains deterministic" ->
        assert {:ok, %{submitted: %{state: :submitted}, polled: %{state: :completed}, result: %{state: :completed}}} =
                 ctx.run_lifecycle_result

        {:handled, ctx}

      text == "standardized error codes are used consistently" ->
        rows = Enum.drop(table, 1)
        failure_matrix = failure_matrix(ctx.provider_opts, table)

        assert Enum.all?(failure_matrix, fn {_provider, results} ->
                 Enum.all?(rows, fn [failure_class, expected_code] ->
                   {:error, %{code: code}} = Map.fetch!(results, failure_class)
                   code == String.to_atom(expected_code)
                 end)
               end)

        {:handled, Map.put(ctx, :failure_matrix, failure_matrix)}

      text == "provider-specific details are isolated under metadata" ->
        assert Enum.all?(ctx.failure_matrix, fn {_provider, results} ->
                 Enum.all?(results, fn {_failure, {:error, %{metadata: metadata}}} -> is_map(metadata) end)
               end)

        {:handled, ctx}

      text == "process-level crashes are not leaked through the contract" ->
        assert {:error, %{code: :provider_transport_error}} = ctx.raising_result
        {:handled, ctx}

      text == "provider identifier fallback is deterministic" ->
        assert {:error, %{provider: NoProviderIdProvider}} = ctx.no_provider_id_result
        {:handled, ctx}

      text == "error payload still includes provider and operation context" ->
        assert {:error, %{operation: :submit, provider: NoProviderIdProvider}} = ctx.no_provider_id_result
        {:handled, ctx}

      text == "response remains terminally cancelled" ->
        assert {:ok, %{state: :cancelled}} = ctx.repeated_cancel_result
        {:handled, ctx}

      text == "repeated cancellation does not create inconsistent state transitions" ->
        assert {:ok, %{state: :cancelled}} = ctx.repeated_cancel_result
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_errors(%{text: text}, ctx) do
    if text =~ ~r/^error / and text =~ ~r/ is returned$/ do
      expected = text |> NxQuantum.TestSupport.Helpers.parse_quoted() |> String.to_atom()
      assert {:error, %{code: ^expected}} = ctx.raising_result
      {:handled, ctx}
    else
      :unhandled
    end
  end

  defp cross_provider_lifecycle(payload) do
    :cross_platform
    |> ProviderMatrix.entries_for()
    |> Map.new(fn entry ->
      {entry.id, ProviderBridge.run_lifecycle(entry.adapter, payload, provider_opts(entry))}
    end)
  end

  defp cross_provider_non_portable(payload) do
    :cross_platform
    |> ProviderMatrix.entries_for()
    |> Map.new(fn entry ->
      {entry.id, ProviderBridge.submit_job(entry.adapter, payload, provider_opts(entry))}
    end)
  end

  defp failure_matrix(opts_by_provider, table) do
    rows = Enum.drop(table, 1)

    Map.new(opts_by_provider, fn {provider, opts} ->
      entries =
        Map.new(rows, fn [failure_class, expected_code] ->
          result = simulate_failure(provider, failure_class, opts)
          assert {:error, %{code: code}} = result
          assert code == String.to_atom(expected_code)
          {failure_class, result}
        end)

      {provider, entries}
    end)
  end

  defp simulate_failure(provider, "transport_timeout", opts) do
    job = %{
      id: "job_1",
      state: :submitted,
      provider: provider,
      target: Keyword.get(opts, :target),
      metadata: %{workflow: :sampler}
    }

    ProviderBridge.poll_job(provider_module(provider), job, Keyword.put(opts, :force_error, {:poll, :timeout}))
  end

  defp simulate_failure(provider, "invalid_state_fetch_result", opts) do
    job = %{
      id: "job_2",
      state: :submitted,
      provider: provider,
      target: Keyword.get(opts, :target),
      metadata: %{workflow: :sampler}
    }

    ProviderBridge.fetch_result(provider_module(provider), job, opts)
  end

  defp simulate_failure(_provider, "unexpected_response_shape", _opts) do
    ProviderBridge.submit_job(BrokenPayloadProvider, %{workflow: :sampler})
  end

  defp simulate_failure(provider, "capability_mismatch", opts) do
    ProviderBridge.submit_job(provider_module(provider), %{workflow: :sampler, dynamic: true}, opts)
  end

  defp simulate_failure(provider, "provider_execution_failure", opts) do
    ProviderBridge.submit_job(
      provider_module(provider),
      %{workflow: :sampler},
      Keyword.put(opts, :force_error, {:submit, :execution_failure})
    )
  end

  defp simulate_failure(provider, "auth_failure", opts) do
    ProviderBridge.submit_job(provider_module(provider), %{workflow: :sampler}, Keyword.put(opts, :provider_config, %{}))
  end

  defp simulate_failure(provider, "rate_limited", opts) do
    ProviderBridge.submit_job(
      provider_module(provider),
      %{workflow: :sampler},
      Keyword.put(opts, :force_error, {:submit, {:provider_rate_limited, :quota}})
    )
  end

  defp provider_module(provider_id), do: ProviderMatrix.entry!(provider_id).adapter

  defp provider_opts(entry), do: [target: entry.target, provider_config: entry.provider_config]
end
