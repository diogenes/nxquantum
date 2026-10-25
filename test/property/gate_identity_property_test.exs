defmodule NxQuantum.Property.GateIdentityPropertyTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Compiler.PassPipeline
  alias NxQuantum.TestSupport.DenseReference
  alias NxQuantum.TestSupport.GateIdentities
  alias NxQuantum.TestSupport.RandomCircuits

  @seed_sets [{101, 202, 303}, {404, 505, 606}, {707, 808, 909}]
  @samples_per_identity 8
  @identity_tolerance 1.0e-12
  @pass_tolerance 1.0e-9
  # resynthesize_1q reads angles from complex64 matrices (see the compiler
  # property test); it is held to its documented resynthesis_tolerance.
  @resynthesis_tolerance 1.0e-6

  test "every catalogued identity holds, and the pass it names preserves it" do
    catalog = GateIdentities.catalog()

    for identity <- catalog, seed <- @seed_sets do
      state = RandomCircuits.seeded(seed)

      {angle_sets, _state} =
        Enum.map_reduce(1..@samples_per_identity, state, fn _, st ->
          Enum.map_reduce(1..max(identity.angles, 1)//1, st, fn _, s ->
            {u, s} = :rand.uniform_s(s)
            {(2.0 * u - 1.0) * :math.pi(), s}
          end)
        end)

      for raw_angles <- angle_sets do
        angles = Enum.take(raw_angles, identity.angles)
        lhs = identity.lhs.(angles)
        rhs = identity.rhs.(angles)
        qubits = identity.qubits

        lhs_unitary = DenseReference.unitary(qubits, lhs)
        rhs_unitary = DenseReference.unitary(qubits, rhs)

        assert DenseReference.distance_up_to_phase(lhs_unitary, rhs_unitary) < @identity_tolerance,
               "identity #{identity.id} does not hold for angles #{inspect(angles)}"

        optimized = PassPipeline.run(identity.pass, lhs, [])
        optimized_unitary = DenseReference.unitary(qubits, optimized)
        tolerance = if identity.pass == :resynthesize_1q, do: @resynthesis_tolerance, else: @pass_tolerance

        assert DenseReference.distance_up_to_phase(optimized_unitary, lhs_unitary) < tolerance,
               "pass #{identity.pass} changed identity #{identity.id} (seed #{inspect(seed)})"
      end
    end
  end

  test "the catalogue covers every compiler pass" do
    covered = MapSet.new(GateIdentities.catalog(), & &1.pass)

    assert MapSet.equal?(covered, MapSet.new([:simplify, :fuse, :cancel, :resynthesize_1q]))
  end
end
