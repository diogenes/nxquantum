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

  test "simplify keeps batched rotations unless every angle is negligible (regression: crashed)" do
    batched = [qubits: 1] |> Circuit.new() |> Gates.rx(0, theta: Nx.tensor([0.1, 0.2]))
    zeros = [qubits: 1] |> Circuit.new() |> Gates.rx(0, theta: Nx.tensor([0.0, 0.0]))

    assert {kept, _} = Compiler.optimize(batched, passes: [:simplify])
    assert length(kept.operations) == 1

    assert {removed, _} = Compiler.optimize(zeros, passes: [:simplify])
    assert removed.operations == []
  end

  test "resynthesize_1q reduces run cost while preserving expectations" do
    circuit =
      [qubits: 1]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.x(0)
      |> Gates.h(0)
      |> Gates.rz(0, theta: 0.3)
      |> Gates.rz(0, theta: 0.4)

    {optimized, report} = Compiler.optimize(circuit, passes: [:resynthesize_1q])

    assert report.gate_count_after < report.gate_count_before

    before_x = circuit |> Circuit.expectation(observable: :pauli_x, wire: 0) |> Nx.to_number()
    after_x = optimized |> Circuit.expectation(observable: :pauli_x, wire: 0) |> Nx.to_number()

    before_y = circuit |> Circuit.expectation(observable: :pauli_y, wire: 0) |> Nx.to_number()
    after_y = optimized |> Circuit.expectation(observable: :pauli_y, wire: 0) |> Nx.to_number()

    before_z = circuit |> Circuit.expectation(observable: :pauli_z, wire: 0) |> Nx.to_number()
    after_z = optimized |> Circuit.expectation(observable: :pauli_z, wire: 0) |> Nx.to_number()

    assert_in_delta after_x, before_x, 1.0e-6
    assert_in_delta after_y, before_y, 1.0e-6
    assert_in_delta after_z, before_z, 1.0e-6
  end

  test "compile/2 exposes deterministic profile diagnostics and report fields" do
    circuit =
      [qubits: 2]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)

    target = %{
      gateset: [:h, :cnot, :rx, :ry, :rz],
      coupling_map: [{0, 1}]
    }

    assert {:ok, %{circuit: compiled, report: report}} =
             Compiler.compile(circuit,
               target: target,
               optimization_level: 2,
               routing_strategy: :sabre_like,
               scheduling_strategy: :asap,
               calibration_profile: :fidelity_first
             )

    assert match?(%Circuit{}, compiled)
    assert report.optimization_level == 2
    assert report.routing.strategy == :sabre_like
    assert report.scheduling.strategy == :asap
    assert report.cost_model.profile == :fidelity_first
    assert is_list(report.diagnostics)
    assert report.rejected_alternatives.routing == [:shortest_path]
  end

  test "compile/2 returns typed error for invalid optimization level" do
    circuit = Circuit.new(qubits: 1)

    assert {:error, %{code: :compiler_invalid_target, stage: :validation}} =
             Compiler.compile(circuit, optimization_level: 99)
  end
end
