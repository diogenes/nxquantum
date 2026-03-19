defmodule NxQuantum.Ports.Backend do
  @moduledoc """
  Port for backend compilation/execution strategy.
  """

  @type compiled_fn :: (term() -> term())

  @callback compile(compiled_fn(), term(), keyword()) :: term()
  @callback default_options() :: keyword()
end
