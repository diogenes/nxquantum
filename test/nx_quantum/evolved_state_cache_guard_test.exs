defmodule NxQuantum.EvolvedStateCacheGuardTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Adapters.Simulators.StateVector
  alias NxQuantum.Adapters.Simulators.StateVector.EvolvedStateCache
  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  setup do
    EvolvedStateCache.reset()
    :ok
  end

  test "evolved-state cache reuses identical keys and differentiates parameter changes" do
    base = measured_circuit(0.3)

    first = StateVector.expectation(base, runtime_profile: :cpu_portable)
    assert EvolvedStateCache.size() == 1

    second = StateVector.expectation(base, runtime_profile: :cpu_portable)
    assert EvolvedStateCache.size() == 1
    assert_in_delta(Nx.to_number(first), Nx.to_number(second), 1.0e-12)

    changed = measured_circuit(0.31)
    _ = StateVector.expectation(changed, runtime_profile: :cpu_portable)
    assert EvolvedStateCache.size() == 2
  end

  test "cache_evolved_state false bypasses cache writes" do
    circuit = measured_circuit(0.45)

    _ = StateVector.expectation(circuit, runtime_profile: :cpu_portable, cache_evolved_state: false)

    assert EvolvedStateCache.size() == 0
  end

  test "ttl expiry rebuilds evolved-state cache entries" do
    first =
      EvolvedStateCache.fetch(:ttl_key, fn -> Nx.tensor([1.0, 2.0], type: {:f, 32}) end,
        evolved_state_cache_ttl_ms: 1,
        evolved_state_cache_max_bytes: 1_024
      )

    assert EvolvedStateCache.size() == 1
    :timer.sleep(5)

    second =
      EvolvedStateCache.fetch(:ttl_key, fn -> Nx.tensor([3.0, 4.0], type: {:f, 32}) end,
        evolved_state_cache_ttl_ms: 1,
        evolved_state_cache_max_bytes: 1_024
      )

    assert Nx.to_flat_list(first) == [1.0, 2.0]
    assert Nx.to_flat_list(second) == [3.0, 4.0]
    assert EvolvedStateCache.size() == 1
  end

  test "byte cap evicts oldest entries first" do
    base_opts = [evolved_state_cache_max_bytes: 16, evolved_state_cache_ttl_ms: :infinity]

    _ = EvolvedStateCache.fetch(:a, fn -> Nx.tensor([1.0, 1.0], type: {:f, 32}) end, base_opts)
    _ = EvolvedStateCache.fetch(:b, fn -> Nx.tensor([2.0, 2.0], type: {:f, 32}) end, base_opts)
    _ = EvolvedStateCache.fetch(:c, fn -> Nx.tensor([3.0, 3.0], type: {:f, 32}) end, base_opts)

    rebuilt_a =
      EvolvedStateCache.fetch(:a, fn -> Nx.tensor([9.0, 9.0], type: {:f, 32}) end, base_opts)

    rebuilt_b =
      EvolvedStateCache.fetch(:b, fn -> Nx.tensor([99.0, 99.0], type: {:f, 32}) end, base_opts)

    cached_c =
      EvolvedStateCache.fetch(:c, fn -> Nx.tensor([99.0, 99.0], type: {:f, 32}) end, base_opts)

    assert Nx.to_flat_list(rebuilt_a) == [9.0, 9.0]
    assert Nx.to_flat_list(rebuilt_b) == [99.0, 99.0]
    assert Nx.to_flat_list(cached_c) == [3.0, 3.0]
    assert EvolvedStateCache.total_bytes() <= 16
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
end
