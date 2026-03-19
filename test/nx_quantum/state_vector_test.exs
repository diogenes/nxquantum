defmodule NxQuantum.StateVectorTest do
  use ExUnit.Case, async: true

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
end
