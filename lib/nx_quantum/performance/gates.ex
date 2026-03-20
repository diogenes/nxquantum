defmodule NxQuantum.Performance.Gates do
  @moduledoc false

  alias NxQuantum.Performance.GateResult

  @spec evaluate(map(), map()) :: {:ok, GateResult.t()} | {:error, map()}
  def evaluate(%{version: version, max_regression_pct: max_regression_pct} = baseline, current_report)
      when is_binary(version) and is_number(max_regression_pct) do
    baseline_by_batch = Map.get(baseline, :throughput_by_batch, %{})
    current_by_batch = throughput_by_batch(current_report)

    with :ok <- validate_baseline_values(baseline_by_batch) do
      baseline_by_batch
      |> build_regressions(current_by_batch, max_regression_pct)
      |> build_gate_result(version)
    end
  end

  def evaluate(_baseline, _current_report) do
    {:error, %{code: :invalid_performance_gate_input}}
  end

  defp build_regressions(baseline_by_batch, current_by_batch, max_regression_pct) do
    Enum.reduce_while(baseline_by_batch, [], fn {batch_size, baseline_value}, acc ->
      process_batch(batch_size, baseline_value, current_by_batch, max_regression_pct, acc)
    end)
  end

  defp process_batch(batch_size, _baseline_value, current_by_batch, _max_regression_pct, _acc)
       when not is_map_key(current_by_batch, batch_size) do
    {:halt, {:error, %{code: :missing_benchmark_metric, batch_size: batch_size}}}
  end

  defp process_batch(batch_size, baseline_value, current_by_batch, max_regression_pct, acc) do
    current_value = Map.fetch!(current_by_batch, batch_size)

    if regression?(baseline_value, current_value, max_regression_pct) do
      {:cont, [regression_record(batch_size, baseline_value, current_value) | acc]}
    else
      {:cont, acc}
    end
  end

  defp build_gate_result({:error, _} = error, _version), do: error

  defp build_gate_result(regression_list, version) do
    ordered = Enum.reverse(regression_list)
    status = if ordered == [], do: :passed, else: :failed
    {:ok, %GateResult{status: status, version: version, regressions: ordered}}
  end

  defp regression?(baseline_value, current_value, max_regression_pct) do
    floor_value = baseline_value * (1.0 - max_regression_pct / 100.0)
    current_value < floor_value
  end

  defp regression_record(batch_size, baseline_value, current_value) do
    delta_pct = Float.round((current_value - baseline_value) / baseline_value * 100.0, 3)

    %{
      metric: :throughput_ops_s,
      batch_size: batch_size,
      baseline: baseline_value,
      current: current_value,
      delta_pct: delta_pct
    }
  end

  defp validate_baseline_values(baseline_by_batch) do
    case Enum.find(baseline_by_batch, fn {_batch_size, value} ->
           not is_number(value) or value <= 0
         end) do
      nil ->
        :ok

      {batch_size, value} ->
        {:error, %{code: :invalid_baseline_threshold, batch_size: batch_size, value: value}}
    end
  end

  defp throughput_by_batch(%{entries: entries}) when is_list(entries) do
    Map.new(entries, fn entry -> {entry.batch_size, entry.throughput_ops_s} end)
  end

  defp throughput_by_batch(_invalid), do: %{}
end
