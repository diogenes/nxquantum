alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates
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

{iterations, runtime_profile} =
  case System.argv() do
    [iterations_arg, profile_arg | _rest] ->
      {parse_iterations.(iterations_arg), parse_runtime_profile.(profile_arg)}

    [iterations_arg] ->
      {parse_iterations.(iterations_arg), :cpu_portable}

    _ ->
      {1000, :cpu_portable}
  end

resolved_profile =
  case Runtime.resolve(runtime_profile, fallback_policy: :allow_cpu_compiled) do
    {:ok, profile} -> profile.id
    {:error, _reason} -> :cpu_portable
  end

warmup = min(100, iterations)

circuit =
  [qubits: 2]
  |> Circuit.new()
  |> Gates.h(0)
  |> Gates.cnot(control: 0, target: 1)
  |> Gates.ry(1, theta: Nx.tensor(0.3))

run_once = fn ->
  case Estimator.expectation_result(circuit,
         observable: :pauli_z,
         wire: 1,
         runtime_profile: runtime_profile,
         fallback_policy: :allow_cpu_compiled
       ) do
    {:ok, value} -> value
    {:error, reason} -> raise "NxQuantum benchmark failed: #{inspect(reason)}"
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
  "NXQ_BENCH runtime_profile=#{runtime_profile} resolved_profile=#{resolved_profile} total_ms=#{Float.round(total_ms, 6)} per_op_ms=#{Float.round(per_op_ms, 6)} ops_s=#{Float.round(ops_s, 6)} value=#{Float.round(numeric_value, 10)}"
)
