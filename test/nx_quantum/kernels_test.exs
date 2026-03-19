defmodule NxQuantum.KernelsTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Kernels
  alias NxQuantum.TestSupport.Fixtures

  test "kernel matrix is deterministic and symmetric" do
    x =
      Nx.tensor([
        [0.0, 0.0],
        [1.0, 0.2],
        [0.5, -0.8]
      ])

    k1 = Kernels.matrix(x, gamma: 0.5)
    k2 = Kernels.matrix(x, gamma: 0.5)

    assert Nx.shape(k1) == {3, 3}
    assert Nx.to_flat_list(k1) == Nx.to_flat_list(k2)
    assert Fixtures.symmetric?(k1, 1.0e-10)
  end
end
