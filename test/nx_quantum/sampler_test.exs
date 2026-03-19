defmodule NxQuantum.SamplerTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Sampler
  alias NxQuantum.Sampler.Result

  test "run/2 returns deterministic sampled results for fixed seed" do
    circuit = Circuit.new(qubits: 1)

    assert {:ok, %Result{} = a} = Sampler.run(circuit, shots: 256, seed: 13)
    assert {:ok, %Result{} = b} = Sampler.run(circuit, shots: 256, seed: 13)

    assert a.counts == b.counts
    assert Nx.to_flat_list(a.probabilities) == Nx.to_flat_list(b.probabilities)
  end

  test "run/2 validates shots" do
    circuit = Circuit.new(qubits: 1)

    assert {:error, %{code: :invalid_shots}} = Sampler.run(circuit, shots: 0)
  end
end
