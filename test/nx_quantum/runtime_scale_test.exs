defmodule NxQuantum.RuntimeScaleTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Runtime

  test "select_simulation_strategy/3 picks tensor-network fallback for large workloads in auto mode" do
    assert {:ok, %{selected_path: :tensor_network_fallback, report: report}} =
             Runtime.select_simulation_strategy(:auto, 28, dense_threshold: 20)

    assert report.selected_strategy == :auto
    assert report.qubit_count == 28
  end

  test "select_simulation_strategy/3 returns scaling_limit_exceeded for dense_only above threshold" do
    assert {:error, %{code: :scaling_limit_exceeded, qubit_count: 28, strategy: :dense_only}} =
             Runtime.select_simulation_strategy(:dense_only, 28, dense_threshold: 20)
  end

  test "select_simulation_strategy/3 stays on dense path below threshold" do
    assert {:ok, %{selected_path: :dense_state_vector}} =
             Runtime.select_simulation_strategy(:auto, 12, dense_threshold: 20)
  end

  test "select_simulation_strategy/3 returns the same report for repeated identical inputs" do
    first = Runtime.select_simulation_strategy(:auto, 28, dense_threshold: 20)
    second = Runtime.select_simulation_strategy(:auto, 28, dense_threshold: 20)

    assert first == second
    assert {:ok, %{selected_path: :tensor_network_fallback, report: report}} = first
    assert report.selected_strategy == :auto
    assert report.qubit_count == 28
    assert report.dense_threshold == 20
  end
end
