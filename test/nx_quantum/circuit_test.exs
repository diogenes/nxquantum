defmodule NxQuantum.CircuitTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Circuit.Error
  alias NxQuantum.Gates

  describe "new/1" do
    test "creates a circuit with configured qubits" do
      circuit = Circuit.new(qubits: 2)

      assert circuit.qubits == 2
      assert circuit.operations == []
      assert circuit.measurement == nil
      assert circuit.bindings == %{}
    end

    test "raises typed error for invalid qubit count" do
      assert_raise Error, fn ->
        Circuit.new(qubits: 0)
      end
    end
  end

  describe "gate application" do
    test "appends gate operations in order" do
      circuit =
        [qubits: 2]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 1)

      assert length(circuit.operations) == 2
      assert Enum.map(circuit.operations, & &1.name) == [:h, :cnot]
    end

    test "raises typed error for out-of-range wire" do
      assert_raise Error, fn ->
        [qubits: 2]
        |> Circuit.new()
        |> Gates.h(2)
      end
    end

    test "raises typed error when control and target are equal" do
      assert_raise Error, fn ->
        [qubits: 2]
        |> Circuit.new()
        |> Gates.cnot(control: 1, target: 1)
      end
    end
  end

  describe "bind/2" do
    test "stores and merges circuit parameter bindings" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Circuit.bind(theta: Nx.tensor(0.2))
        |> Circuit.bind(%{phi: Nx.tensor(0.3)})

      assert Map.has_key?(circuit.bindings, :theta)
      assert Map.has_key?(circuit.bindings, :phi)
    end

    test "raises typed error for invalid bind params shape" do
      assert_raise Error, fn ->
        [qubits: 1]
        |> Circuit.new()
        |> Circuit.bind("not-a-map")
      end
    end
  end

  describe "expectation/2" do
    test "raises typed error for unsupported observable" do
      assert_raise Error, fn ->
        [qubits: 1]
        |> Circuit.new()
        |> Circuit.expectation(observable: :unsupported, wire: 0)
      end
    end

    test "raises typed error for out-of-range measurement wire" do
      assert_raise Error, fn ->
        [qubits: 1]
        |> Circuit.new()
        |> Circuit.expectation(observable: :pauli_z, wire: 1)
      end
    end
  end
end
