defmodule NxQuantum.Transpiler.RouterRouteCircuitTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
  alias NxQuantum.Gates
  alias NxQuantum.Transpiler.Router

  test "single-qubit gates follow the moved layout" do
    circuit =
      [qubits: 3]
      |> Circuit.new()
      |> Gates.cnot(control: 0, target: 2)
      |> Gates.h(0)

    assert {:ok, %{operations: ops, final_layout: layout}} =
             Router.route_circuit(circuit, {:coupling_map, [{0, 1}, {1, 0}, {1, 2}, {2, 1}]})

    assert [%GateOperation{name: :swap, wires: [0, 1]}, %GateOperation{name: :cnot, wires: [1, 2]}, h] = ops
    assert h.wires == [1]
    assert layout == %{0 => 1, 1 => 0, 2 => 2}
  end

  test "gates that are already adjacent are emitted unchanged, with no routing record" do
    circuit = [qubits: 2] |> Circuit.new() |> Gates.cnot(control: 0, target: 1)

    assert {:ok, %{operations: [op], routing: [], final_layout: %{0 => 0, 1 => 1}}} =
             Router.route_circuit(circuit, {:coupling_map, [{0, 1}]})

    assert op.wires == [0, 1]
  end

  test "disconnected topologies return the logical edge that cannot be routed" do
    circuit = [qubits: 3] |> Circuit.new() |> Gates.cnot(control: 0, target: 2)

    assert {:error, {0, 2}} = Router.route_circuit(circuit, {:coupling_map, [{0, 1}]})
  end
end
