defmodule NxQuantum.Property.TranspilerRoutingEquivalencePropertyTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.TestSupport.DenseReference
  alias NxQuantum.TestSupport.RandomCircuits
  alias NxQuantum.Transpiler

  @seed_sets [{1001, 2002, 3003}, {4004, 5005, 6006}, {7007, 8008, 9009}]
  @circuits_per_seed 10
  @max_depth 14
  @tolerance 1.0e-9

  test "insert_swaps output is topology-conformant and equals the input up to the final layout" do
    for seed <- @seed_sets, {qubits, ops, index} <- generate(seed), topology <- [:line, :ring], qubits >= 2 do
      edges = coupling_edges(topology, qubits)
      circuit = %Circuit{qubits: qubits, operations: ops}

      assert {:ok, routed, report} =
               Transpiler.run(circuit, topology: {:coupling_map, edges}, mode: :insert_swaps),
             "seed #{inspect(seed)} circuit #{index} #{topology}: routing failed"

      assert Enum.all?(routed.operations, &supported?(&1, edges)),
             "seed #{inspect(seed)} circuit #{index} #{topology}: non-native CNOT left in output"

      layout = report.logical_to_physical_map || identity_layout(qubits)
      expected = qubits |> DenseReference.unitary(ops) |> DenseReference.permute_rows(qubits, layout)
      actual = DenseReference.unitary(qubits, routed.operations)
      distance = DenseReference.distance_up_to_phase(actual, expected)

      assert distance < @tolerance,
             "seed #{inspect(seed)} circuit #{index} #{topology}: distance #{distance}"
    end
  end

  defp generate(seed) do
    {circuits, _state} =
      Enum.map_reduce(1..@circuits_per_seed, RandomCircuits.seeded(seed), fn index, state ->
        {qubits, state} = :rand.uniform_s(5, state)
        {depth, state} = :rand.uniform_s(@max_depth, state)
        {ops, state} = RandomCircuits.operations(state, qubits + 1, depth)
        {{qubits + 1, ops, index}, state}
      end)

    circuits
  end

  defp coupling_edges(:line, qubits), do: for(i <- 0..(qubits - 2), do: {i, i + 1})

  defp coupling_edges(:ring, qubits) do
    coupling_edges(:line, qubits) ++ [{qubits - 1, 0}]
  end

  defp supported?(%{name: :cnot, wires: [a, b]}, edges), do: {a, b} in edges or {b, a} in edges
  defp supported?(_op, _edges), do: true

  defp identity_layout(qubits), do: Map.new(0..(qubits - 1), &{&1, &1})
end
