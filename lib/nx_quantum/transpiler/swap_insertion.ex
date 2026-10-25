defmodule NxQuantum.Transpiler.SwapInsertion do
  @moduledoc false

  alias NxQuantum.GateOperation

  @spec swap_operation(non_neg_integer(), non_neg_integer()) :: GateOperation.t()
  def swap_operation(a, b), do: GateOperation.new(:swap, [a, b])
end
