defmodule NxQuantum.Compiler.QftReferenceTest do
  @moduledoc """
  H1.4 QFT reference: a QFT circuit built from H, RZ, and CNOT must equal the discrete Fourier transform
  up to global phase. Compared against an explicit DFT matrix, not against the simulator itself.
  """

  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Unitary

  @tol 1.0e-6

  for n <- [1, 2, 3, 4] do
    @n n

    test "QFT on #{n} qubit(s) equals the DFT up to phase and bit order" do
      qubits = @n
      unitary = qubits |> qft() |> Map.fetch!(:operations) |> Unitary.of(qubits)
      dft = dft_matrix(qubits)
      bit_reversed = permute_bits(dft, qubits)

      assert Unitary.equal_up_to_phase?(unitary, dft, @tol) or
               Unitary.equal_up_to_phase?(unitary, bit_reversed, @tol),
             "QFT matrix did not match the DFT under either bit order"
    end
  end

  # QFT with the usual controlled-phase ladder and final swaps.
  defp qft(qubits) do
    circuit =
      Enum.reduce(0..(qubits - 1), Circuit.new(qubits: qubits), fn j, acc ->
        acc = Gates.h(acc, j)

        Enum.reduce((j + 1)..(qubits - 1)//1, acc, fn k, inner ->
          controlled_phase(inner, k, j, :math.pi() / Integer.pow(2, k - j))
        end)
      end)

    Enum.reduce(0..(div(qubits, 2) - 1)//1, circuit, fn i, acc ->
      swap(acc, i, qubits - 1 - i)
    end)
  end

  # CP(theta) up to global phase, from RZ and CNOT.
  defp controlled_phase(circuit, control, target, theta) do
    circuit
    |> Gates.rz(control, theta: theta / 2)
    |> Gates.rz(target, theta: theta / 2)
    |> Gates.cnot(control: control, target: target)
    |> Gates.rz(target, theta: -theta / 2)
    |> Gates.cnot(control: control, target: target)
  end

  defp swap(circuit, a, b) do
    circuit
    |> Gates.cnot(control: a, target: b)
    |> Gates.cnot(control: b, target: a)
    |> Gates.cnot(control: a, target: b)
  end

  defp dft_matrix(qubits) do
    dim = Integer.pow(2, qubits)
    scale = 1 / :math.sqrt(dim)

    rows =
      for j <- 0..(dim - 1) do
        for k <- 0..(dim - 1) do
          angle = 2 * :math.pi() * j * k / dim
          Complex.multiply(Complex.new(scale), Complex.exp(Complex.new(0.0, angle)))
        end
      end

    Nx.tensor(rows, type: {:c, 64})
  end

  # Reorders basis indices by reversing their bits, for statevector conventions that order wires the other way.
  defp permute_bits(matrix, qubits) do
    dim = Integer.pow(2, qubits)
    perm = for i <- 0..(dim - 1), do: reverse_bits(i, qubits)
    index = Nx.tensor(perm)
    matrix |> Nx.take(index, axis: 0) |> Nx.take(index, axis: 1)
  end

  defp reverse_bits(value, qubits) do
    Enum.reduce(0..(qubits - 1), 0, fn bit, acc ->
      acc
      |> Bitwise.bsl(1)
      |> Bitwise.bor(Bitwise.band(Bitwise.bsr(value, bit), 1))
    end)
  end
end
