defmodule NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy do
  @moduledoc false

  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy.Complex
  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy.RealPauliZ
  alias NxQuantum.Circuit

  @type t :: module()

  @callback applicable?(Circuit.t()) :: boolean()
  @callback evolve(Circuit.t()) :: Nx.Tensor.t()

  @strategies [RealPauliZ, Complex]
  @path_names %{RealPauliZ => :real_pauli_z, Complex => :complex}

  @type evolution_path :: :real_pauli_z | :complex

  @spec select(Circuit.t()) :: t()
  def select(%Circuit{} = circuit) do
    Enum.find(@strategies, Complex, & &1.applicable?(circuit))
  end

  @spec evolve(Circuit.t()) :: Nx.Tensor.t()
  def evolve(%Circuit{} = circuit) do
    {_path, state} = evolve_with_path(circuit)
    state
  end

  @spec evolve_with_path(Circuit.t()) :: {evolution_path(), Nx.Tensor.t()}
  def evolve_with_path(%Circuit{} = circuit) do
    strategy = select(circuit)
    {Map.fetch!(@path_names, strategy), strategy.evolve(circuit)}
  end

  # Pure: the path that evolve_with_path/1 takes for this circuit, without evolving it.
  @spec path_for(Circuit.t()) :: evolution_path()
  def path_for(%Circuit{} = circuit), do: circuit |> select() |> then(&Map.fetch!(@path_names, &1))
end
