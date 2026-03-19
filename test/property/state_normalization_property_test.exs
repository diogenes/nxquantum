defmodule NxQuantum.Property.StateNormalizationPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias NxQuantum.Adapters.Simulators.StateVector.State
  alias NxQuantum.GateOperation

  property "state-vector norm is preserved for 1-2 qubit deterministic gate sequences" do
    check all(
            qubits <- integer(1..2),
            operations <- list_of(operation_generator(qubits), min_length: 1, max_length: 12)
          ) do
      state =
        qubits
        |> State.initial_state()
        |> State.apply_operations(operations)

      assert_in_delta norm_squared(state), 1.0, 1.0e-5
    end
  end

  defp operation_generator(qubits) do
    wire_generator = integer(0..(qubits - 1))

    single_qubit_gate_generator =
      one_of([
        constant(:h),
        constant(:x),
        constant(:y),
        constant(:z)
      ])

    base_generators = [
      map({single_qubit_gate_generator, wire_generator}, fn {gate, wire} ->
        GateOperation.new(gate, [wire])
      end),
      map({constant(:rx), wire_generator, float(min: -3.14159, max: 3.14159)}, fn {:rx, wire, theta} ->
        GateOperation.new(:rx, [wire], theta: theta)
      end),
      map({constant(:ry), wire_generator, float(min: -3.14159, max: 3.14159)}, fn {:ry, wire, theta} ->
        GateOperation.new(:ry, [wire], theta: theta)
      end),
      map({constant(:rz), wire_generator, float(min: -3.14159, max: 3.14159)}, fn {:rz, wire, theta} ->
        GateOperation.new(:rz, [wire], theta: theta)
      end)
    ]

    generators =
      if qubits > 1 do
        base_generators ++ [cnot_generator(qubits)]
      else
        base_generators
      end

    one_of(generators)
  end

  defp cnot_generator(qubits) do
    map({integer(0..(qubits - 1)), integer(0..(qubits - 1))}, fn {control, target} ->
      if control == target do
        GateOperation.new(:cnot, [0, 1])
      else
        GateOperation.new(:cnot, [control, target])
      end
    end)
  end

  defp norm_squared(state) do
    state
    |> Nx.conjugate()
    |> Nx.multiply(state)
    |> Nx.sum()
    |> Nx.real()
    |> Nx.to_number()
  end
end
