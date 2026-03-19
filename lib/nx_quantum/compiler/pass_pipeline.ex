defmodule NxQuantum.Compiler.PassPipeline do
  @moduledoc false

  alias NxQuantum.Compiler.Passes.Cancel
  alias NxQuantum.Compiler.Passes.Fuse
  alias NxQuantum.Compiler.Passes.Simplify

  @spec run(atom(), list()) :: list()
  def run(:simplify, operations), do: Simplify.run(operations)
  def run(:fuse, operations), do: Fuse.run(operations)
  def run(:cancel, operations), do: Cancel.run(operations)
  def run(_unknown, operations), do: operations
end
