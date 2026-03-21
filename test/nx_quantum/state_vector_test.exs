defmodule NxQuantum.StateVectorTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Simulators.StateVector.Matrices
  alias NxQuantum.Adapters.Simulators.StateVector.State
  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  test "expectation of |0> on Pauli-Z is 1" do
    expectation =
      [qubits: 1]
      |> Circuit.new()
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
      |> Nx.to_number()

    assert_in_delta expectation, 1.0, 1.0e-6
  end

  test "ry(pi) rotates |0> to |1> and expectation z is -1" do
    expectation =
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: :math.pi())
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
      |> Nx.to_number()

    assert_in_delta expectation, -1.0, 1.0e-5
  end

  test "hadamard creates equal superposition and expectation z is 0" do
    expectation =
      [qubits: 1]
      |> Circuit.new()
      |> Gates.h(0)
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
      |> Nx.to_number()

    assert_in_delta expectation, 0.0, 1.0e-6
  end

  test "ry(pi/2) yields Pauli-X expectation 1 and Pauli-Y expectation 0" do
    circuit =
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: :math.pi() / 2.0)

    expectation_x =
      circuit
      |> Circuit.expectation(observable: :pauli_x, wire: 0)
      |> Nx.to_number()

    expectation_y =
      circuit
      |> Circuit.expectation(observable: :pauli_y, wire: 0)
      |> Nx.to_number()

    assert_in_delta expectation_x, 1.0, 1.0e-5
    assert_in_delta expectation_y, 0.0, 1.0e-5
  end

  test "bell state has deterministic zero Pauli-Z expectation on the second qubit" do
    expectation =
      [qubits: 2]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)
      |> Circuit.expectation(observable: :pauli_z, wire: 1)
      |> Nx.to_number()

    assert_in_delta expectation, 0.0, 1.0e-6
  end

  test "pauli-z fast expectation matches dense observable expectation" do
    qubits = 3

    state =
      [qubits: qubits]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.ry(1, theta: 0.41)
      |> Gates.cnot(control: 1, target: 2)
      |> then(fn circuit ->
        State.apply_operations(State.initial_state(qubits), circuit.operations)
      end)

    wire = 2
    observable_matrix = Matrices.observable_matrix(:pauli_z, wire, qubits)

    dense = state |> State.expectation_from_state(observable_matrix) |> Nx.to_number()
    fast = state |> State.expectation_pauli_z(wire, qubits) |> Nx.to_number()

    assert_in_delta fast, dense, 1.0e-8
  end

  test "single-qubit layout plan is deterministic" do
    plan = Matrices.single_qubit_layout_plan(2, 6)
    plan_again = Matrices.single_qubit_layout_plan(2, 6)

    assert plan == plan_again
    assert plan.transpose_axes == [3, 0, 1, 2, 4, 5]
    assert plan.inverse_axes == [1, 2, 3, 0, 4, 5]
    assert plan.qubit_shape == {2, 2, 2, 2, 2, 2}
    assert plan.unflatten_shape == {2, 2, 2, 2, 2, 2}
    assert plan.trailing_size == 32
    assert plan.state_shape == {64}
  end
end
