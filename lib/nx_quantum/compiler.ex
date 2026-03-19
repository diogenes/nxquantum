defmodule NxQuantum.Compiler do
  @moduledoc """
  Circuit optimization pipeline facade.

  Current implementation is a no-op scaffold for v0.2 planning.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Compiler.PassPipeline

  @type pass :: :simplify | :fuse | :cancel

  @spec optimize(Circuit.t(), keyword()) :: {Circuit.t(), map()}
  def optimize(%Circuit{} = circuit, opts \\ []) do
    passes = Keyword.get(opts, :passes, [:simplify, :fuse, :cancel])
    before = length(circuit.operations)

    optimized_ops =
      Enum.reduce(passes, circuit.operations, fn pass, operations ->
        PassPipeline.run(pass, operations)
      end)

    optimized = %{circuit | operations: optimized_ops}

    report = %{
      passes: passes,
      gate_count_before: before,
      gate_count_after: length(optimized_ops)
    }

    {optimized, report}
  end
end
