defmodule NxQuantum.TestSupport.RandomCircuits do
  @moduledoc """
  Deterministic random operation lists for property-style checks.

  Every draw comes from an explicit `:rand` state built from a caller-supplied
  seed triple, so one seed set always yields the same circuits. Repeated gates
  are generated on purpose, to exercise cancellation and fusion.
  """

  alias NxQuantum.GateOperation

  @single_qubit [:h, :x, :y, :z, :rx, :ry, :rz]
  @rotations [:rx, :ry, :rz]

  @spec seeded({integer(), integer(), integer()}) :: :rand.state()
  def seeded({a, b, c}), do: :rand.seed_s(:exsss, {a, b, c})

  @spec operations(:rand.state(), pos_integer(), non_neg_integer()) ::
          {[GateOperation.t()], :rand.state()}
  def operations(state, qubits, depth) do
    {reversed, state} =
      Enum.reduce(1..depth//1, {[], state}, fn _, {acc, st} ->
        {op, st} = next_operation(acc, qubits, st)
        {[op | acc], st}
      end)

    {Enum.reverse(reversed), state}
  end

  defp next_operation(acc, qubits, state) do
    {roll, state} = :rand.uniform_s(state)

    cond do
      acc != [] and roll < 0.2 -> {hd(acc), state}
      qubits >= 2 and roll < 0.5 -> cnot(qubits, state)
      true -> single(qubits, state)
    end
  end

  defp single(qubits, state) do
    {index, state} = :rand.uniform_s(length(@single_qubit), state)
    kind = Enum.at(@single_qubit, index - 1)
    {wire, state} = :rand.uniform_s(qubits, state)

    if kind in @rotations do
      {theta, state} = angle(state)
      {GateOperation.new(kind, [wire - 1], theta: theta), state}
    else
      {GateOperation.new(kind, [wire - 1]), state}
    end
  end

  defp cnot(qubits, state) do
    {control, state} = :rand.uniform_s(qubits, state)
    {offset, state} = :rand.uniform_s(qubits - 1, state)
    target = rem(control - 1 + offset, qubits)
    {GateOperation.new(:cnot, [control - 1, target]), state}
  end

  defp angle(state) do
    {roll, state} = :rand.uniform_s(state)

    if roll < 0.1 do
      {0.0, state}
    else
      {u, state} = :rand.uniform_s(state)
      {(2.0 * u - 1.0) * :math.pi(), state}
    end
  end
end
