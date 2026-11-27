defmodule NxQuantum.EstimatorEvolvedCacheTest do
  # Sync on purpose (KG-20). The evolved-state cache is one ETS table shared by every test in the
  # VM, and async tests can delete or evict its entries between the two runs below. Sync modules
  # run after all async modules finish, so this module cannot race them.
  use ExUnit.Case, async: false

  alias NxQuantum.Adapters.Simulators.StateVector.EvolvedStateCache
  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Estimator.Result
  alias NxQuantum.Gates

  setup do
    EvolvedStateCache.reset()
    :ok
  end

  describe "evolved-state cache reporting" do
    test "a repeated run served from the evolved-state cache reports the state-vector method and no evolution path" do
      circuit = real_path_circuit(0.577_215)
      opts = [observables: [:pauli_z], wire: 1]

      assert {:ok, %Result{}} = Estimator.run(circuit, opts)
      assert {:ok, %Result{} = second} = Estimator.run(circuit, opts)

      assert second.metadata.strategy_observability.cache_status == :hit

      assert second.metadata.simulation == %{
               method: :state_vector,
               evolution_path: nil,
               state_backend: :portable,
               expectation_path: :generic
             }
    end
  end

  defp real_path_circuit(theta) do
    [qubits: 2]
    |> Circuit.new()
    |> Gates.h(0)
    |> Gates.cnot(control: 0, target: 1)
    |> Gates.ry(1, theta: Nx.tensor(theta))
  end
end
