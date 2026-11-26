# KG-17 benchmark: state-vector structure cache, miss path.
#
# Runs a 20-qubit CNOT ladder (forward and back) in a fresh process per iteration, so every
# structure-cache lookup is a miss. Prints wall time of the evolve and the bytes the structure
# cache retains afterwards. The retained bytes are read from the ETS table directly, so the same
# script works on branches with and without byte accounting.
#
# Run:
#   NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 KG17_LABEL=branch mix run bench/kg17_cache_miss_bench.exs
#
# Output: one "KG17 <label> run=<i> ms=<float> retained_bytes=<int>" line per run, then one
# "KG17 <label> median_ms=<float> retained_bytes=<int>" line. KG17_LABEL defaults to "branch".
#
# Determinism: the circuit has no random inputs (fixed angles). The seed is set for the harness only.

alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy
alias NxQuantum.Circuit
alias NxQuantum.Gates

:rand.seed(:exsss, {0, 0, 0})

qubits = 20
iterations = 5
# Label prefixes every result line so branch and main runs can be told apart in one CI log.
label = System.get_env("KG17_LABEL", "branch")
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

IO.puts("kg17_cache_miss_bench label=#{label} qubits=#{qubits} seed=0 iterations=#{iterations}")

# Per-run lines: wall time of the miss path in ms, and bytes retained by the structure cache.
rows =
  results
  |> Enum.with_index(1)
  |> Enum.map(fn {{micros, _entries, bytes}, i} -> {i, micros / 1000, bytes} end)

Enum.each(rows, fn {i, ms, bytes} ->
  IO.puts("KG17 #{label} run=#{i} ms=#{Float.round(ms, 2)} retained_bytes=#{bytes}")
end)

# iterations is odd (5), so the median is the middle sample of each sorted list.
median = fn values -> values |> Enum.sort() |> Enum.at(div(length(values), 2)) end
median_ms = rows |> Enum.map(fn {_, ms, _} -> ms end) |> median.()
median_bytes = rows |> Enum.map(fn {_, _, bytes} -> bytes end) |> median.()

IO.puts("KG17 #{label} median_ms=#{Float.round(median_ms, 2)} retained_bytes=#{median_bytes}")
