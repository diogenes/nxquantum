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
  # drift from its derivation. Inputs are hard-coded below.
  @lanes ["nxquantum_cpu_portable", "nxquantum_cpu_compiled"]

  # Formula inputs are pinned HERE, not read from the table, so editing an input
  # and the derived values in one commit to the table still fails this test.
  @u :math.pow(2, -24)
  @floor 1.0e-6
  @real %{kappa: [1, 0], g1_per_qubit: 9, c0: 1}
  @complex %{kappa: [2, 1], g1_per_qubit: 16, c0: 3}
  @families %{"real" => @real, "complex" => @complex}

  # Continuity scenarios: kappa path, G1, c0 and the X/Y float32 sum units per lane.
  # 131 = 2^(n-1) + 3 for n = 8 (cpu_compiled X/Y sum on EXLA); 3 is the portable sum;
  # the +1 in the basis strings is c0.
  @continuity %{
    "baseline_2q" => %{kappa: [1, 0], g1: 2, c0: 1, xy: [0, 0]},
    "deep_6q" => %{kappa: [1, 0], g1: 7, c0: 1, xy: [0, 0]},
    "batch_obs_8q" => %{kappa: [2, 1], g1: 11, c0: 1, xy: [3, 2 ** 7 + 3]},
    "state_reuse_8q_xy" => %{kappa: [2, 1], g1: 11, c0: 1, xy: [3, 2 ** 7 + 3]}
  }

  setup_all do
    %{table: BenchScenarios.table()}
  end

  defp kappa([a, b]), do: a * :math.sqrt(2) + b

  defp bound(spec, g1, xy_units) do
    (2 * kappa(spec.kappa) * g1 + spec.c0 + xy_units) * @u
  end

  defp tolerance(b) do
    exponent = trunc(Float.floor(:math.log10(b))) - 1
    quantum = :math.pow(10, exponent)
    max(@floor, Float.ceil(b / quantum) * quantum)
  end

  test "the xy unit constant 131 is 2^(n-1)+3 at n = 8" do
    assert 2 ** (8 - 1) + 3 == 131
  end

  test "the table's tolerance_formula block matches the pinned constants", %{table: table} do
    formula = table["tolerance_formula"]
    assert formula["u"] == "2^-24"
    assert formula["floor"] == @floor
    assert formula["rounding"] == "ceil to 2 significant figures"

    for {name, spec} <- @families do
      assert formula["families"][name] == %{
               "kappa" => spec.kappa,
               "g1_per_qubit" => spec.g1_per_qubit,
               "c0" => spec.c0
             }
    end

    assert formula["continuity"] |> Map.keys() |> Enum.sort() == @continuity |> Map.keys() |> Enum.sort()

    for {id, spec} <- @continuity do
      [portable, compiled] = spec.xy

      assert formula["continuity"][id] == %{
               "kappa" => spec.kappa,
               "g1" => spec.g1,
               "c0" => spec.c0,
               "xy_units" => %{"cpu_portable" => portable, "cpu_compiled" => compiled}
             }
    end
  end

  for family <- ["real", "complex"], width <- [4, 8, 12, 16, 20, 24] do
    test "#{family} family tolerance at #{width} qubits follows the formula", %{table: table} do
      family = unquote(family)
      width = unquote(width)
      spec = Map.fetch!(@families, family)

      expected = tolerance(bound(spec, spec.g1_per_qubit * width, 0))
      tolerances = table["tolerances"][family][Integer.to_string(width)]

      for lane <- @lanes do
        assert_in_delta tolerances[lane], expected, 1.0e-12, "#{family} #{width}q #{lane}"
      end
    end
  end

  for scenario <- ["baseline_2q", "deep_6q", "batch_obs_8q", "state_reuse_8q_xy"] do
    test "continuity tolerance of #{scenario} follows the formula", %{table: table} do
      scenario_id = unquote(scenario)
      spec = Map.fetch!(@continuity, scenario_id)

      expected = spec.xy |> Enum.map(&bound(spec, spec.g1, &1)) |> Enum.max() |> tolerance()

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
