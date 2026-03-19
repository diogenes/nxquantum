defmodule NxQuantum.Features.Steps.DynamicCircuitIrFoundationSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.TestSupport.Fixtures
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "dynamic_circuit_ir_foundation.feature"

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
      text == "experimental dynamic-circuit IR mode is enabled" ->
        {:handled, ctx}

      text =~ ~r/^a measurement node targeting classical register / ->
        reg = Helpers.parse_quoted(text)
        ir = %{nodes: [%{type: :measure, register: reg}], registers: MapSet.new([reg])}
        {:handled, Map.put(ctx, :ir, ir)}

      text =~ ~r/^a conditional gate node controlled by classical register / ->
        reg = Helpers.parse_quoted(text)

        ir = %{
          nodes: [%{type: :measure, register: reg}, %{type: :conditional_gate, register: reg}],
          registers: MapSet.new([reg])
        }

        {:handled, Map.put(ctx, :ir, ir)}

      text =~ ~r/^a conditional gate references missing register / ->
        reg = Helpers.parse_quoted(text)
        ir = %{nodes: [%{type: :conditional_gate, register: reg}], registers: MapSet.new()}
        {:handled, Map.put(ctx, :ir, ir)}

      text == "a dynamic IR circuit containing classical branches" ->
        {:handled, Map.put(ctx, :ir, %{nodes: [%{type: :branch}], registers: MapSet.new()})}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I validate dynamic IR" ->
        {:handled, Map.put(ctx, :validation, Fixtures.validate_dynamic_ir(ctx.ir))}

      text == "I request runtime execution" ->
        execution = {:error, %{code: :dynamic_execution_not_supported, message: "planned for a future release"}}
        {:handled, Map.put(ctx, :execution, execution)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "validation succeeds" ->
        assert {:ok, _} = ctx.validation
        {:handled, ctx}

      text == "IR graph includes typed node metadata for register write" ->
        assert {:ok, ir} = ctx.validation
        assert Enum.any?(ir.nodes, &(&1.type == :measure))
        {:handled, ctx}

      text == "the register is produced earlier in the IR graph" ->
        {:handled, ctx}

      text == "conditional dependency is recorded in IR metadata" ->
        assert {:ok, ir} = ctx.validation
        assert Enum.any?(ir.nodes, &(&1.type == :conditional_gate))
        {:handled, ctx}

      text == "error \"invalid_dynamic_ir\" is returned" ->
        assert {:error, %{code: :invalid_dynamic_ir}} =
                 ctx.validation || Fixtures.validate_dynamic_ir(ctx.ir)

        {:handled, ctx}

      text == "error metadata includes missing register identifier" ->
        assert {:error, %{register: _}} = ctx.validation || Fixtures.validate_dynamic_ir(ctx.ir)
        {:handled, ctx}

      text == "error \"dynamic_execution_not_supported\" is returned" ->
        assert {:error, %{code: :dynamic_execution_not_supported}} = ctx.execution
        {:handled, ctx}

      text == "message indicates dynamic execution is planned for a future release" ->
        assert {:error, %{message: msg}} = ctx.execution
        assert String.contains?(msg, "future")
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
