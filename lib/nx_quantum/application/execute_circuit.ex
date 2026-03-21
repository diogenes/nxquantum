defmodule NxQuantum.Application.ExecuteCircuit do
  @moduledoc """
  Application service that executes circuit use-cases through ports.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Runtime.SimulatorResolver

  @spec expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  def expectation(%Circuit{} = circuit, opts \\ []) do
    simulator = Keyword.get_lazy(opts, :simulator, &SimulatorResolver.default/0)
    backend_opts = Keyword.get(opts, :backend_opts, [])

    simulator.expectation(circuit, backend_opts)
  end
end
