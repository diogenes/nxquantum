defmodule NxQuantum.Features.Steps.VariationalCircuitSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "variational_circuit.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_operations/2, &handle_measurements/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "a circuit with 2 qubits" -> {:handled, Map.put(ctx, :circuit, Circuit.new(qubits: 2))}
      text == "a circuit with 1 qubit" -> {:handled, Map.put(ctx, :circuit, Circuit.new(qubits: 1))}
      true -> :unhandled
    end
  end

  defp handle_operations(%{text: text}, ctx) do
    cond do
      text == "I apply H on wire 0" ->
        {:handled, Map.put(ctx, :circuit, Gates.h(ctx.circuit, 0))}

      text =~ ~r/^I apply RX on wire 0 with theta / ->
        theta = Helpers.parse_quoted_number(text)
        {:handled, Map.put(ctx, :circuit, Gates.rx(ctx.circuit, 0, theta: theta))}

      text == "I apply CNOT from wire 0 to wire 1" ->
        {:handled, Map.put(ctx, :circuit, Gates.cnot(ctx.circuit, control: 0, target: 1))}

      text =~ ~r/^I apply RY on wire \d+ with theta / ->
        [_, wire_value] = Regex.run(~r/^I apply RY on wire (\d+) with theta /, text)
        theta = Helpers.parse_quoted_number(text)
        wire = String.to_integer(wire_value)
        {:handled, Map.put(ctx, :circuit, Gates.ry(ctx.circuit, wire, theta: theta))}

      true ->
        :unhandled
    end
  end

  defp handle_measurements(%{text: text}, ctx) do
    if text =~ ~r/^I measure expectation of Pauli-[XYZ] on wire \d+$/ do
      [_all, observable_label, wire_value] =
        Regex.run(~r/^I measure expectation of (Pauli-[XYZ]) on wire (\d+)$/, text)

      observable = observable_for_label(observable_label)
      wire = String.to_integer(wire_value)
      value = Circuit.expectation(ctx.circuit, observable: observable, wire: wire)
      {:handled, Map.put(ctx, :expectation, value)}
    else
      :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "I receive a scalar tensor expectation value" ->
        assert %Nx.Tensor{} = ctx.expectation
        assert Nx.shape(ctx.expectation) == {}
        {:handled, ctx}

      text =~ ~r/^the scalar value is approximately / ->
        [_, expected, tolerance] =
          Regex.run(~r/the scalar value is approximately "([^"]+)" with tolerance "([^"]+)"/, text)

        assert_in_delta Nx.to_number(ctx.expectation), String.to_float(expected), String.to_float(tolerance)
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp observable_for_label("Pauli-X"), do: :pauli_x
  defp observable_for_label("Pauli-Y"), do: :pauli_y
  defp observable_for_label("Pauli-Z"), do: :pauli_z
end
