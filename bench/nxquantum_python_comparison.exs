alias NxQuantum.Adapters.Simulators.StateVector.EvolutionStrategy
alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval
alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates
alias NxQuantum.Observables.SparsePauli
alias NxQuantum.Runtime

parse_iterations = fn value ->
  case Integer.parse(value) do
    {parsed, ""} when parsed > 0 -> parsed
    _ -> 1000
  end
end

parse_runtime_profile = fn value ->
  case String.trim(value) do
    "cpu_portable" -> :cpu_portable
    "cpu_compiled" -> :cpu_compiled
    "nvidia_gpu_compiled" -> :nvidia_gpu_compiled
    "torch_interop_runtime" -> :torch_interop_runtime
    _ -> :cpu_portable
  end
end

parse_scenario = fn value ->
  case String.trim(value) do
    "baseline_2q" -> :baseline_2q
    "deep_6q" -> :deep_6q
    "batch_obs_8q" -> :batch_obs_8q
    "state_reuse_8q_xy" -> :state_reuse_8q_xy
    "sampled_counts_sparse_terms" -> :sampled_counts_sparse_terms
    _ -> :baseline_2q
  end
end

{iterations, runtime_profile} =
  case System.argv() do
    [iterations_arg, profile_arg, _scenario_arg | _rest] ->
      {parse_iterations.(iterations_arg), parse_runtime_profile.(profile_arg)}

    [iterations_arg] ->
      {parse_iterations.(iterations_arg), :cpu_portable}

    _ ->
      {1000, :cpu_portable}
  end

scenario =
  case System.argv() do
    [_iterations_arg, _profile_arg, scenario_arg | _rest] -> parse_scenario.(scenario_arg)
    _ -> :baseline_2q
  end

resolved_profile =
  case Runtime.resolve(runtime_profile, fallback_policy: :allow_cpu_compiled) do
    {:ok, profile} -> profile.id
    {:error, _reason} -> :cpu_portable
  end

warmup = min(100, iterations)

circuit =
  case scenario do
    :baseline_2q ->
      [qubits: 2]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.ry(1, theta: Nx.tensor(0.3))

    :deep_6q ->
      [qubits: 6]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.cnot(control: 1, target: 2)
      |> Gates.cnot(control: 2, target: 3)
      |> Gates.cnot(control: 3, target: 4)
      |> Gates.cnot(control: 4, target: 5)
      |> Gates.ry(0, theta: Nx.tensor(0.11))
      |> Gates.ry(1, theta: Nx.tensor(0.22))
      |> Gates.ry(2, theta: Nx.tensor(0.33))
      |> Gates.ry(3, theta: Nx.tensor(0.44))
      |> Gates.ry(4, theta: Nx.tensor(0.55))
      |> Gates.ry(5, theta: Nx.tensor(0.66))
      |> Gates.cnot(control: 0, target: 3)
      |> Gates.cnot(control: 2, target: 5)
      |> Gates.cnot(control: 1, target: 4)

    :batch_obs_8q ->
      [qubits: 8]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.cnot(control: 1, target: 2)
      |> Gates.cnot(control: 2, target: 3)
      |> Gates.cnot(control: 3, target: 4)
      |> Gates.cnot(control: 4, target: 5)
      |> Gates.cnot(control: 5, target: 6)
      |> Gates.cnot(control: 6, target: 7)
      |> Gates.ry(0, theta: Nx.tensor(0.11))
      |> Gates.ry(1, theta: Nx.tensor(0.22))
      |> Gates.ry(2, theta: Nx.tensor(0.33))
      |> Gates.ry(3, theta: Nx.tensor(0.44))
      |> Gates.ry(4, theta: Nx.tensor(0.55))
      |> Gates.ry(5, theta: Nx.tensor(0.66))
      |> Gates.ry(6, theta: Nx.tensor(0.77))
      |> Gates.ry(7, theta: Nx.tensor(0.88))
      |> Gates.rx(2, theta: Nx.tensor(0.19))
      |> Gates.rz(3, theta: Nx.tensor(0.29))
      |> Gates.cnot(control: 0, target: 4)
      |> Gates.cnot(control: 2, target: 6)
      |> Gates.cnot(control: 1, target: 5)

    :state_reuse_8q_xy ->
      [qubits: 8]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.cnot(control: 1, target: 2)
      |> Gates.cnot(control: 2, target: 3)
      |> Gates.cnot(control: 3, target: 4)
      |> Gates.cnot(control: 4, target: 5)
      |> Gates.cnot(control: 5, target: 6)
      |> Gates.cnot(control: 6, target: 7)
      |> Gates.ry(0, theta: Nx.tensor(0.11))
      |> Gates.ry(1, theta: Nx.tensor(0.22))
      |> Gates.ry(2, theta: Nx.tensor(0.33))
      |> Gates.ry(3, theta: Nx.tensor(0.44))
      |> Gates.ry(4, theta: Nx.tensor(0.55))
      |> Gates.ry(5, theta: Nx.tensor(0.66))
      |> Gates.ry(6, theta: Nx.tensor(0.77))
      |> Gates.ry(7, theta: Nx.tensor(0.88))
      |> Gates.rx(2, theta: Nx.tensor(0.19))
      |> Gates.rz(3, theta: Nx.tensor(0.29))
      |> Gates.cnot(control: 0, target: 4)
      |> Gates.cnot(control: 2, target: 6)
      |> Gates.cnot(control: 1, target: 5)

    :sampled_counts_sparse_terms ->
      [qubits: 2]
      |> Circuit.new()
      |> Gates.h(0)
  end

batch_observables =
  case scenario do
    :batch_obs_8q ->
      observable_cycle = [:pauli_x, :pauli_y, :pauli_z]

      Enum.map(0..47, fn index ->
        %{observable: Enum.at(observable_cycle, rem(index, 3)), wire: rem(index, 8)}
      end)

    _ ->
      []
  end

max_concurrency = System.schedulers_online()

state_reuse_payload =
  case scenario do
    :state_reuse_8q_xy ->
      state = EvolutionStrategy.evolve(circuit)
      x_term = PauliExpval.term_for_observable(:pauli_x, 5)
      y_term = PauliExpval.term_for_observable(:pauli_y, 5)

      plan =
        PauliExpval.plan([x_term, y_term], 8, parallel_observables: false)

      %{state: state, plan: plan}

    _ ->
      nil
  end

sampled_counts_payload =
  case scenario do
    :sampled_counts_sparse_terms ->
      counts = %{
        "00000000" => 900,
        "00000011" => 420,
        "00011100" => 330,
        "00110011" => 270,
        "01010101" => 510,
        "01100110" => 340,
        "10011001" => 290,
        "10101010" => 470,
        "11000011" => 280,
        "11111111" => 286
      }

      terms =
        Enum.map(0..47, fn index ->
          z_mask = rem(index * 37, 255) + 1
          magnitude = 0.02 * (rem(index, 5) + 1)
          coeff = if rem(index, 2) == 0, do: magnitude, else: -magnitude
          %{x_mask: 0, z_mask: z_mask, coeff: coeff}
        end)

      {:ok, sparse_pauli} = SparsePauli.new(8, terms)

      %{counts: counts, sparse_pauli: sparse_pauli}

    _ ->
      nil
  end

run_once = fn ->
  case scenario do
    :batch_obs_8q ->
      case Estimator.run(circuit,
             observables: batch_observables,
             runtime_profile: runtime_profile,
             fallback_policy: :allow_cpu_compiled,
             parallel_observables: true,
             max_concurrency: max_concurrency
           ) do
        {:ok, result} -> Nx.sum(result.values)
        {:error, reason} -> raise "NxQuantum benchmark failed: #{inspect(reason)}"
      end

    :state_reuse_8q_xy ->
      %{state: state, plan: plan} = state_reuse_payload
      [x, y] = PauliExpval.expectations_with_reuse_cache(state, plan)
      Nx.add(x, y)

    :sampled_counts_sparse_terms ->
      %{counts: counts, sparse_pauli: sparse_pauli} = sampled_counts_payload

      case Estimator.sampled_expectation_from_counts(counts,
             sparse_pauli: sparse_pauli,
             sampled_parallel_mode: :auto,
             max_concurrency: max_concurrency
           ) do
        {:ok, value} -> value
        {:error, reason} -> raise "NxQuantum sampled benchmark failed: #{inspect(reason)}"
      end

    _ ->
      case Estimator.expectation_result(circuit,
             observable: :pauli_z,
             wire: if(scenario == :deep_6q, do: 5, else: 1),
             runtime_profile: runtime_profile,
             fallback_policy: :allow_cpu_compiled
           ) do
        {:ok, value} -> value
        {:error, reason} -> raise "NxQuantum benchmark failed: #{inspect(reason)}"
      end
  end
end

for _ <- 1..warmup do
  _ = run_once.()
end

{microseconds, last_value} =
  :timer.tc(fn ->
    Enum.reduce(1..iterations, nil, fn _, _acc ->
      run_once.()
    end)
  end)

total_ms = microseconds / 1000.0
per_op_ms = total_ms / iterations
ops_s = iterations / (microseconds / 1_000_000.0)
numeric_value = Nx.to_number(last_value)

IO.puts(
  "NXQ_BENCH scenario=#{scenario} runtime_profile=#{runtime_profile} resolved_profile=#{resolved_profile} total_ms=#{Float.round(total_ms, 6)} per_op_ms=#{Float.round(per_op_ms, 6)} ops_s=#{Float.round(ops_s, 6)} value=#{Float.round(numeric_value, 10)}"
)
