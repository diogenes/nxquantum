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

      text == "I apply H on wire 0" ->
        Map.put(ctx, :circuit, Gates.h(ctx.circuit, 0))

      text =~ ~r/^I apply RX on wire 0 with theta / ->
        theta = Helpers.parse_quoted_number(text)
        Map.put(ctx, :circuit, Gates.rx(ctx.circuit, 0, theta: theta))

      text == "I apply CNOT from wire 0 to wire 1" ->
        Map.put(ctx, :circuit, Gates.cnot(ctx.circuit, control: 0, target: 1))

      text =~ ~r/^I apply RY on wire 1 with theta / ->
        theta = Helpers.parse_quoted_number(text)
        Map.put(ctx, :circuit, Gates.ry(ctx.circuit, 1, theta: theta))

      text == "I measure expectation of Pauli-Z on wire 1" ->
        value = Circuit.expectation(ctx.circuit, observable: :pauli_z, wire: 1)
        Map.put(ctx, :expectation, value)

      text == "I receive a scalar tensor expectation value" ->
        assert %Nx.Tensor{} = ctx.expectation
        assert Nx.shape(ctx.expectation) == {}
        ctx

      true ->
        raise "unhandled step: #{text}"
    end
  end
end
