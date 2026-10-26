defmodule NxQuantum.TestSupport.NumericsCases do
  @moduledoc """
  Fixed-seed circuit cases and the float64 dense reference shared by the
  numerics evidence scripts (`bench/numerics_precision_floor.exs` and
  `bench/numerics_digest.exs`).

  Every draw comes from `RandomCircuits` with an explicit seed triple, so one
  case always yields the same circuits.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
  alias NxQuantum.TestSupport.DenseReference
  alias NxQuantum.TestSupport.RandomCircuits

  @type case_spec :: {pos_integer(), pos_integer(), pos_integer(), {integer(), integer(), integer()}}

  # {qubits, depth, circuits, seed}. The dense reference is limited to 6 qubits.
  @cases [
    {4, 18, 10, {4, 1, 1}},
    {6, 18, 10, {6, 1, 1}},
    {6, 200, 5, {6, 2, 2}}
  ]

  @paulis [pauli_x: :x, pauli_y: :y, pauli_z: :z]

  @spec cases() :: [case_spec()]
  def cases, do: @cases

  @doc "Operation lists for one case, drawn in order from the seeded state."
  @spec circuits(case_spec()) :: [[GateOperation.t()]]
  def circuits({qubits, depth, count, seed}) do
    {ops_lists, _state} =
      Enum.map_reduce(1..count, RandomCircuits.seeded(seed), fn _, state ->
        RandomCircuits.operations(state, qubits, depth)
      end)

    ops_lists
  end

  @doc """
  Production expectation (tensor) and float64 reference (float) for every
  wire and Pauli observable of one circuit.
  """
  @spec measure(pos_integer(), [GateOperation.t()]) :: [{Nx.Tensor.t(), float()}]
  def measure(qubits, ops) do
    psi =
      qubits
      |> DenseReference.unitary(ops)
      |> Nx.slice([0, 0], [Integer.pow(2, qubits), 1])
      |> Nx.reshape({Integer.pow(2, qubits)})

    for wire <- 0..(qubits - 1), {observable, gate} <- @paulis do
      m = DenseReference.unitary(qubits, [GateOperation.new(gate, [wire])])

      reference =
        psi
        |> then(&Nx.dot(m, &1))
        |> then(&Nx.multiply(Nx.conjugate(psi), &1))
        |> Nx.real()
        |> Nx.sum()
        |> Nx.to_number()

      production = Circuit.expectation(%Circuit{qubits: qubits, operations: ops}, observable: observable, wire: wire)

      {production, reference}
    end
  end
end
