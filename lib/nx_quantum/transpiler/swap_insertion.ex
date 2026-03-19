defmodule NxQuantum.Transpiler.SwapInsertion do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation

  @spec prepend_swaps(Circuit.t(), [NxQuantum.Transpiler.coupling_edge()]) :: Circuit.t()
  def prepend_swaps(%Circuit{} = circuit, swaps) do
    swap_operations = Enum.map(swaps, fn {a, b} -> GateOperation.new(:swap, [a, b]) end)
    %{circuit | operations: swap_operations ++ circuit.operations}
  end
end
