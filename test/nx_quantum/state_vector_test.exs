defmodule NxQuantum.StateVectorTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Simulators.StateVector.Matrices
  alias NxQuantum.Adapters.Simulators.StateVector.State
  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
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
    assert plan.pair_shape == {8, 2, 4}
    assert plan.outer_size == 8
    assert plan.inner_size == 4
    assert plan.trailing_size == 32
    assert plan.state_shape == {64}
  end

  test "single-qubit gate coefficient cache is deterministic" do
    op = GateOperation.new(:ry, [0], theta: 0.3)
    coefficients = Matrices.single_qubit_gate_coefficients(op)
    coefficients_again = Matrices.single_qubit_gate_coefficients(op)

    assert coefficients == coefficients_again
    assert_in_delta Nx.to_number(Nx.real(coefficients.g00)), :math.cos(0.15), 1.0e-7
    assert_in_delta Nx.to_number(Nx.real(coefficients.g01)), -:math.sin(0.15), 1.0e-7
    assert_in_delta Nx.to_number(Nx.real(coefficients.g10)), :math.sin(0.15), 1.0e-7
    assert_in_delta Nx.to_number(Nx.real(coefficients.g11)), :math.cos(0.15), 1.0e-7
  end

  test "compiled execution plan cache is deterministic" do
    operations = [
      GateOperation.new(:h, [0]),
      GateOperation.new(:ry, [1], theta: 0.3),
      GateOperation.new(:cnot, [0, 1])
    ]

    plan = Matrices.compiled_execution_plan(operations, 2)
    plan_again = Matrices.compiled_execution_plan(operations, 2)

    assert plan == plan_again
    assert length(plan) == 3
    assert {:single_qubit, 0, _gate0, _coeff0} = Enum.at(plan, 0)
    assert {:single_qubit, 1, _gate1, _coeff1} = Enum.at(plan, 1)
    assert {:cnot, _perm} = Enum.at(plan, 2)
  end

  test "compiled execution plan fuses consecutive cnot operations" do
    operations = [
      GateOperation.new(:cnot, [0, 1]),
      GateOperation.new(:cnot, [1, 2]),
      GateOperation.new(:cnot, [2, 3]),
      GateOperation.new(:ry, [0], theta: 0.2)
    ]

    plan = Matrices.compiled_execution_plan(operations, 4)

    assert length(plan) == 2
    assert {:cnot, fused_permutation} = Enum.at(plan, 0)
    assert {:single_qubit, 0, _gate, _coefficients} = Enum.at(plan, 1)

    state = State.initial_state(4)
    p01 = Matrices.cnot_permutation(0, 1, 4)
    p12 = Matrices.cnot_permutation(1, 2, 4)
    p23 = Matrices.cnot_permutation(2, 3, 4)

    sequential_state =
      state
      |> Nx.take(p01)
      |> Nx.take(p12)
      |> Nx.take(p23)

    fused_state = Nx.take(state, fused_permutation)

    assert Nx.to_flat_list(sequential_state) == Nx.to_flat_list(fused_state)
  end
end
