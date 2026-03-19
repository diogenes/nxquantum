defmodule NxQuantum.Features.Steps.CircuitOptimizationSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Compiler
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "circuit_optimization.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_optimization/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: "a circuit with redundant and cancelable gate sequences"}, ctx) do
    circuit =
      [qubits: 1]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.h(0)
      |> Gates.rx(0, theta: 0.2)
      |> Gates.rx(0, theta: 0.3)
      |> Gates.rz(0, theta: 0.0)

    {:handled, Map.put(ctx, :circuit, circuit)}
  end

  defp handle_setup(%{text: "a circuit with repeated adjacent single-qubit rotations"}, ctx) do
    handle_setup(%{text: "a circuit with redundant and cancelable gate sequences"}, ctx)
  end

  defp handle_setup(%{text: text}, ctx) do
    if text =~ ~r/^numerical tolerance is / do
      {:handled, Map.put(ctx, :tolerance, Helpers.parse_quoted_number(text))}
    else
      :unhandled
    end
  end

  defp handle_optimization(%{text: text}, ctx) do
    cond do
      text =~ ~r/^I optimize the circuit with passes / ->
        passes = text |> Helpers.parse_quoted() |> String.split(",") |> Enum.map(&String.to_atom/1)
        {optimized, report} = Compiler.optimize(ctx.circuit, passes: passes)
        {:handled, ctx |> Map.put(:optimized, optimized) |> Map.put(:report, report)}

      text == "I evaluate expectation before and after optimization" ->
        before = Nx.to_number(Circuit.expectation(ctx.circuit, observable: :pauli_z, wire: 0))
        after_v = Nx.to_number(Circuit.expectation(ctx.optimized, observable: :pauli_z, wire: 0))
        {:handled, ctx |> Map.put(:before, before) |> Map.put(:after, after_v)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "the optimized expectation matches the original within tolerance" ->
        assert_in_delta ctx.before, ctx.after, ctx.tolerance
        {:handled, ctx}

      text =~ ~r/^optimization report includes / ->
        key = text |> Helpers.parse_quoted() |> String.to_atom()
        assert Map.has_key?(ctx.report, key)
        {:handled, ctx}

      text =~ ~r/^\"gate_count_after\" is less than \"gate_count_before\"$/ ->
        assert ctx.report.gate_count_after < ctx.report.gate_count_before
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
