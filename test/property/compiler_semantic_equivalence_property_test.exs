defmodule NxQuantum.Property.CompilerSemanticEquivalencePropertyTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Compiler
  alias NxQuantum.TestSupport.DenseReference
  alias NxQuantum.TestSupport.RandomCircuits

  @seed_sets [{11, 22, 33}, {44, 55, 66}, {77, 88, 99}]
  @circuits_per_seed 12
  @max_qubits 6
  @max_depth 18

  # Exact rewrites (simplify, fuse, cancel) are held to 1e-9. resynthesize_1q
  # reads Euler angles from complex64 gate matrices, so its floor is ~1e-7; it is
  # held to its documented `resynthesis_tolerance` (1e-6) instead. `nil` runs
  # the optimizer's default pass list, which includes resynthesis.
  @exact_tolerance 1.0e-9
  @resynthesis_tolerance 1.0e-6

  @pass_sets [
    [:simplify],
    [:fuse],
    [:cancel],
    [:resynthesize_1q],
    [:simplify, :fuse, :cancel],
    nil
  ]

  test "each pass and the default pipeline preserve the unitary up to global phase" do
    for seed <- @seed_sets, {{qubits, ops}, index} <- Enum.with_index(generate(seed)), passes <- @pass_sets do
      circuit = %Circuit{qubits: qubits, operations: ops}
      expected = DenseReference.unitary(qubits, ops)

      {optimized, _report} = if passes, do: Compiler.optimize(circuit, passes: passes), else: Compiler.optimize(circuit)

      actual = DenseReference.unitary(qubits, optimized.operations)
      distance = DenseReference.distance_up_to_phase(actual, expected)

      assert distance < tolerance_for(passes),
             "seed #{inspect(seed)} circuit #{index} passes #{inspect(passes)}: distance #{distance}"
    end
  end

  defp tolerance_for(nil), do: @resynthesis_tolerance
  defp tolerance_for(passes), do: if(:resynthesize_1q in passes, do: @resynthesis_tolerance, else: @exact_tolerance)

  defp generate(seed) do
    {circuits, _state} =
      Enum.map_reduce(1..@circuits_per_seed, RandomCircuits.seeded(seed), fn _, state ->
        {qubits, state} = :rand.uniform_s(@max_qubits, state)
        {depth, state} = :rand.uniform_s(@max_depth, state)
        {ops, state} = RandomCircuits.operations(state, qubits, depth)
        {{qubits, ops}, state}
      end)

    circuits
  end
end
