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

  @generic_expectation_path %{
    expectation_path: :generic,
    fused_kernel: %{requested_kernel: :unknown, selected_kernel: :unknown, reason: :not_applicable}
  }

  @impl true
  @spec expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  def expectation(%Circuit{} = circuit, opts) do
    {value, _facts} = expectation_with_simulation(circuit, opts)
    value
  end

  @impl true
  @spec expectation_with_simulation(Circuit.t(), keyword()) :: {Nx.Tensor.t(), map()}
  def expectation_with_simulation(%Circuit{measurement: nil}, _opts) do
    raise ArgumentError, "measurement not set; call Circuit.expectation/2 with observable and wire"
  end

  def expectation_with_simulation(%Circuit{} = circuit, opts) do
    %{observable: observable, wire: wire} = circuit.measurement
    {state, run} = evolve_with_cache(circuit, opts)
    value = expectation_for_observable(state, observable, wire, circuit.qubits)
    {Nx.as_type(value, {:f, 32}), simulation_facts(run, @generic_expectation_path)}
  end

  @impl true
  @spec expectations(Circuit.t(), [map()], keyword()) :: Nx.Tensor.t()
  def expectations(%Circuit{} = circuit, observable_specs, opts) when is_list(observable_specs) do
    {values, _facts} = expectations_with_simulation(circuit, observable_specs, opts)
    values
  end

  @impl true
  @spec expectations_with_simulation(Circuit.t(), [map()], keyword()) :: {Nx.Tensor.t(), map()}
  def expectations_with_simulation(%Circuit{} = circuit, observable_specs, opts) when is_list(observable_specs) do
    if observable_specs == [] do
      {Nx.tensor([], type: {:f, 32}), NxQuantum.Ports.Simulator.unreported_facts()}
    else
      {state, run} = evolve_with_cache(circuit, opts)
      maybe_bitmask_terms = Enum.map(observable_specs, &PauliExpval.term_for_observable(&1.observable, &1.wire))

      {values, path} =
        if Enum.all?(maybe_bitmask_terms, &is_map/1) do
          maybe_bitmask_terms
          |> PauliExpval.plan(circuit.qubits, opts)
          |> then(&PauliExpval.expectations_with_plan_and_path(state, &1, opts))
        else
          values =
            Enum.map(observable_specs, fn %{observable: observable, wire: wire} ->
              expectation_for_observable(state, observable, wire, circuit.qubits)
            end)

          {values, @generic_expectation_path}
        end

      {values |> Nx.stack() |> Nx.as_type({:f, 32}), simulation_facts(run, path)}
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

  # Returns the state and what happened to it in this call. A cache hit reuses a state that an
  # earlier call evolved, so no evolution path is reported for it.
  defp evolve_with_cache(%Circuit{} = circuit, opts) do
    if cache_evolved_state?(circuit, opts) do
      cache_key = evolved_state_cache_key(circuit, opts)

      {state, cache_status} =
        EvolvedStateCache.fetch_with_status(cache_key, fn -> evolve_state(circuit, opts) end, opts)

      path = if cache_status == :miss, do: EvolutionStrategy.path_for(circuit)
      {state, %{cache_status: cache_status, evolution_path: path, state_backend: state_backend(state)}}
    else
      state = evolve_state(circuit, opts)

      run = %{
        cache_status: :bypass,
        evolution_path: EvolutionStrategy.path_for(circuit),
        state_backend: state_backend(state)
      }

      {state, run}
    end
  end

  defp evolve_state(%Circuit{} = circuit, opts) do
    {_path, evolved} = EvolutionStrategy.evolve_with_path(circuit)
    maybe_apply_runtime_backend(evolved, opts)
  end

  defp simulation_facts(run, path) do
    %{
      method: :state_vector,
      evolution_path: run.evolution_path,
      state_backend: run.state_backend,
      cache_status: run.cache_status,
      expectation_path: path.expectation_path,
      fused_kernel: path.fused_kernel
    }
  end

  # Neutral label for the state's backend. The Nx backend module itself never leaves the adapter.
  defp state_backend(%Nx.Tensor{data: %{__struct__: Nx.BinaryBackend}}), do: :portable

  defp state_backend(%Nx.Tensor{data: %{__struct__: backend}}) do
    if backend == exla_backend_module(), do: :compiled, else: :other
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

  defp maybe_apply_runtime_backend(%Nx.Tensor{} = state, opts) do
    case runtime_backend(opts) do
      nil ->
        state

      Nx.BinaryBackend ->
        state

      backend ->
        Nx.backend_transfer(state, backend)
    end
  rescue
    _ -> state
  end

  defp runtime_backend(opts) do
    case Keyword.get(opts, :runtime_profile) do
      %{backend: backend, id: id} ->
        backend_with_client(id, backend)

      %{id: id} when is_atom(id) ->
        default_backend_for_profile(id)

      id when is_atom(id) ->
        default_backend_for_profile(id)

      _ ->
        Nx.BinaryBackend
    end
  end

  defp default_backend_for_profile(:cpu_compiled), do: backend_with_client(:cpu_compiled, exla_backend_module())

  defp default_backend_for_profile(:nvidia_gpu_compiled),
    do: backend_with_client(:nvidia_gpu_compiled, exla_backend_module())

  defp default_backend_for_profile(_profile_id), do: Nx.BinaryBackend

  defp backend_with_client(profile_id, backend) when is_atom(backend) do
    if backend == exla_backend_module() do
      client = if profile_id == :nvidia_gpu_compiled, do: :cuda, else: :host
      {backend, client: client}
    else
      backend
    end
  end

  defp exla_backend_module, do: :"Elixir.EXLA.Backend"
end
