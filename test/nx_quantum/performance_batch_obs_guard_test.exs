defmodule NxQuantum.PerformanceBatchObsGuardTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Performance.BatchObsGuard

  test "run/1 returns typed report with per-op metric" do
    assert {:ok, report} = BatchObsGuard.run(iterations: 2, warmup: 1, max_per_op_ms: 100.0)
    assert report.status == :ok
    assert is_float(report.per_op_ms)
    assert report.per_op_ms > 0.0
    assert report.iterations == 2
  end

  test "run/1 validates invalid iteration and warmup config" do
    assert {:error, %{code: :invalid_batch_obs_guard_config}} =
             BatchObsGuard.run(iterations: 0, warmup: 0, max_per_op_ms: 100.0)
  end
end
