defmodule NxQuantum.PerformanceBatchObsGuardTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Performance.BatchObsGuard

  test "run/1 returns typed report with per-op metric" do
    assert {:ok, report} = BatchObsGuard.run(iterations: 2, warmup: 1, max_per_op_ms: 100.0)
    assert report.status == :ok
    assert is_float(report.per_op_ms)
    assert report.per_op_ms > 0.0
    assert report.iterations == 2
    assert report.cache_mode == :hot
    assert report.guard_mode == :blocking
  end

  test "run/1 validates invalid iteration and warmup config" do
    assert {:error, %{code: :invalid_batch_obs_guard_config}} =
             BatchObsGuard.run(iterations: 0, warmup: 0, max_per_op_ms: 100.0)
  end

  test "cold lane report writes CSV artifact with required schema fields" do
    tmp_dir = Path.join(System.tmp_dir!(), "nxq_batch_obs_guard_test")
    artifact = Path.join(tmp_dir, "cold_report.csv")

    assert {:ok, report} =
             BatchObsGuard.run(
               iterations: 2,
               warmup: 1,
               max_per_op_ms: 100.0,
               cache_mode: :cold,
               artifact_path: artifact
             )

    assert report.cache_mode == :cold
    assert report.guard_mode == :report_only
    assert File.exists?(artifact)

    [header, row] =
      artifact
      |> File.read!()
      |> String.trim()
      |> String.split("\n")

    assert header == "scenario,cache_mode,guard_mode,status,per_op_ms,max_per_op_ms,iterations,warmup,total_ms,value"
    assert row =~ "batch_obs_8q"
    assert row =~ "cold"
    assert row =~ "report_only"
  end

  test "run/1 returns typed error when artifact_path is invalid" do
    assert {:error, %{code: :invalid_artifact_path}} =
             BatchObsGuard.run(
               iterations: 1,
               warmup: 0,
               max_per_op_ms: 100.0,
               cache_mode: :cold,
               artifact_path: :invalid
             )
  end
end
