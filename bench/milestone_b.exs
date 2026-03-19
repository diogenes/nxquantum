alias NxQuantum.Circuit
alias NxQuantum.Compiler
alias NxQuantum.Estimator
alias NxQuantum.Gates

base_1q =
  Circuit.new(qubits: 1)
  |> Gates.ry(0, theta: 0.9)
  |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})

base_2q =
  Circuit.new(qubits: 2)
  |> Gates.h(0)
  |> Gates.cnot(control: 0, target: 1)
  |> Gates.ry(1, theta: 0.4)
  |> Map.put(:measurement, %{observable: :pauli_z, wire: 1})

redundant =
  Circuit.new(qubits: 1)
  |> Gates.h(0)
  |> Gates.h(0)
  |> Gates.rx(0, theta: 0.2)
  |> Gates.rx(0, theta: 0.3)
  |> Gates.rz(0, theta: 0.0)

Benchee.run(
  %{
    "expectation_1q" => fn ->
      {:ok, _value} = Estimator.expectation_result(base_1q)
    end,
    "expectation_2q" => fn ->
      {:ok, _value} = Estimator.expectation_result(base_2q)
    end,
    "shots_seeded_2048" => fn ->
      {:ok, _value} = Estimator.expectation_result(base_1q, shots: 2_048, seed: 2_026)
    end,
    "noise_depolarizing" => fn ->
      {:ok, _value} = Estimator.expectation_result(base_1q, noise: [depolarizing: 0.1])
    end,
    "noise_amplitude_damping" => fn ->
      {:ok, _value} = Estimator.expectation_result(base_1q, noise: [amplitude_damping: 0.2])
    end,
    "optimize_pipeline" => fn ->
      {_optimized, _report} = Compiler.optimize(redundant, passes: [:simplify, :fuse, :cancel])
    end
  },
  warmup: 1,
  time: 2,
  memory_time: 0,
  formatters: [Benchee.Formatters.Console]
)
