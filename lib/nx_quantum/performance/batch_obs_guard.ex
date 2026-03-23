defmodule NxQuantum.Performance.BatchObsGuard do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Gates

  @spec run(keyword()) :: {:ok, map()} | {:error, map()}
  def run(opts \\ []) do
    iterations = Keyword.get(opts, :iterations, 100)
    warmup = Keyword.get(opts, :warmup, 20)
    max_per_op_ms = Keyword.get(opts, :max_per_op_ms, 2.028_193_5)

    if iterations <= 0 or warmup < 0 do
      {:error, %{code: :invalid_batch_obs_guard_config, iterations: iterations, warmup: warmup}}
    else
      circuit = batch_obs_circuit()
      observables = batch_observables()

      run_once = fn ->
        case Estimator.run(circuit,
               observables: observables,
               parallel_observables: true,
               max_concurrency: System.schedulers_online()
             ) do
          {:ok, result} -> Nx.to_number(Nx.sum(result.values))
          {:error, reason} -> raise "batch_obs guard estimator failed: #{inspect(reason)}"
        end
      end

      for _ <- 1..warmup, do: run_once.()

      {microseconds, value} =
        :timer.tc(fn ->
          Enum.reduce(1..iterations, nil, fn _, _ ->
            run_once.()
          end)
        end)

      total_ms = microseconds / 1000.0
      per_op_ms = total_ms / iterations

      status =
        if per_op_ms <= max_per_op_ms do
          :ok
        else
          :failed
        end

      {:ok,
       %{
         status: status,
         iterations: iterations,
         warmup: warmup,
         total_ms: total_ms,
         per_op_ms: per_op_ms,
         max_per_op_ms: max_per_op_ms,
         value: value
       }}
    end
  end

  defp batch_observables do
    observable_cycle = [:pauli_x, :pauli_y, :pauli_z]

    Enum.map(0..47, fn index ->
      %{observable: Enum.at(observable_cycle, rem(index, 3)), wire: rem(index, 8)}
    end)
  end

  defp batch_obs_circuit do
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
  end
end
