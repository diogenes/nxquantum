defmodule NxQuantum.Compiler.GateIdentitiesTest do
  @moduledoc """
  H1.4 gate-identity catalog. Each identity is checked against an explicit reference unitary and tagged
  with the compiler pass it justifies. Also guards the helper itself: it must reject non-equivalent circuits.
  """

  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Unitary

  @tol 1.0e-6

  defp ops(qubits, fun), do: [qubits: qubits] |> Circuit.new() |> fun.() |> Map.fetch!(:operations)
  defp unitary(qubits, fun), do: Unitary.of(ops(qubits, fun), qubits)

  defp matrix(rows) do
    rows |> Enum.map(fn row -> Enum.map(row, &Complex.new/1) end) |> Nx.tensor(type: {:c, 64})
  end

  # Pass: cancel. X X = I
  test "cancel: X·X = I" do
    assert Unitary.equal_up_to_phase?(unitary(1, &(&1 |> Gates.x(0) |> Gates.x(0))), eye(2), @tol)
  end

  # Pass: cancel. CNOT·CNOT = I
  test "cancel: CNOT·CNOT = I" do
    cnot = fn c -> Gates.cnot(c, control: 0, target: 1) end
    assert Unitary.equal_up_to_phase?(unitary(2, &(&1 |> cnot.() |> cnot.())), eye(4), @tol)
  end

  # Pass: simplify. H·H = I
  test "simplify: H·H = I" do
    assert Unitary.equal_up_to_phase?(unitary(1, &(&1 |> Gates.h(0) |> Gates.h(0))), eye(2), @tol)
  end

  # Pass: fuse. Rx(a)·Rx(b) = Rx(a+b)
  test "fuse: Rx(a)·Rx(b) = Rx(a+b)" do
    composed = unitary(1, &(&1 |> Gates.rx(0, theta: 0.4) |> Gates.rx(0, theta: 0.9)))
    single = unitary(1, &Gates.rx(&1, 0, theta: 1.3))
    assert Unitary.equal_up_to_phase?(composed, single, @tol)
  end

  # Pass: simplify. Rz(0) = I
  test "simplify: Rz(0) = I" do
    assert Unitary.equal_up_to_phase?(unitary(1, &Gates.rz(&1, 0, theta: 0.0)), eye(2), @tol)
  end

  # Pass: resynthesize_1q. Any single-qubit run is equivalent to one rotation sequence; checked by the property suite.

  # Identity corrected from the 2026 research report: conjugating CNOT by H on the TARGET gives CZ.
  # (The report wrote (H⊗H)·CNOT·(H⊗H), which swaps control and target and is not CZ.)
  test "reference: (I⊗H)·CNOT·(I⊗H) = CZ" do
    conjugated =
      unitary(2, fn c ->
        c
        |> Gates.h(1)
        |> Gates.cnot(control: 0, target: 1)
        |> Gates.h(1)
      end)

    cz = matrix([[1, 0, 0, 0], [0, 1, 0, 0], [0, 0, 1, 0], [0, 0, 0, -1]])
    assert Unitary.equal_up_to_phase?(conjugated, cz, @tol)
  end

  test "helper rejects non-equivalent circuits (guards against vacuous equivalence tests)" do
    refute Unitary.equal_up_to_phase?(unitary(1, &Gates.h(&1, 0)), unitary(1, &Gates.x(&1, 0)), @tol)
    refute Unitary.equal_up_to_phase?(unitary(1, &Gates.rx(&1, 0, theta: 0.1)), eye(2), @tol)
  end

  test "helper accepts global phase differences" do
    z = unitary(1, &Gates.z(&1, 0))
    assert Unitary.equal_up_to_phase?(z, Nx.multiply(z, Complex.new(0.0, 1.0)), @tol)
  end

  defp eye(dim) do
    rows = for i <- 0..(dim - 1), do: for(j <- 0..(dim - 1), do: if(i == j, do: 1, else: 0))
    matrix(rows)
  end
end
