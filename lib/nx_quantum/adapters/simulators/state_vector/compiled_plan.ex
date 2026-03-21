defmodule NxQuantum.Adapters.Simulators.StateVector.CompiledPlan do
  @moduledoc false

  alias NxQuantum.Adapters.Simulators.StateVector.Cache
  alias NxQuantum.Adapters.Simulators.StateVector.KeyEncoder
  alias NxQuantum.Adapters.Simulators.StateVector.MatrixLibrary
  alias NxQuantum.Adapters.Simulators.StateVector.Operations.Cnot
  alias NxQuantum.Adapters.Simulators.StateVector.Operations.Dense
  alias NxQuantum.Adapters.Simulators.StateVector.Operations.SingleQubit
  alias NxQuantum.GateOperation

  @spec compiled_execution_plan([GateOperation.t()], pos_integer()) :: [struct()]
  def compiled_execution_plan(operations, qubits) when is_list(operations) do
    cache_key = {:execution_plan, qubits, KeyEncoder.execution_plan_key(operations)}

    Cache.fetch(cache_key, fn ->
      build_compiled_plan(operations, qubits)
    end)
  end

  defp compile_operation(%GateOperation{name: name, wires: [wire]} = op, _qubits)
       when name in [:h, :x, :y, :z, :rx, :ry, :rz] do
    %SingleQubit{
      wire: wire,
      gate_matrix: MatrixLibrary.single_qubit_gate_matrix(op),
      gate_coefficients: MatrixLibrary.single_qubit_gate_coefficients(op)
    }
  end

  defp compile_operation(%GateOperation{name: :cnot, wires: [control, target]}, qubits) do
    %Cnot{permutation: MatrixLibrary.cnot_permutation(control, target, qubits)}
  end

  defp compile_operation(%GateOperation{} = op, qubits) do
    %Dense{matrix: MatrixLibrary.gate_matrix(op, qubits)}
  end

  defp build_compiled_plan([], _qubits), do: []

  defp build_compiled_plan(operations, qubits) do
    {cnot_ops, rest_ops} = take_cnot_prefix(operations)

    cond do
      length(cnot_ops) >= 2 ->
        [compile_cnot_chain(cnot_ops, qubits) | build_compiled_plan(rest_ops, qubits)]

      cnot_ops == [] ->
        [compile_operation(hd(operations), qubits) | build_compiled_plan(tl(operations), qubits)]

      true ->
        [compile_operation(hd(cnot_ops), qubits) | build_compiled_plan(rest_ops, qubits)]
    end
  end

  defp take_cnot_prefix(operations), do: do_take_cnot_prefix(operations, [])

  defp do_take_cnot_prefix([%GateOperation{name: :cnot} = op | rest], acc) do
    do_take_cnot_prefix(rest, [op | acc])
  end

  defp do_take_cnot_prefix(rest, acc), do: {Enum.reverse(acc), rest}

  defp compile_cnot_chain(cnot_ops, qubits) do
    cache_key = {:gate, :cnot_chain, qubits, KeyEncoder.execution_plan_key(cnot_ops)}

    permutation =
      Cache.fetch(cache_key, fn ->
        cnot_ops
        |> Enum.map(fn %GateOperation{wires: [control, target]} ->
          MatrixLibrary.cnot_permutation(control, target, qubits)
        end)
        |> compose_permutations()
      end)

    %Cnot{permutation: permutation}
  end

  defp compose_permutations([first | rest]) do
    Enum.reduce(rest, first, fn next_permutation, acc ->
      Nx.take(acc, next_permutation)
    end)
  end
end
