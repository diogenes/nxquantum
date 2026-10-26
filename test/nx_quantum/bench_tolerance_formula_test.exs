defmodule NxQuantum.BenchToleranceFormulaTest do
  use ExUnit.Case, async: true

  alias NxQuantum.TestSupport.BenchScenarios

  # Recomputes every NxQuantum family and continuity tolerance in
  # bench/scenarios/python_alternatives.json from the written formula
  #
  #   tol = max(1e-6, B rounded up to 2 significant figures),
  #   B   = (2 * kappa * G1 + c0 + xy_units) * u,   u = 2^-24, kappa = a * sqrt(2) + b
  #
  # and asserts it equals the table value, so a hand edit of a tolerance cannot
  # drift from its derivation.
  @lanes ["nxquantum_cpu_portable", "nxquantum_cpu_compiled"]
  @u :math.pow(2, -24)

  setup_all do
    %{table: BenchScenarios.table()}
  end

  defp kappa([a, b]), do: a * :math.sqrt(2) + b

  defp bound(formula, g1, xy_units) do
    (2 * kappa(formula["kappa"]) * g1 + formula["c0"] + xy_units) * @u
  end

  defp tolerance(b, floor) do
    exponent = trunc(Float.floor(:math.log10(b))) - 1
    quantum = :math.pow(10, exponent)
    max(floor, Float.ceil(b / quantum) * quantum)
  end

  for family <- ["real", "complex"], width <- [4, 8, 12, 16, 20, 24] do
    test "#{family} family tolerance at #{width} qubits follows the formula", %{table: table} do
      family = unquote(family)
      width = unquote(width)
      formula = table["tolerance_formula"]
      spec = formula["families"][family]

      expected = tolerance(bound(spec, spec["g1_per_qubit"] * width, 0), formula["floor"])
      tolerances = table["tolerances"][family][Integer.to_string(width)]

      for lane <- @lanes do
        assert_in_delta tolerances[lane], expected, 1.0e-12, "#{family} #{width}q #{lane}"
      end
    end
  end

  for scenario <- ["baseline_2q", "deep_6q", "batch_obs_8q", "state_reuse_8q_xy"] do
    test "continuity tolerance of #{scenario} follows the formula", %{table: table} do
      scenario_id = unquote(scenario)
      formula = table["tolerance_formula"]
      spec = formula["continuity"][scenario_id]

      worst =
        spec["xy_units"]
        |> Map.values()
        |> Enum.map(&bound(spec, spec["g1"], &1))
        |> Enum.max()

      expected = tolerance(worst, formula["floor"])

      for lane <- @lanes do
        assert_in_delta table["scenarios"][scenario_id]["tolerance"][lane], expected, 1.0e-12, "#{scenario_id} #{lane}"
      end
    end
  end

  test "the competitor lanes stay at 1e-6 on every scenario that gates them", %{table: table} do
    for {id, scenario} <- table["scenarios"],
        scenario["tolerance"],
        lane <- ["qiskit", "pennylane", "cirq_c128_equivalence"] do
      assert scenario["tolerance"][lane] == 1.0e-6, "#{id} #{lane}"
    end
  end

  test "cirq_c64 is gated at 1e-6 on sampled scenarios and ungated elsewhere", %{table: table} do
    for {id, scenario} <- table["scenarios"] do
      expected = if String.starts_with?(scenario["kind"], "sampled"), do: 1.0e-6

      actual =
        case scenario do
          %{"tolerance" => tol} -> tol["cirq_c64"]
          %{"tolerance_ref" => [family, width]} -> table["tolerances"][family][width]["cirq_c64"]
        end

      assert actual == expected, id
    end
  end
end
