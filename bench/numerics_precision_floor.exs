# Precision-floor evidence for KG-10 (see docs/backend-support.md, "Numerical precision").
#
# Measures how far production expectation values are from a float64 dense
# reference, over fixed-seed random circuits. Circuits and reference come from
# test/support, so the run is deterministic.
#
# Run from the repository root:
#   MIX_ENV=test mix run bench/numerics_precision_floor.exs

alias NxQuantum.Circuit
alias NxQuantum.GateOperation
alias NxQuantum.TestSupport.DenseReference
alias NxQuantum.TestSupport.RandomCircuits

Code.require_file("test/support/dense_reference.ex")
Code.require_file("test/support/random_circuits.ex")

# {qubits, depth, circuits, seed}. The dense reference is limited to 6 qubits.
cases = [
  {4, 18, 10, {4, 1, 1}},
  {6, 18, 10, {6, 1, 1}},
  {6, 200, 5, {6, 2, 2}}
]

paulis = [pauli_x: :x, pauli_y: :y, pauli_z: :z]

# Each entry is {|production - float64 reference|, |production - float32(reference)|}.
measure_circuit = fn qubits, ops ->
  psi =
    qubits
    |> DenseReference.unitary(ops)
    |> Nx.slice([0, 0], [Integer.pow(2, qubits), 1])
    |> Nx.reshape({Integer.pow(2, qubits)})

  for wire <- 0..(qubits - 1), {observable, gate} <- paulis do
    m = DenseReference.unitary(qubits, [GateOperation.new(gate, [wire])])

    reference =
      psi
      |> then(&Nx.dot(m, &1))
      |> then(&Nx.multiply(Nx.conjugate(psi), &1))
      |> Nx.real()
      |> Nx.sum()
      |> Nx.to_number()

    production =
      %Circuit{qubits: qubits, operations: ops}
      |> Circuit.expectation(observable: observable, wire: wire)
      |> Nx.to_number()

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

for {qubits, depth, circuits, seed} <- cases do
  {errors, _state} =
    Enum.map_reduce(1..circuits, RandomCircuits.seeded(seed), fn _, state ->
      {ops, state} = RandomCircuits.operations(state, qubits, depth)
      {measure_circuit.(qubits, ops), state}
    end)

  s = errors |> List.flatten() |> summarize.()

  IO.puts(
    "| #{qubits} | #{depth} | #{circuits} | #{s.observations} | " <>
      "#{:erlang.float_to_binary(s.max_raw, scientific: 2)} | " <>
      "#{:erlang.float_to_binary(s.max_rounded, scientific: 2)} | " <>
      "#{:erlang.float_to_binary(s.exact_percent, decimals: 1)}% |"
  )
end
