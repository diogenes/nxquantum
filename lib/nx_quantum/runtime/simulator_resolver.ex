defmodule NxQuantum.Runtime.SimulatorResolver do
  @moduledoc false

  @spec default() :: module()
  def default do
    Application.get_env(
      :nx_quantum,
      :simulator,
      NxQuantum.Adapters.Simulators.StateVector
    )
  end
end
