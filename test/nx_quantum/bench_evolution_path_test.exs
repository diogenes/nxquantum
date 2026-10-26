defmodule NxQuantum.BenchEvolutionPathTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy
  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy.Complex
  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy.RealPauliZ
  alias NxQuantum.TestSupport.BenchScenarios

  # Path evidence for the H1.3 width families (R2). The bench calls public
  # facades only; this test may use the internal strategy selector.
  @expected %{"real" => RealPauliZ, "complex" => Complex}

  setup_all do
    table = BenchScenarios.table()
    {fixture, _sha} = BenchScenarios.fixture(table)
    %{fixture: fixture}
  end

  for family <- ["real", "complex"] do
    test "#{family} family selects the expected evolution path at every fixture width", %{fixture: fixture} do
      family = unquote(family)
      widths = fixture["families"][family]["widths"]

      assert map_size(widths) >= 6

      for {width, entry} <- widths, index <- [0, entry["sets"] - 1] do
        n = String.to_integer(width)
        gates = BenchScenarios.family_gates(family, n, Enum.at(entry["k"], index), fixture["layers"])
        circuit = BenchScenarios.build_circuit(n, gates, &Nx.tensor/1)
        specs = BenchScenarios.z_specs(n)

        assert EvolutionStrategy.select(%{circuit | measurement: hd(specs)}) == @expected[family],
               "#{family} family, #{n} qubits, angle set #{index}"
      end
    end
  end
end
