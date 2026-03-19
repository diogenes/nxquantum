defmodule NxQuantum.Compiler.Passes.Simplify do
  @moduledoc false

  alias NxQuantum.Compiler.Theta
  alias NxQuantum.GateOperation

  @spec run([GateOperation.t()]) :: [GateOperation.t()]
  def run(operations) do
    Enum.reject(operations, fn
      %GateOperation{name: name} = op when name in [:rx, :ry, :rz] ->
        op |> Theta.value() |> Theta.to_number() |> abs() < 1.0e-12

      _ ->
        false
    end)
  end
end
