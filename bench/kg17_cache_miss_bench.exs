# KG-17 benchmark: state-vector structure cache, miss path.
#
# Runs a 20-qubit CNOT ladder (forward and back) in a fresh process per iteration, so every
# structure-cache lookup is a miss. Prints wall time of the evolve and the bytes the structure
# cache retains afterwards. The retained bytes are read from the ETS table directly, so the same
# script works on branches with and without byte accounting.
#
# Run:
#   NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mise exec -- mix run bench/kg17_cache_miss_bench.exs
#
# Determinism: the circuit has no random inputs (fixed angles). The seed is set for the harness only.

alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy
alias NxQuantum.Circuit
alias NxQuantum.Gates

:rand.seed(:exsss, {0, 0, 0})

qubits = 20
iterations = 3
table = :nxq_state_vector_matrix_cache

circuit = fn ->
  base =
    Enum.reduce(0..(qubits - 1), Circuit.new(qubits: qubits), fn wire, acc ->
      acc |> Gates.h(wire) |> Gates.ry(wire, theta: 0.1 * (wire + 1))
    end)

  ladder = Enum.map(0..(qubits - 2), &{&1, &1 + 1})

  Enum.reduce(ladder ++ Enum.reverse(ladder), base, fn {control, target}, acc ->
    Gates.cnot(acc, control: control, target: target)
  end)
end

# Sum of the bytes held by the structure cache. Tensors count their data size; other terms count
# their external term size. Works with rows of any shape whose second element is the value.
retained = fn ->
  case :ets.whereis(table) do
    :undefined ->
      {0, 0}

    tid ->
      rows = :ets.tab2list(tid)

      bytes =
        Enum.reduce(rows, 0, fn row, acc ->
          value = elem(row, 1)

          acc +
            case value do
              %Nx.Tensor{} -> Nx.byte_size(value)
              other -> :erlang.external_size(other)
            end
        end)

      {length(rows), bytes}
  end
end

run_once = fn ->
  task =
    Task.async(fn ->
      c = circuit.()
      {micros, _state} = :timer.tc(fn -> c |> EvolutionStrategy.evolve() |> Nx.to_binary() end)
      {entries, bytes} = retained.()
      {micros, entries, bytes}
    end)

  Task.await(task, :infinity)
end

# Warm-up run (not reported) so module loading does not count against the first iteration.
_ = run_once.()

results = for _ <- 1..iterations, do: run_once.()

IO.puts("kg17_cache_miss_bench qubits=#{qubits} seed=0 iterations=#{iterations}")

Enum.with_index(results, 1)
|> Enum.each(fn {{micros, entries, bytes}, i} ->
  IO.puts(
    "iteration=#{i} miss_wall_ms=#{Float.round(micros / 1000, 2)} " <>
      "retained_entries=#{entries} retained_bytes=#{bytes}"
  )
end)

best_ms = results |> Enum.map(fn {micros, _, _} -> micros end) |> Enum.min() |> Kernel./(1000)
IO.puts("best_miss_wall_ms=#{Float.round(best_ms, 2)}")
