defmodule NxQuantum.Adapters.Simulators.StateVector do
  @moduledoc """
  State-vector simulator adapter.

  Gate application and expectation primitives delegate to `Nx.Defn` kernels in
  NxQuantum.Adapters.Simulators.StateVector.State.
  """

  @behaviour NxQuantum.Ports.Simulator

  alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy
  alias NxQuantum.Adapters.Simulators.StateVector.EvolvedStateCache
  alias NxQuantum.Adapters.Simulators.StateVector.KeyEncoder
  alias NxQuantum.Adapters.Simulators.StateVector.Matrices
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval
  alias NxQuantum.Adapters.Simulators.StateVector.State
  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation

  @type state_vector :: Nx.Tensor.t()

  @impl true
  @spec expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  def expectation(%Circuit{measurement: nil}, _opts) do
    raise ArgumentError, "measurement not set; call Circuit.expectation/2 with observable and wire"
  end

  def expectation(%Circuit{} = circuit, opts) do
    %{observable: observable, wire: wire} = circuit.measurement
    state = evolve_with_cache(circuit, opts)
    value = expectation_for_observable(state, observable, wire, circuit.qubits)
    Nx.as_type(value, {:f, 32})
  end

  @impl true
  @spec expectations(Circuit.t(), [map()], keyword()) :: Nx.Tensor.t()
  def expectations(%Circuit{} = circuit, observable_specs, opts) when is_list(observable_specs) do
    if observable_specs == [] do
      Nx.tensor([], type: {:f, 32})
    else
      state = evolve_with_cache(circuit, opts)
      maybe_bitmask_terms = Enum.map(observable_specs, &PauliExpval.term_for_observable(&1.observable, &1.wire))

      values =
        if Enum.all?(maybe_bitmask_terms, &is_map/1) do
          maybe_bitmask_terms
          |> PauliExpval.plan(circuit.qubits, opts)
          |> then(&PauliExpval.expectations_with_plan(state, &1, opts))
        else
          Enum.map(observable_specs, fn %{observable: observable, wire: wire} ->
            expectation_for_observable(state, observable, wire, circuit.qubits)
          end)
        end

      values |> Nx.stack() |> Nx.as_type({:f, 32})
    end
  end

  @impl true
  @spec apply_gates(state_vector(), [GateOperation.t()], keyword()) :: state_vector()
  def apply_gates(%Nx.Tensor{} = state, operations, _opts) when is_list(operations) do
    State.apply_operations(state, operations)
  end

  defp expectation_for_observable(state, :pauli_x, wire, qubits),
    do: PauliExpval.expectation(state, PauliExpval.term_for_observable(:pauli_x, wire), qubits)

  defp expectation_for_observable(state, :pauli_y, wire, qubits),
    do: PauliExpval.expectation(state, PauliExpval.term_for_observable(:pauli_y, wire), qubits)

  defp expectation_for_observable(state, :pauli_z, wire, qubits), do: State.expectation_pauli_z(state, wire, qubits)

  defp expectation_for_observable(state, observable, wire, qubits) do
    observable_matrix = Matrices.observable_matrix(observable, wire, qubits)
    State.expectation_from_state(state, observable_matrix)
  end

  defp evolve_with_cache(%Circuit{} = circuit, opts) do
    if cache_evolved_state?(circuit, opts) do
      cache_key = evolved_state_cache_key(circuit, opts)

      {state, cache_status} =
        EvolvedStateCache.fetch_with_status(cache_key, fn -> EvolutionStrategy.evolve(circuit) end, opts)

      Process.put(:nxq_estimator_cache_status, cache_status)
      state
    else
      Process.put(:nxq_estimator_cache_status, :bypass)
      EvolutionStrategy.evolve(circuit)
    end
  end

  defp cache_evolved_state?(%Circuit{qubits: qubits}, opts) do
    Keyword.get(opts, :cache_evolved_state, true) and qubits <= 10
  end

  defp evolved_state_cache_key(%Circuit{} = circuit, opts) do
    profile_id =
      case Keyword.get(opts, :runtime_profile) do
        %{id: id} when is_atom(id) -> id
        id when is_atom(id) -> id
        _ -> :cpu_portable
      end

    {:evolved_state, profile_id, circuit.qubits, KeyEncoder.execution_plan_key(circuit.operations)}
  end
end
