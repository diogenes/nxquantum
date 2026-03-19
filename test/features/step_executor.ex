defmodule NxQuantum.Features.StepExecutor do
  @moduledoc false

  @type handler_result :: {:handled, map()} | :unhandled
  @type handler :: (map(), map() -> handler_result())

  @spec run(map(), map(), [handler()]) :: handler_result()
  def run(step, ctx, handlers) do
    Enum.reduce_while(handlers, :unhandled, fn handler, _acc ->
      case handler.(step, ctx) do
        {:handled, updated} -> {:halt, {:handled, updated}}
        :unhandled -> {:cont, :unhandled}
      end
    end)
  end
end
