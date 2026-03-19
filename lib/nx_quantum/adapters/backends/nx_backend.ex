defmodule NxQuantum.Adapters.Backends.NxBackend do
  @moduledoc """
  Baseline backend adapter.

  This scaffold keeps execution API stable while we iterate on backend policy
  (JIT/AOT choices, compiler selection, and backend-specific tuning).
  """

  @behaviour NxQuantum.Ports.Backend

  @impl true
  def compile(fun, args, _opts) when is_function(fun, 1), do: fun.(args)

  @impl true
  def default_options, do: []
end
