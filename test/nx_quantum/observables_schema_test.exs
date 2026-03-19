defmodule NxQuantum.Observables.SchemaTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Observables.Error
  alias NxQuantum.Observables.Schema

  describe "normalize_observable/1" do
    test "returns normalized supported observable" do
      assert {:ok, :pauli_z} = Schema.normalize_observable(:pauli_z)
    end

    test "returns typed error for unsupported observable" do
      assert {:error, %{code: :unsupported_observable, observable: :foo}} =
               Schema.normalize_observable(:foo)
    end
  end

  describe "measurement/3" do
    test "validates observable and wire against qubit count" do
      assert {:ok, %{observable: :pauli_x, wire: 1}} = Schema.measurement(:pauli_x, 1, 2)
    end

    test "returns typed error for out-of-range measurement wire" do
      assert {:error, %{code: :measurement_wire_out_of_range, wire: 2, qubits: 2}} =
               Schema.measurement(:pauli_x, 2, 2)
    end

    test "bang variant raises typed observable error" do
      assert_raise Error, fn ->
        Schema.measurement!(:invalid, 0, 1)
      end
    end
  end
end
