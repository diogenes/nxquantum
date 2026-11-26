defmodule NxQuantum.Adapters.Simulators.StateVector.CacheByteCapTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Adapters.Simulators.StateVector.Cache
  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy
  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  @cap_env :state_vector_structure_cache_max_bytes
  @default_cap 512 * 1024 * 1024

  setup do
    previous_cap = Application.fetch_env(:nx_quantum, @cap_env)
    Cache.reset()

    on_exit(fn ->
      case previous_cap do
        {:ok, value} -> Application.put_env(:nx_quantum, @cap_env, value)
        :error -> Application.delete_env(:nx_quantum, @cap_env)
      end

      Cache.reset()
    end)

    :ok
  end

  test "an entry larger than the byte cap is returned but not retained" do
    put_cap(1_024)
    big = Nx.iota({512}, type: {:s, 64})

    assert Nx.to_flat_list(Cache.fetch(:big_entry, build(:first, big))) == Nx.to_flat_list(big)
    assert_received {:built, :first}

    _ = Cache.fetch(:big_entry, build(:second, big))
    assert_received {:built, :second}

    assert Cache.size() == 0
    assert Cache.total_bytes() == 0
  end

  test "an entry that fits under the cap is retained and hits the cache" do
    put_cap(1_024)
    small = Nx.iota({8}, type: {:s, 64})

    _ = Cache.fetch(:small_entry, build(:first, small))
    assert_received {:built, :first}

    assert Nx.to_flat_list(Cache.fetch(:small_entry, build(:second, small))) == Nx.to_flat_list(small)
    refute_received {:built, :second}

    assert Cache.size() == 1
    assert Cache.total_bytes() == 64
  end

  test "composite values are measured too, not only tensors" do
    put_cap(100)
    pair = {Nx.iota({8}, type: {:s, 64}), Nx.iota({8}, type: {:s, 64})}

    _ = Cache.fetch(:pair, build(:first, pair))
    assert_received {:built, :first}

    _ = Cache.fetch(:pair, build(:second, pair))
    assert_received {:built, :second}
    assert Cache.size() == 0
  end

  test "total bytes stay under the cap and the oldest entries are evicted first" do
    put_cap(160)

    for i <- 1..5 do
      _ = Cache.fetch({:fifo, i}, fn -> Nx.iota({8}, type: {:s, 64}) end)
      assert Cache.total_bytes() <= 160
    end

    assert Cache.size() == 2

    _ = Cache.fetch({:fifo, 5}, build(:newest_kept, Nx.iota({8}, type: {:s, 64})))
    _ = Cache.fetch({:fifo, 4}, build(:second_newest_kept, Nx.iota({8}, type: {:s, 64})))
    refute_received {:built, :newest_kept}
    refute_received {:built, :second_newest_kept}

    _ = Cache.fetch({:fifo, 1}, build(:oldest_evicted, Nx.iota({8}, type: {:s, 64})))
    assert_received {:built, :oldest_evicted}
  end

  test "library default cap is 512 MiB" do
    Application.delete_env(:nx_quantum, @cap_env)

    # Checks the library's own default, not a fallback supplied by this test.
    assert Cache.default_max_bytes() == 512 * 1024 * 1024

    # Probe: 2^20 s64 elements = 8 MiB of tensor data, well under the default cap, so it is retained.
    _ = Cache.fetch(:default_cap_probe, fn -> Nx.iota({1_048_576}, type: {:s, 64}) end)
    assert Cache.total_bytes() == 8 * 1_048_576
    assert Cache.total_bytes() <= @default_cap
  end

  test "evolved states are identical with the structure cache on, off, and over budget" do
    circuit = cnot_ladder_circuit(5)

    on_budget = evolve_in_fresh_process(circuit, @default_cap)
    assert Cache.size() > 0

    off_budget = evolve_in_fresh_process(circuit, 0)
    assert Cache.size() == 0
    assert Cache.total_bytes() == 0

    over_budget = evolve_in_fresh_process(circuit, 1_024)
    assert Cache.total_bytes() <= 1_024

    assert on_budget == off_budget
    assert over_budget == off_budget
  end

  defp put_cap(bytes), do: Application.put_env(:nx_quantum, @cap_env, bytes)

  defp build(tag, value) do
    fn ->
      send(self(), {:built, tag})
      value
    end
  end

  # A fresh process has an empty per-process plan cache, so each run exercises the structure cache.
  defp evolve_in_fresh_process(circuit, cap) do
    put_cap(cap)
    Cache.reset()

    fn ->
      circuit
      |> EvolutionStrategy.evolve()
      |> Nx.to_binary()
    end
    |> Task.async()
    |> Task.await()
  end

  defp cnot_ladder_circuit(qubits) do
    base =
      Enum.reduce(0..(qubits - 1), Circuit.new(qubits: qubits), fn wire, acc ->
        acc |> Gates.h(wire) |> Gates.ry(wire, theta: 0.1 * (wire + 1))
      end)

    ladder = Enum.map(0..(qubits - 2), &{&1, &1 + 1})

    Enum.reduce(ladder ++ Enum.reverse(ladder), base, fn {control, target}, acc ->
      Gates.cnot(acc, control: control, target: target)
    end)
  end
end
