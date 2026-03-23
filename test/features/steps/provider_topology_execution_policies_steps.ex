defmodule NxQuantum.Features.Steps.ProviderTopologyExecutionPoliciesSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Gates
  alias NxQuantum.Transpiler

  @impl true
  def feature, do: "provider_topology_execution_policies.feature"

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
      text == "heavy-hex target topology is selected" ->
        circuit =
          [qubits: 3]
          |> Circuit.new()
          |> Gates.cnot(control: 0, target: 2)

        {:handled,
         Map.merge(ctx, %{
           circuit: circuit,
           topology: {:heavy_hex, [{0, 1}, {1, 2}]},
           mode: :insert_swaps
         })}

      text == "all-to-all target topology is selected" ->
        circuit =
          [qubits: 3]
          |> Circuit.new()
          |> Gates.cnot(control: 0, target: 2)

        {:handled,
         Map.merge(ctx, %{
           circuit: circuit,
           topology: :all_to_all,
           mode: :strict
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: "transpilation runs"}, ctx) do
    {:handled, Map.put(ctx, :transpile_result, Transpiler.run(ctx.circuit, topology: ctx.topology, mode: ctx.mode))}
  end

  defp handle_execution(_step, _ctx), do: :unhandled

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "swap insertion and depth delta are reported deterministically" ->
        assert {:ok, _transpiled, report} = ctx.transpile_result
        assert report.topology_id == :heavy_hex
        assert report.added_swap_gates == 1
        assert report.depth_delta == 2
        {:handled, ctx}

      text == "routed edges are included in routing metadata" ->
        assert {:ok, _transpiled, report} = ctx.transpile_result
        assert report.routed_edges == [{1, 2}]
        {:handled, ctx}

      text == "logical-to-physical mapping is included in routing metadata" ->
        assert {:ok, _transpiled, report} = ctx.transpile_result
        assert report.routing_path == [0, 1, 2]
        assert report.inserted_swaps == [{0, 1}]
        {:handled, ctx}

      text == "swap insertion is minimized or zero by policy" ->
        assert {:ok, _transpiled, report} = ctx.transpile_result
        assert report.added_swap_gates == 0
        {:handled, ctx}

      text == "routing metadata explicitly reports zero or minimal swap behavior" ->
        assert {:ok, _transpiled, report} = ctx.transpile_result
        assert report.routed_edges == []
        assert report.routing_path == nil
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
