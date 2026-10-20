defmodule NxQuantum.Property.TranspilerRoutingEquivalenceTest do
  @moduledoc """
  H1.4 deliverable 3: routed circuits implement the original unitary, up to the output qubit relabelling
  reported by `report.final_layout` (logical qubit l ends on physical wire `final_layout[l]`).

  Random circuits on a line topology force routing. Fixed seed, explicit tolerance.
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Unitary
  alias NxQuantum.Transpiler

  @seed 20_261_020
  @max_runs 40

  property "routed circuits equal the original up to the reported output layout" do
    check all(
            qubits <- integer(2..4),
            spec <- gate_spec(qubits),
            max_runs: @max_runs,
            initial_seed: @seed
          ) do
      circuit = build(spec, qubits)
      topology = {:coupling_map, line_edges(qubits)}

      assert {:ok, routed, report} = Transpiler.run(circuit, topology: topology, mode: :insert_swaps)

      original = Unitary.of(circuit.operations, qubits)
      routed_u = Unitary.of(routed.operations, qubits)
      expected = relabel_outputs(original, report.final_layout, qubits)

      assert Unitary.equal_up_to_phase?(routed_u, expected),
             "routing changed the circuit for #{inspect(spec)} with final layout #{inspect(report.final_layout)}"
    end
  end

  test "identity layout when no routing is needed" do
    circuit = [qubits: 2] |> Circuit.new() |> Gates.cnot(control: 0, target: 1)

    assert {:ok, _routed, report} =
             Transpiler.run(circuit, topology: {:coupling_map, [{0, 1}, {1, 0}]}, mode: :insert_swaps)

    assert report.final_layout == %{0 => 0, 1 => 1}
  end

  defp line_edges(qubits) do
    for i <- 0..(qubits - 2), edge <- [{i, i + 1}, {i + 1, i}], do: edge
  end

  defp gate_spec(qubits) do
    list_of(one_of([single(qubits), pair(qubits)]), max_length: 12)
  end

  defp single(qubits) do
    gen all(name <- member_of([:h, :rz]), wire <- integer(0..(qubits - 1)), theta <- float(min: -3.0, max: 3.0)) do
      {name, wire, theta}
    end
  end

  defp pair(qubits) do
    gen all(c <- integer(0..(qubits - 1)), offset <- integer(1..(qubits - 1))) do
      {:cnot, c, rem(c + offset, qubits)}
    end
  end

  defp build(spec, qubits) do
    Enum.reduce(spec, Circuit.new(qubits: qubits), fn
      {:cnot, c, t}, acc -> Gates.cnot(acc, control: c, target: t)
      {:h, w, _}, acc -> Gates.h(acc, w)
      {:rz, w, t}, acc -> Gates.rz(acc, w, theta: t)
    end)
  end

  # Logical qubit l lives on physical wire final_layout[l] after routing. Row i (logical bits) moves to row j.
  defp relabel_outputs(matrix, layout, qubits) do
    dim = Integer.pow(2, qubits)

    source =
      for j <- 0..(dim - 1) do
        Enum.reduce(0..(qubits - 1), 0, fn l, acc ->
          bit = Bitwise.band(Bitwise.bsr(j, layout[l]), 1)
          Bitwise.bor(acc, Bitwise.bsl(bit, l))
        end)
      end

    Nx.take(matrix, Nx.tensor(source), axis: 0)
  end
end
