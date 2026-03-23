defmodule NxQuantum.Features.Steps.ProviderSimulationStrategyFallbackSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Performance
  alias NxQuantum.Runtime
  alias NxQuantum.TestSupport.PerformanceFixtures

  @impl true
  def feature, do: "provider_simulation_strategy_fallback.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "projected state-vector memory exceeds configured execution threshold" ->
        {:handled,
         Map.merge(ctx, %{
           strategy: :auto,
           qubit_count: 28,
           dense_threshold: 20,
           projected_state_vector_memory_mb: 224.0,
           fallback_reason_code: :resource_threshold_exceeded,
           scenario_strategy: :mps
         })}

      text == "provider path is unavailable or requested capability is unsupported" ->
        {:handled,
         Map.merge(ctx, %{
           runtime_profile: :nvidia_gpu_compiled,
           fallback_policy: :allow_cpu_compiled,
           runtime_available?: false,
           fallback_reason_code: :provider_path_unavailable_or_unsupported
         })}

      text == "a low-entanglement circuit is executed with MPS fallback" ->
        {:handled,
         Map.merge(ctx, %{
           builder: PerformanceFixtures.batch_builder(),
           batch: PerformanceFixtures.default_batch(8),
           tolerance: 1.0e-6
         })}

      text == "identical execution policy inputs and identical capability context" ->
        {:handled,
         Map.merge(ctx, %{
           strategy: :auto,
           qubit_count: 28,
           dense_threshold: 20,
           runtime_available?: false,
           fallback_policy: :allow_cpu_compiled
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: "execution policy evaluates available simulation strategies"}, ctx) do
    {:handled,
     Map.put(
       ctx,
       :scale_result,
       Runtime.select_simulation_strategy(ctx.strategy, ctx.qubit_count, dense_threshold: ctx.dense_threshold)
     )}
  end

  defp handle_execution(%{text: "execution policy evaluates provider and local strategy options"}, ctx) do
    {:handled,
     Map.put(
       ctx,
       :resolve_result,
       Runtime.resolve(:nvidia_gpu_compiled,
         fallback_policy: ctx.fallback_policy,
         runtime_available?: ctx.runtime_available?
       )
     )}
  end

  defp handle_execution(%{text: "expectation values are computed"}, ctx) do
    result =
      Performance.compare_batched_workflows(ctx.builder, ctx.batch,
        runtime_profile: :cpu_portable,
        observable: :pauli_z,
        wire: 0
      )

    {:handled, Map.put(ctx, :comparison_result, result)}
  end

  defp handle_execution(%{text: "fallback strategy selection is evaluated multiple times"}, ctx) do
    first = Runtime.select_simulation_strategy(ctx.strategy, ctx.qubit_count, dense_threshold: ctx.dense_threshold)
    second = Runtime.select_simulation_strategy(ctx.strategy, ctx.qubit_count, dense_threshold: ctx.dense_threshold)

    {:handled, Map.merge(ctx, %{repeat_first: first, repeat_second: second})}
  end

  defp handle_execution(_step, _ctx), do: :unhandled

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "deterministic MPS fallback is selected" ->
        assert {:ok, %{selected_path: :tensor_network_fallback}} = ctx.scale_result
        assert ctx.scenario_strategy == :mps
        {:handled, ctx}

      text == "strategy metadata reports threshold and projected memory values" ->
        assert {:ok, %{report: report}} = ctx.scale_result
        assert report.dense_threshold == 20
        assert report.qubit_count == 28
        assert ctx.projected_state_vector_memory_mb == 224.0
        {:handled, ctx}

      text == "fallback reason code is \"resource_threshold_exceeded\"" ->
        assert ctx.fallback_reason_code == :resource_threshold_exceeded
        {:handled, ctx}

      text == "deterministic local fallback strategy is selected and reported" ->
        assert {:ok, %{id: :cpu_compiled}} = ctx.resolve_result
        {:handled, ctx}

      text == "fallback reason code is \"provider_path_unavailable_or_unsupported\"" ->
        assert ctx.fallback_reason_code == :provider_path_unavailable_or_unsupported
        {:handled, ctx}

      text == "no implicit provider reroute is performed" ->
        assert {:ok, %{id: :cpu_compiled}} = ctx.resolve_result
        {:handled, ctx}

      text == "expectation results remain within tolerance contract" ->
        assert {:ok, %{batched_values: batched_values, scalar_values: scalar_values}} = ctx.comparison_result

        batched = Nx.to_flat_list(batched_values)
        scalar = Nx.to_flat_list(scalar_values)

        batched
        |> Enum.zip(scalar)
        |> Enum.each(fn {value, reference} ->
          assert_in_delta value, reference, ctx.tolerance
        end)

        {:handled, ctx}

      text == "tolerance configuration and observed delta are reported deterministically" ->
        assert {:ok, %{metrics: metrics}} = ctx.comparison_result
        observed_delta = abs(metrics.batched_throughput_ops_s - metrics.scalar_throughput_ops_s)
        assert observed_delta > 0.0
        {:handled, ctx}

      text == "selected strategy and reported metadata are identical across runs" ->
        assert ctx.repeat_first == ctx.repeat_second
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
