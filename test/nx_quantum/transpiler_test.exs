defmodule NxQuantum.TranspilerTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.Transpiler

  test "strict mode returns typed error on unsupported coupling" do
    circuit =
      [qubits: 3]
      |> Circuit.new()
      |> Gates.cnot(control: 0, target: 2)

    assert {:error, %{code: :topology_violation, edge: {0, 2}}} =
             Transpiler.run(circuit, topology: {:coupling_map, [{0, 1}, {1, 2}]}, mode: :strict)
  end

  test "insert_swaps mode returns transpilation report with routing overhead" do
    circuit =
      [qubits: 3]
      |> Circuit.new()
      |> Gates.cnot(control: 0, target: 2)

    assert {:ok, transpiled, report} =
             Transpiler.run(circuit,
               topology: {:coupling_map, [{0, 1}, {1, 2}]},
               mode: :insert_swaps
             )

    assert report.added_swap_gates == 1
    assert report.depth_delta == 2
    assert length(transpiled.operations) > length(circuit.operations)
  end

  test "all_to_all topology incurs no routing overhead" do
    circuit =
      [qubits: 3]
      |> Circuit.new()
      |> Gates.cnot(control: 0, target: 2)

    assert {:ok, _transpiled, report} = Transpiler.run(circuit, topology: :all_to_all, mode: :strict)
    assert report.added_swap_gates == 0
  end
end
