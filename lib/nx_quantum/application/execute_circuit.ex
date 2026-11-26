defmodule NxQuantum.Application.ExecuteCircuit do
  @moduledoc """
  Application service that executes circuit use-cases through ports.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Ports.Simulator
  alias NxQuantum.Runtime.SimulatorResolver

  @spec expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  def expectation(%Circuit{} = circuit, opts \\ []) do
    {value, _facts} = expectation_with_simulation(circuit, opts)
    value
  end

  @doc "Like `expectation/2`, and also returns the simulator's facts about how the value was produced."
  @spec expectation_with_simulation(Circuit.t(), keyword()) :: {Nx.Tensor.t(), Simulator.simulation_facts()}
  def expectation_with_simulation(%Circuit{} = circuit, opts \\ []) do
    {simulator, simulator_opts} = resolve(opts)

    if loaded_with?(simulator, :expectation_with_simulation, 2) do
      simulator.expectation_with_simulation(circuit, simulator_opts)
    else
      {simulator.expectation(circuit, simulator_opts), Simulator.unreported_facts()}
    end
  end

  @spec expectations(Circuit.t(), [map()], keyword()) :: Nx.Tensor.t()
  def expectations(%Circuit{} = circuit, observable_specs, opts \\ []) when is_list(observable_specs) do
    {values, _facts} = expectations_with_simulation(circuit, observable_specs, opts)
    values
  end

  @doc "Like `expectations/3`, and also returns the simulator's facts about how the values were produced."
  @spec expectations_with_simulation(Circuit.t(), [map()], keyword()) ::
          {Nx.Tensor.t(), Simulator.simulation_facts()}
  def expectations_with_simulation(%Circuit{} = circuit, observable_specs, opts \\ []) when is_list(observable_specs) do
    {simulator, simulator_opts} = resolve(opts)

    cond do
      loaded_with?(simulator, :expectations_with_simulation, 3) ->
        simulator.expectations_with_simulation(circuit, observable_specs, simulator_opts)

      loaded_with?(simulator, :expectations, 3) ->
        {simulator.expectations(circuit, observable_specs, simulator_opts), Simulator.unreported_facts()}

      true ->
        values =
          observable_specs
          |> Enum.map(fn %{observable: observable, wire: wire} ->
            measured = %{circuit | measurement: %{observable: observable, wire: wire}}
            simulator.expectation(measured, simulator_opts)
          end)
          |> case do
            [] -> Nx.tensor([], type: {:f, 32})
            values -> Nx.stack(values)
          end

        {values, Simulator.unreported_facts()}
    end
  end

  # function_exported?/3 is false until the module is loaded, so load it first.
  defp loaded_with?(simulator, fun, arity) do
    Code.ensure_loaded?(simulator) and function_exported?(simulator, fun, arity)
  end

  defp resolve(opts) do
    simulator = Keyword.get_lazy(opts, :simulator, &SimulatorResolver.default/0)
    backend_opts = Keyword.get(opts, :backend_opts, [])
    simulator_opts = opts |> Keyword.drop([:simulator, :backend_opts]) |> Keyword.merge(backend_opts)
    {simulator, simulator_opts}
  end
end
