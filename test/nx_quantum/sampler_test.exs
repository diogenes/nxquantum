defmodule NxQuantum.SamplerTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
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

  test "batched_run/3 returns deterministic batch counts for fixed seed" do
    builder = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: theta)
    end

    batch = Nx.tensor([0.1, 0.2, 0.3])

    assert {:ok, a} = Sampler.batched_run(builder, batch, shots: 128, seed: 11)
    assert {:ok, b} = Sampler.batched_run(builder, batch, shots: 128, seed: 11)

    assert Enum.map(a, & &1.counts) == Enum.map(b, & &1.counts)
    assert length(a) == 3
  end

  test "batched_run/3 validates rank-1 batch shape" do
    builder = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: theta)
    end

    assert {:error, %{code: :invalid_batch_shape, received: {2, 2}}} =
             Sampler.batched_run(builder, Nx.tensor([[0.1, 0.2], [0.3, 0.4]]), shots: 64, seed: 1)
  end

  test "batched_run/3 parallel preserves deterministic values and ordering" do
    builder = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: theta)
    end

    batch = Nx.tensor([0.1, 0.2, 0.3, 0.4, 0.5], type: {:f, 32})

    assert {:ok, sequential} = Sampler.batched_run(builder, batch, shots: 128, seed: 11)

    assert {:ok, parallel} =
             Sampler.batched_run(builder, batch,
               shots: 128,
               seed: 11,
               parallel: true,
               max_concurrency: 4
             )

    assert Enum.map(sequential, & &1.counts) == Enum.map(parallel, & &1.counts)

    assert Enum.map(sequential, &Nx.to_flat_list(&1.probabilities)) ==
             Enum.map(parallel, &Nx.to_flat_list(&1.probabilities))
  end
end
