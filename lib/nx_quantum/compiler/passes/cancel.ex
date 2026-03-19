defmodule NxQuantum.Compiler.Passes.Cancel do
  @moduledoc false

  alias NxQuantum.GateOperation

  @spec run([GateOperation.t()]) :: [GateOperation.t()]
  def run(operations), do: cancel(operations, [])

  defp cancel([], acc), do: Enum.reverse(acc)

  defp cancel([first, second | rest], acc) do
    if cancellable?(first, second) do
      cancel(rest, acc)
    else
      cancel([second | rest], [first | acc])
    end
  end

  defp cancel([single], acc), do: Enum.reverse([single | acc])

  defp cancellable?(%GateOperation{name: name, wires: wires}, %GateOperation{name: name, wires: wires})
       when name in [:x, :y, :z, :h, :cnot], do: true

  defp cancellable?(_, _), do: false
end
