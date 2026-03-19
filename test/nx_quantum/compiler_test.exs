defmodule NxQuantum.CompilerTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Compiler
  alias NxQuantum.Gates

  test "optimizer simplifies, fuses, and cancels operations" do
    circuit =
      [qubits: 1]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.h(0)
      |> Gates.rx(0, theta: 0.1)
      |> Gates.rx(0, theta: 0.2)
      |> Gates.rz(0, theta: 0.0)

    {optimized, report} = Compiler.optimize(circuit, passes: [:simplify, :fuse, :cancel])

    assert report.gate_count_before == 5
    assert report.gate_count_after == 1
    assert hd(optimized.operations).name == :rx
    assert_in_delta Map.fetch!(hd(optimized.operations).params, :theta), 0.3, 1.0e-8
  end
end
