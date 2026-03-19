defmodule NxQuantum.Compiler.Passes.Fuse do
  @moduledoc false

  alias NxQuantum.Compiler.Theta
  alias NxQuantum.GateOperation

  @spec run([GateOperation.t()]) :: [GateOperation.t()]
  def run(operations), do: fuse(operations, [])

  defp fuse([], acc), do: Enum.reverse(acc)

  defp fuse([first, second | rest], acc) do
    if fuseable?(first, second) do
      fused = Theta.put(first, Theta.add(Theta.value(first), Theta.value(second)))
      fuse([fused | rest], acc)
    else
      fuse([second | rest], [first | acc])
    end
  end

  defp fuse([single], acc), do: Enum.reverse([single | acc])

  defp fuseable?(%GateOperation{name: name, wires: wires_a}, %GateOperation{name: name, wires: wires_b})
       when name in [:rx, :ry, :rz] do
    wires_a == wires_b
  end

  defp fuseable?(_, _), do: false
end
