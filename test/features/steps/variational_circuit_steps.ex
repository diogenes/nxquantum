defmodule NxQuantum.Features.Steps.VariationalCircuitSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "variational_circuit.feature"

  @impl true
  def execute(%{text: text}, ctx) do
    cond do
      text == "a circuit with 2 qubits" ->
        Map.put(ctx, :circuit, Circuit.new(qubits: 2))

      text == "a circuit with 1 qubit" ->
        Map.put(ctx, :circuit, Circuit.new(qubits: 1))

      text == "I apply H on wire 0" ->
        Map.put(ctx, :circuit, Gates.h(ctx.circuit, 0))

      text =~ ~r/^I apply RX on wire 0 with theta / ->
        theta = Helpers.parse_quoted_number(text)
        Map.put(ctx, :circuit, Gates.rx(ctx.circuit, 0, theta: theta))

      text == "I apply CNOT from wire 0 to wire 1" ->
        Map.put(ctx, :circuit, Gates.cnot(ctx.circuit, control: 0, target: 1))

      text =~ ~r/^I apply RY on wire \d+ with theta / ->
        [_, wire_value] = Regex.run(~r/^I apply RY on wire (\d+) with theta /, text)
        theta = Helpers.parse_quoted_number(text)
        wire = String.to_integer(wire_value)
        Map.put(ctx, :circuit, Gates.ry(ctx.circuit, wire, theta: theta))

      text =~ ~r/^I measure expectation of Pauli-[XYZ] on wire \d+$/ ->
        [_all, observable_label, wire_value] =
          Regex.run(~r/^I measure expectation of (Pauli-[XYZ]) on wire (\d+)$/, text)

        observable =
          case observable_label do
            "Pauli-X" -> :pauli_x
            "Pauli-Y" -> :pauli_y
            "Pauli-Z" -> :pauli_z
          end

        wire = String.to_integer(wire_value)
        value = Circuit.expectation(ctx.circuit, observable: observable, wire: wire)
        Map.put(ctx, :expectation, value)

      text == "I receive a scalar tensor expectation value" ->
        assert %Nx.Tensor{} = ctx.expectation
        assert Nx.shape(ctx.expectation) == {}
        ctx

      text =~ ~r/^the scalar value is approximately / ->
        [_, expected, tolerance] =
          Regex.run(~r/the scalar value is approximately "([^"]+)" with tolerance "([^"]+)"/, text)

        assert_in_delta Nx.to_number(ctx.expectation), String.to_float(expected), String.to_float(tolerance)
        ctx

      true ->
        raise "unhandled step: #{text}"
    end
  end
end
