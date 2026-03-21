alias NxQuantum.Circuit
alias NxQuantum.Gates
alias NxQuantum.Sampler

iterations =
  case System.argv() do
    [value | _] ->
      case Integer.parse(value) do
        {parsed, ""} when parsed > 0 -> parsed
        _ -> 4000
      end

    _ ->
      4000
  end

circuit =
  [qubits: 2]
  |> Circuit.new()
  |> Gates.h(0)
  |> Gates.cnot(control: 0, target: 1)
  |> Gates.ry(1, theta: Nx.tensor(0.3))

builder = fn theta ->
  [qubits: 2]
  |> Circuit.new()
  |> Gates.h(0)
  |> Gates.cnot(control: 0, target: 1)
  |> Gates.ry(1, theta: theta)
end

batch = Nx.broadcast(Nx.tensor(0.3, type: {:f, 32}), {iterations})

measure = fn fun ->
  {microseconds, _} = :timer.tc(fun)
  total_ms = microseconds / 1000.0
  per_op_ms = total_ms / iterations
  ops_s = iterations / (microseconds / 1_000_000.0)
  %{total_ms: total_ms, per_op_ms: per_op_ms, ops_s: ops_s}
end

scalar =
  measure.(fn ->
    Enum.each(1..iterations, fn _ ->
      {:ok, _} = Sampler.run(circuit, shots: 256, seed: 11)
    end)
  end)

batch_seq =
  measure.(fn ->
    {:ok, _} =
      Sampler.batched_run(builder, batch,
        shots: 256,
        seed: 11
      )
  end)

batch_parallel =
  measure.(fn ->
    {:ok, _} =
      Sampler.batched_run(builder, batch,
        shots: 256,
        seed: 11,
        parallel: true,
        max_concurrency: System.schedulers_online()
      )
  end)

for {label, stats} <- [scalar: scalar, batch_seq: batch_seq, batch_parallel: batch_parallel] do
  IO.puts(
    "SAMPLER_PAR_BENCH label=#{label} total_ms=#{Float.round(stats.total_ms, 6)} per_op_ms=#{Float.round(stats.per_op_ms, 6)} ops_s=#{Float.round(stats.ops_s, 6)}"
  )
end
