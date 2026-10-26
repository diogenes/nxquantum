defmodule NxQuantum.Numerics.PrefixParityAnalyticTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Estimator
  alias NxQuantum.TestSupport.BenchScenarios

  # tol = max(1e-6, B) at 12 qubits (plan v3, section 0): the float32 gate
  # coefficients and float32 value rounding of the NxQuantum lanes.
  @qubits 12
  @tolerance %{"real" => 2.1e-6, "complex" => 1.1e-5}

  setup_all do
    table = BenchScenarios.table()
    {fixture, _sha} = BenchScenarios.fixture(table)
    %{fixture: fixture}
  end

  # Product state of single-qubit rotations followed by CNOT(j, j + 1), j ascending:
  # wire k then carries the parity of wires 0..k, so <Z_k> = prod_{j <= k} cos(theta_j).
  for family <- ["real", "complex"] do
    test "12-qubit prefix-parity circuit matches prod cos(theta_j), #{family} family", %{fixture: fixture} do
      family = unquote(family)
      entry = fixture["prefix_parity"][family][Integer.to_string(@qubits)]

      circuit =
        BenchScenarios.build_circuit(
          @qubits,
          BenchScenarios.prefix_parity_gates(family, @qubits, entry),
          &Nx.tensor/1
        )

      {:ok, result} =
        Estimator.run(circuit, observables: BenchScenarios.z_specs(@qubits), cache_evolved_state: false)

      values = Nx.to_flat_list(result.values)
      expected = BenchScenarios.prefix_parity_expected(entry)

      assert length(values) == @qubits

      worst =
        values
        |> Enum.zip(expected)
        |> Enum.map(fn {got, want} -> abs(got - want) end)
        |> Enum.max()

      assert worst <= @tolerance[family], "max error #{worst} exceeds #{@tolerance[family]}"
    end
  end
end
