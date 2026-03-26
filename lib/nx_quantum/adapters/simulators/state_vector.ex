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
        EvolvedStateCache.fetch_with_status(
          cache_key,
          fn -> circuit |> EvolutionStrategy.evolve() |> maybe_apply_runtime_backend(opts) end,
          opts
        )

      Process.put(:nxq_estimator_cache_status, cache_status)
      state
    else
      Process.put(:nxq_estimator_cache_status, :bypass)

      circuit
      |> EvolutionStrategy.evolve()
      |> maybe_apply_runtime_backend(opts)
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
