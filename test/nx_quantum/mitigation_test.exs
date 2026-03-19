defmodule NxQuantum.MitigationTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Mitigation
  alias NxQuantum.Sampler

  test "readout mitigation is deterministic for same calibration and input" do
    circuit = Circuit.new(qubits: 1)
    {:ok, sample} = Sampler.run(circuit, shots: 512, seed: 99)

    calibration = Nx.tensor([[0.95, 0.05], [0.06, 0.94]], type: {:f, 32})

    assert {:ok, out_a} = Mitigation.pipeline(sample, [{:readout, calibration: calibration}])
    assert {:ok, out_b} = Mitigation.pipeline(sample, [{:readout, calibration: calibration}])

    assert Nx.to_flat_list(out_a.probabilities) == Nx.to_flat_list(out_b.probabilities)
    assert length(out_a.metadata.mitigation_trace) == 1
  end

  test "readout mitigation returns typed error for invalid matrix" do
    circuit = Circuit.new(qubits: 1)
    {:ok, sample} = Sampler.run(circuit, shots: 128, seed: 1)

    assert {:error, %{code: :invalid_mitigation_input}} =
             Mitigation.pipeline(sample, [{:readout, calibration: Nx.tensor([1.0, 0.0])}])
  end

  test "zne pass appends deterministic metadata for estimator result" do
    circuit = Circuit.new(qubits: 1)
    {:ok, estimate} = Estimator.run(circuit, observables: [:pauli_z], wire: 0)

    assert {:ok, mitigated} =
             Mitigation.pipeline(estimate, [{:zne_linear, scales: [1.0, 2.0, 3.0]}])

    assert mitigated.metadata.mitigation_trace == [%{pass: :zne_linear, scales: [1.0, 2.0, 3.0]}]
  end
end
