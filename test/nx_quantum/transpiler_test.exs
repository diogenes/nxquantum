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

  test "heavy-hex topology produces deterministic routing metadata" do
    circuit =
      [qubits: 3]
      |> Circuit.new()
      |> Gates.cnot(control: 0, target: 2)

    topology = {:heavy_hex, [{0, 1}, {1, 2}]}

    assert {:ok, transpiled_a, report_a} = Transpiler.run(circuit, topology: topology, mode: :insert_swaps)
    assert {:ok, _transpiled_b, report_b} = Transpiler.run(circuit, topology: topology, mode: :insert_swaps)

    assert report_a == report_b
    assert transpiled_a.metadata.topology == topology
    assert report_a.topology_id == :heavy_hex
    assert report_a.routing_path == [0, 1, 2]
    assert report_a.inserted_swaps == [{0, 1}]
    assert report_a.routed_edges == [{1, 2}]
    assert report_a.added_swap_gates == 1
  end
end
