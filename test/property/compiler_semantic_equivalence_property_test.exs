defmodule NxQuantum.Property.CompilerSemanticEquivalenceTest do
  @moduledoc """
  H1.4: every compiler pass, and the full optimization pipeline, preserves the circuit unitary up to global phase.

  Random circuits come from StreamData with a fixed initial seed, so every run checks the same cases.
  Tolerance is explicit (`1.0e-6` relative to dimension).
  """

  use ExUnit.Case, async: true
  use ExUnitProperties

  alias NxQuantum.Circuit
  alias NxQuantum.Compiler
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Unitary

  @seed 20_261_019
  @max_runs 60

  property "single-qubit passes preserve the unitary up to global phase" do
    check all(
            qubits <- integer(1..3),
            spec <- circuit_spec(qubits),
            pass <- member_of([:simplify, :fuse, :cancel, :resynthesize_1q]),
            max_runs: @max_runs,
            initial_seed: @seed
          ) do
      assert_pass_preserves(spec, qubits, [pass])
    end
  end

  property "the full optimization pipeline preserves the unitary up to global phase" do
    check all(
            qubits <- integer(1..3),
            spec <- circuit_spec(qubits),
            max_runs: @max_runs,
            initial_seed: @seed
          ) do
      assert_pass_preserves(spec, qubits, [:simplify, :fuse, :cancel, :resynthesize_1q, :simplify])
    end
  end

  defp assert_pass_preserves(spec, qubits, passes) do
    circuit = build(spec, qubits)
    {optimized, report} = Compiler.optimize(circuit, passes: passes)

    before = Unitary.of(circuit.operations, qubits)
    after_ = Unitary.of(optimized.operations, qubits)

    assert Unitary.equal_up_to_phase?(before, after_),
           "passes #{inspect(passes)} changed the unitary for #{inspect(spec)}"

    assert report.gate_count_after <= report.gate_count_before
  end

  defp circuit_spec(qubits) do
    gate = one_of([single_gate(qubits), two_gate(qubits)])
    list_of(gate, max_length: 16)
  end

  defp single_gate(qubits) do
    gen all(
          name <- member_of([:h, :x, :y, :z, :rx, :ry, :rz]),
          wire <- integer(0..(qubits - 1)),
          theta <- float(min: -3.1, max: 3.1)
        ) do
      {name, wire, theta}
    end
  end

  defp two_gate(qubits) when qubits >= 2 do
    gen all(
          control <- integer(0..(qubits - 1)),
          offset <- integer(1..(qubits - 1)),
          target = rem(control + offset, qubits)
        ) do
      {:cnot, control, target}
    end
  end

  defp two_gate(_qubits) do
    gen all(wire <- constant(0)) do
      {:h, wire, 0.0}
    end
  end

  defp build(spec, qubits) do
    Enum.reduce(spec, Circuit.new(qubits: qubits), fn
      {:cnot, c, t}, circuit -> Gates.cnot(circuit, control: c, target: t)
      {:h, w, _}, circuit -> Gates.h(circuit, w)
      {:x, w, _}, circuit -> Gates.x(circuit, w)
      {:y, w, _}, circuit -> Gates.y(circuit, w)
      {:z, w, _}, circuit -> Gates.z(circuit, w)
      {:rx, w, t}, circuit -> Gates.rx(circuit, w, theta: t)
      {:ry, w, t}, circuit -> Gates.ry(circuit, w, theta: t)
      {:rz, w, t}, circuit -> Gates.rz(circuit, w, theta: t)
    end)
  end
end
