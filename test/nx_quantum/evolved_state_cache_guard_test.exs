defmodule NxQuantum.EvolvedStateCacheGuardTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Adapters.Simulators.StateVector
  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  @table :nxq_state_vector_evolved_cache

  setup do
    clear_cache_table()
    :ok
  end

  test "evolved-state cache reuses identical keys and differentiates parameter changes" do
    base = measured_circuit(0.3)

    first = StateVector.expectation(base, runtime_profile: :cpu_portable)
    assert evolved_cache_size() == 1

    second = StateVector.expectation(base, runtime_profile: :cpu_portable)
    assert evolved_cache_size() == 1
    assert_in_delta(Nx.to_number(first), Nx.to_number(second), 1.0e-12)

    changed = measured_circuit(0.31)
    _ = StateVector.expectation(changed, runtime_profile: :cpu_portable)
    assert evolved_cache_size() == 2
  end

  test "cache_evolved_state false bypasses cache writes" do
    circuit = measured_circuit(0.45)

    _ = StateVector.expectation(circuit, runtime_profile: :cpu_portable, cache_evolved_state: false)

    assert evolved_cache_size() == 0
  end

  defp measured_circuit(theta) do
    circuit =
      [qubits: 2]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.ry(1, theta: theta)

    %{circuit | measurement: %{observable: :pauli_z, wire: 1}}
  end

  defp clear_cache_table do
    case :ets.whereis(@table) do
      :undefined ->
        :ok

      table ->
        :ets.delete_all_objects(table)
        :ok
    end
  rescue
    _ -> :ok
  end

  defp evolved_cache_size do
    case :ets.whereis(@table) do
      :undefined -> 0
      table -> :ets.info(table, :size) || 0
    end
  rescue
    _ -> 0
  end
end
