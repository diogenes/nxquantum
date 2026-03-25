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
    cache_mode = cache_mode(opts)
    cache_opts = cache_opts(cache_mode)
    guard_mode = guard_mode(cache_mode)

    if iterations <= 0 or warmup < 0 do
      {:error, %{code: :invalid_batch_obs_guard_config, iterations: iterations, warmup: warmup}}
    else
      circuit = batch_obs_circuit()
      observables = batch_observables()

      run_once = fn ->
        estimator_opts =
          [
            observables: observables,
            parallel_observables: true,
            max_concurrency: System.schedulers_online()
          ] ++ cache_opts

        case Estimator.run(circuit, estimator_opts) do
          {:ok, result} -> Nx.to_number(Nx.sum(result.values))
          {:error, reason} -> raise "batch_obs guard estimator failed: #{inspect(reason)}"
        end
      end

      if warmup > 0 do
        Enum.each(1..warmup, fn _ ->
          _ = run_once.()
        end)
      end

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

      report = %{
        scenario: :batch_obs_8q,
        cache_mode: cache_mode,
        guard_mode: guard_mode,
        status: status,
        iterations: iterations,
        warmup: warmup,
        total_ms: total_ms,
        per_op_ms: per_op_ms,
        max_per_op_ms: max_per_op_ms,
        value: value
      }

      with :ok <- maybe_write_artifact(report, opts) do
        {:ok, report}
      end
    end
  end

  @spec write_csv_artifact(map(), Path.t()) :: :ok | {:error, map()}
  def write_csv_artifact(report, path) when is_map(report) and is_binary(path) do
    with :ok <- validate_artifact_report(report),
         :ok <- ensure_parent_dir(path) do
      content = to_csv(report)
      File.write(path, content)
    else
      {:error, _} = error -> error
    end
  rescue
    error ->
      {:error, %{code: :artifact_write_failed, reason: error, path: path}}
  end

  defp maybe_write_artifact(report, opts) do
    case Keyword.get(opts, :artifact_path) do
      nil -> :ok
      path when is_binary(path) -> write_csv_artifact(report, path)
      _ -> {:error, %{code: :invalid_artifact_path}}
    end
  end

  defp validate_artifact_report(report) do
    required_keys = [
      :scenario,
      :cache_mode,
      :guard_mode,
      :status,
      :per_op_ms,
      :max_per_op_ms,
      :iterations,
      :warmup,
      :total_ms
    ]

    missing =
      Enum.reject(required_keys, fn key ->
        Map.has_key?(report, key)
      end)

    if missing == [] do
      :ok
    else
      {:error, %{code: :invalid_artifact_report, missing: missing}}
    end
  end

  defp ensure_parent_dir(path) do
    path
    |> Path.dirname()
    |> File.mkdir_p()
  end

  defp to_csv(report) do
    header = "scenario,cache_mode,guard_mode,status,per_op_ms,max_per_op_ms,iterations,warmup,total_ms,value\n"

    row =
      Enum.map_join(
        [
          report.scenario,
          report.cache_mode,
          report.guard_mode,
          report.status,
          report.per_op_ms,
          report.max_per_op_ms,
          report.iterations,
          report.warmup,
          report.total_ms,
          report.value
        ],
        ",",
        &csv_value/1
      )

    header <> row <> "\n"
  end

  defp csv_value(value) when is_atom(value), do: Atom.to_string(value)
  defp csv_value(value) when is_float(value), do: :erlang.float_to_binary(value, decimals: 10)
  defp csv_value(value) when is_integer(value), do: Integer.to_string(value)
  defp csv_value(value), do: to_string(value)

  defp cache_mode(opts) do
    case Keyword.get(opts, :cache_mode, :hot) do
      :cold -> :cold
      _ -> :hot
    end
  end

  defp cache_opts(:cold), do: [cache_evolved_state: false]
  defp cache_opts(:hot), do: [cache_evolved_state: true]

  defp guard_mode(:hot), do: :blocking
  defp guard_mode(:cold), do: :report_only

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
