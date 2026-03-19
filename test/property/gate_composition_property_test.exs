defmodule NxQuantum.Property.GateCompositionPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  property "adding gates preserves qubit cardinality" do
    check all(
            qubits <- integer(1..8),
            wire <- integer(0..7)
          ) do
      selected_wire = min(wire, qubits - 1)

      circuit =
        [qubits: qubits]
        |> Circuit.new()
        |> Gates.h(selected_wire)
        |> Gates.rx(selected_wire, theta: Nx.tensor(0.1))

      assert circuit.qubits == qubits
      assert length(circuit.operations) == 2
    end
  end
end
