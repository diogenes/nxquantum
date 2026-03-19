defmodule NxQuantum.Features.Steps do
  @moduledoc false

  alias NxQuantum.Features.StepRegistry

  @spec execute(map(), map()) :: {:ok, map()} | {:error, String.t()}
  def execute(step, ctx) do
    feature = Map.fetch!(ctx, :feature)

    try do
      module = StepRegistry.module_for_feature(feature)
      {:ok, module.execute(step, ctx)}
    rescue
      error ->
        {:error, Exception.format(:error, error, __STACKTRACE__)}
    end
  end
end
