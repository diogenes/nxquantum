defmodule NxQuantum.CompiledScaffoldCacheTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.CompiledScaffoldCache

  setup do
    CompiledScaffoldCache.reset()
    :ok
  end

  test "fetch reuses cached scaffold for same qubits and wire" do
    first = CompiledScaffoldCache.fetch(8, 2)
    assert CompiledScaffoldCache.size() == 1

    second = CompiledScaffoldCache.fetch(8, 2)
    assert CompiledScaffoldCache.size() == 1

    assert Nx.to_flat_list(first.selector) == Nx.to_flat_list(second.selector)
    assert Nx.to_flat_list(first.signs) == Nx.to_flat_list(second.signs)
    assert Nx.to_flat_list(first.flipped_indices) == Nx.to_flat_list(second.flipped_indices)
  end

  test "fetch isolates cache entries by qubits and wire" do
    _ = CompiledScaffoldCache.fetch(8, 0)
    _ = CompiledScaffoldCache.fetch(8, 1)
    _ = CompiledScaffoldCache.fetch(10, 1)

    assert CompiledScaffoldCache.size() == 3
  end
end
