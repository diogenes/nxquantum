defmodule NxQuantum.BenchCacheModeGuardTest do
  use ExUnit.Case, async: false

  @repo_root Path.expand("../..", __DIR__)
  @script "bench/nxquantum_python_comparison.exs"

  test "benchmark harness emits sampled lane output with cache_mode" do
    {output, status} =
      System.cmd(
        "mise",
        ["exec", "--", "mix", "run", @script, "1", "cpu_portable", "sampled_counts_sparse_terms", "cold"],
        cd: @repo_root,
        stderr_to_stdout: true
      )

    assert status == 0
    assert output =~ "NXQ_BENCH"
    assert output =~ "scenario=sampled_counts_sparse_terms"
    assert output =~ "cache_mode=cold"
  end

  test "benchmark harness supports cache_mode on batch observable lane" do
    {output, status} =
      System.cmd(
        "mise",
        ["exec", "--", "mix", "run", @script, "1", "cpu_portable", "batch_obs_8q", "cold"],
        cd: @repo_root,
        stderr_to_stdout: true
      )

    assert status == 0
    assert output =~ "NXQ_BENCH"
    assert output =~ "scenario=batch_obs_8q"
    assert output =~ "cache_mode=cold"
  end
end
