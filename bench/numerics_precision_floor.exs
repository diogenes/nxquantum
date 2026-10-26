# Precision-floor evidence for KG-10 (see docs/backend-support.md, "Numerical precision").
#
# Measures how far production expectation values are from a float64 dense
# reference, over fixed-seed random circuits. Circuits and reference come from
# test/support, so the run is deterministic.
#
# Run from the repository root:
#   MIX_ENV=test mix run bench/numerics_precision_floor.exs

alias NxQuantum.TestSupport.NumericsCases

Code.require_file("test/support/dense_reference.ex")
Code.require_file("test/support/random_circuits.ex")
Code.require_file("test/support/numerics_cases.ex")

# Each entry is {|production - float64 reference|, |production - float32(reference)|}.
measure_circuit = fn qubits, ops ->
  for {value, reference} <- NumericsCases.measure(qubits, ops) do
    production = Nx.to_number(value)
    reference32 = reference |> Nx.tensor(type: {:f, 32}) |> Nx.to_number()

    {abs(production - reference), abs(production - reference32)}
  end
end

summarize = fn errors ->
  {raw, rounded} = Enum.unzip(errors)
  exact = Enum.count(rounded, &(&1 == 0.0))

  %{
    max_raw: Enum.max(raw),
    max_rounded: Enum.max(rounded),
    exact_percent: 100 * exact / length(rounded),
    observations: length(errors)
  }
end

IO.puts(
  "| qubits | depth | circuits | observations | max abs error vs float64 | max abs error vs float32(reference) | exact after float32 rounding |"
)

IO.puts("| --- | --- | --- | --- | --- | --- | --- |")

for {qubits, depth, circuits, _seed} = spec <- NumericsCases.cases() do
  errors = spec |> NumericsCases.circuits() |> Enum.map(&measure_circuit.(qubits, &1))

  s = errors |> List.flatten() |> summarize.()

  IO.puts(
    "| #{qubits} | #{depth} | #{circuits} | #{s.observations} | " <>
      "#{:erlang.float_to_binary(s.max_raw, scientific: 2)} | " <>
      "#{:erlang.float_to_binary(s.max_rounded, scientific: 2)} | " <>
      "#{:erlang.float_to_binary(s.exact_percent, decimals: 1)}% |"
  )
end
