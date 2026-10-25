defmodule NxQuantum.QftReferenceTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.DenseReference

  @tolerance 1.0e-9
  # Measured: Nx.ifft on 2^odd sizes deviates from the float64 DFT by ~1.2e-8
  # (n=1: 1.21e-8, n=3: 6.05e-9, n=5: 3.03e-9); 2^even sizes are ~1e-15.
  # The FFT comparison therefore uses 1e-7, a 10x margin over the worst case.
  @fft_tolerance 1.0e-7

  test "QFT built from gates equals the DFT with e^{+2 pi i jk/N} and 1/sqrt(N) normalization" do
    for qubits <- 1..5 do
      unitary = qubits |> qft() |> operations() |> then(&DenseReference.unitary(qubits, &1))
      dft = inverse_dft(qubits)

      distance = DenseReference.distance_up_to_phase(unitary, dft)
      assert distance < @tolerance, "QFT on #{qubits} qubits: distance #{distance}"
    end
  end

  test "QFT matches Nx.ifft column by column, up to normalization" do
    for qubits <- 1..5 do
      dim = Integer.pow(2, qubits)
      unitary = qubits |> qft() |> operations() |> then(&DenseReference.unitary(qubits, &1))

      # Nx.ifft of each basis vector is (1/N) * column of the inverse-sign DFT.
      scaled = Nx.multiply(Nx.transpose(Nx.ifft(Nx.eye(dim, type: {:c, 128}))), :math.sqrt(dim))
      distance = DenseReference.distance_up_to_phase(unitary, scaled)

      assert distance < @fft_tolerance, "QFT vs Nx.ifft on #{qubits} qubits: distance #{distance}"
    end
  end

  test "sign convention is discriminated: forward FFT does not match the QFT for 2+ qubits" do
    for qubits <- 2..4 do
      dim = Integer.pow(2, qubits)
      unitary = qubits |> qft() |> operations() |> then(&DenseReference.unitary(qubits, &1))

      forward = Nx.multiply(Nx.transpose(Nx.fft(Nx.eye(dim, type: {:c, 128}))), :math.sqrt(dim))
      distance = DenseReference.distance_up_to_phase(unitary, forward)

      assert distance > 1.0e-3, "forward FFT unexpectedly matched QFT on #{qubits} qubits"
    end
  end

  defp qft(qubits) do
    circuit =
      Enum.reduce(0..(qubits - 1)//1, Circuit.new(qubits: qubits), fn target, acc ->
        acc = Gates.h(acc, target)

        Enum.reduce((target + 1)..(qubits - 1)//1, acc, fn control, inner ->
          controlled_phase(inner, control, target, :math.pi() / Integer.pow(2, control - target))
        end)
      end)

    Enum.reduce(0..(div(qubits, 2) - 1)//1, circuit, fn i, acc ->
      swap(acc, i, qubits - 1 - i)
    end)
  end

  # Controlled-phase by theta, as three CNOTs and four RZ rotations. Each
  # RZ(lambda) equals U1(lambda) up to a global phase, which the comparison ignores.
  defp controlled_phase(circuit, control, target, theta) do
    circuit
    |> Gates.rz(target, theta: theta / 2)
    |> Gates.cnot(control: control, target: target)
    |> Gates.rz(target, theta: -theta / 2)
    |> Gates.cnot(control: control, target: target)
    |> Gates.rz(control, theta: theta / 2)
  end

  defp swap(circuit, a, b) do
    circuit
    |> Gates.cnot(control: a, target: b)
    |> Gates.cnot(control: b, target: a)
    |> Gates.cnot(control: a, target: b)
  end

  defp operations(%Circuit{operations: operations}), do: operations

  # Analytic DFT in float64: F[j, k] = e^{+2 pi i jk / N} / sqrt(N).
  defp inverse_dft(qubits) do
    dim = Integer.pow(2, qubits)
    scale = 1.0 / :math.sqrt(dim)

    cells = for j <- 0..(dim - 1), k <- 0..(dim - 1), do: 2.0 * :math.pi() * (j * k) / dim
    re = cells |> Enum.map(&(scale * :math.cos(&1))) |> Nx.tensor(type: {:f, 64}) |> Nx.reshape({dim, dim})
    im = cells |> Enum.map(&(scale * :math.sin(&1))) |> Nx.tensor(type: {:f, 64}) |> Nx.reshape({dim, dim})

    Nx.complex(re, im)
  end
end
