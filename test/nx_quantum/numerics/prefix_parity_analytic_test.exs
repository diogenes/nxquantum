defmodule NxQuantum.Numerics.PrefixParityAnalyticTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Estimator
  alias NxQuantum.TestSupport.BenchScenarios

  # tol = max(1e-6, B rounded up to 2 significant figures), B = (2*kappa*G1 + c0)*u,
  # u = 2^-24, with n = 12 and an exact CNOT chain (a permutation, no rounding):
  #   real:    kappa = sqrt(2),       G1 = n,     c0 = 1 -> B = 2.083e-6 -> 2.1e-6
  #   complex: kappa = 2*sqrt(2) + 1, G1 = 2n,    c0 = 3 -> B = 1.113e-5 -> 1.2e-5
  # For a unit-norm observable |d<P>| <= 2*|d psi| + |d psi|^2.
  @qubits 12
  @tolerance %{"real" => 2.1e-6, "complex" => 1.2e-5}

  setup_all do
    table = BenchScenarios.table()
    {fixture, _sha} = BenchScenarios.fixture(table)
    %{fixture: fixture}
  end

  # Product state of single-qubit rotations followed by CNOT(j, j + 1), j ascending:
  # wire k then carries the parity of wires 0..k, so <Z_k> = prod_{j <= k} cos(theta_j).
  for family <- ["real", "complex"] do
    test "12-qubit prefix-parity circuit matches prod_{j<=k} cos(theta_j), theta_w=(w+1)/64, #{family} family", %{
      fixture: fixture
    } do
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
      # The identity only discriminates while the expected values stay far from 0.
      assert Enum.min(Enum.map(expected, &abs/1)) > 0.9

      worst =
        values
        |> Enum.zip(expected)
        |> Enum.map(fn {got, want} -> abs(got - want) end)
        |> Enum.max()

      assert worst <= @tolerance[family], "max error #{worst} exceeds #{@tolerance[family]}"
    end
  end
end
