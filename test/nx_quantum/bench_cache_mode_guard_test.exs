defmodule NxQuantum.BenchCacheModeGuardTest do
  use ExUnit.Case, async: false

  alias NxQuantum.TestSupport.BenchScenarios

  @repo_root Path.expand("../..", __DIR__)
  @script "bench/nxquantum_python_comparison.exs"
  @legacy_ids ~w(baseline_2q deep_6q batch_obs_8q state_reuse_8q_xy sampled_counts_sparse_terms)

  # Each entry is one `mix run` of the bench script. They are independent, so
  # setup_all starts them concurrently and the tests assert on the captured
  # output instead of paying a VM boot per test in sequence.
  @runs %{
    sampled_cold: ["--scenario", "sampled_counts_z_wires_8q", "--cache-mode", "cold"],
    batch_cold: ["--scenario", "batch_obs_8q", "--cache-mode", "cold"],
    batch_hot: ["--scenario", "batch_obs_8q", "--cache-mode", "hot"],
    family_cold: ["--scenario", "real_zbatch_4q", "--cache-mode", "cold", "--iterations", "3"],
    unknown: ["--scenario", "no_such_scenario"],
    hot_12q: ["--scenario", "real_zbatch_12q", "--cache-mode", "hot"],
    sparse_gap: ["--scenario", "sampled_counts_sparse_terms"]
  }

  setup_all do
    results =
      @runs
      |> Task.async_stream(fn {key, extra} -> {key, run_bench(extra)} end,
        max_concurrency: map_size(@runs),
        timeout: 300_000
      )
      |> Map.new(fn {:ok, {key, result}} -> {key, result} end)

    %{table: BenchScenarios.table(), runs: results}
  end

  test "scenario ids come from the table and keep the legacy ids", %{table: table} do
    ids = Map.keys(table["scenarios"])

    for id <- @legacy_ids, do: assert(id in ids)

    for family <- ["real", "complex"], n <- [4, 8, 12, 16, 20, 24] do
      assert "#{family}_zbatch_#{n}q" in ids
    end

    assert table["scenarios"] |> Map.values() |> Enum.all?(&(&1["warmup"] > 0 and &1["iterations"] > 0))
  end

  test "only cirq_c64 is ungated and every family width has a tolerance for every lane", %{table: table} do
    ungated = for {id, lane} <- table["lanes"], lane["agreement"] == "ungated", do: id
    assert ungated == ["cirq_c64"]
    assert is_boolean(table["tolerances_confirmed"])

    for family <- ["real", "complex"], n <- [4, 8, 12, 16, 20, 24], {lane, _} <- table["lanes"] do
      assert Map.has_key?(table["tolerances"][family][Integer.to_string(n)], lane)
    end
  end

  test "sampled lane emits per-observable values with cold flags applied", %{table: table, runs: runs} do
    id = "sampled_counts_z_wires_8q"
    {output, status} = runs.sampled_cold

    assert status == 0
    assert output =~ "NXQ_BENCH"
    assert output =~ "scenario=#{id}"
    assert output =~ "cache_mode=cold"
    # Known Gap: the counts path reports no library cache mode.
    assert output =~ "library_cache_mode=unreported"
    assert output =~ "cache_parsed_counts=false"
    assert output =~ "cache_mask_lookup_plan=false"
    assert_iteration_values(output, length(table["scenarios"][id]["observables"]), 2)
  end

  test "batch observable lane emits per-observable values and applies the cold and hot flags", %{table: table, runs: runs} do
    id = "batch_obs_8q"
    expected = length(table["scenarios"][id]["observables"])

    {cold, cold_status} = runs.batch_cold
    assert cold_status == 0
    assert cold =~ "scenario=#{id}"
    assert cold =~ "cache_mode=cold"
    assert cold =~ "library_cache_mode=disabled"
    assert cold =~ "flags=cache_evolved_state=false"
    assert_iteration_values(cold, expected, 2)

    {hot, hot_status} = runs.batch_hot
    assert hot_status == 0
    assert hot =~ "library_cache_mode=enabled"
    assert hot =~ "flags=cache_evolved_state=true"
  end

  test "cold family lane uses a distinct angle set per iteration", %{runs: runs} do
    {output, status} = runs.family_cold

    assert status == 0
    assert output =~ "flags=cache_evolved_state=false"
    rows = assert_iteration_values(output, 4, 3)
    assert rows |> Enum.uniq() |> length() == 3
  end

  test "an unknown scenario id raises", %{runs: runs} do
    {output, status} = runs.unknown

    assert status != 0
    assert output =~ "unknown scenario id"
  end

  test "hot mode is refused above 10 qubits and the sparse-terms lane is a recorded gap", %{runs: runs} do
    {hot_output, hot_status} = runs.hot_12q
    assert hot_status != 0
    assert hot_output =~ "does not allow cache mode hot"

    {gap_output, gap_status} = runs.sparse_gap
    assert gap_status != 0
    assert gap_output =~ "Known Gap"
  end

  defp assert_iteration_values(output, observable_count, iteration_count) do
    rows =
      for line <- String.split(output, "\n"), String.starts_with?(line, "NXQ_ITER ") do
        [_, values] = Regex.run(~r/values=(\S+)/, line)
        values |> String.split(",") |> Enum.map(&String.to_float/1)
      end

    assert length(rows) == iteration_count
    assert Enum.all?(rows, &(length(&1) == observable_count))
    rows
  end

  defp run_bench(extra) do
    args = ["run", @script, "--mode", "values", "--profile", "cpu_portable", "--warmup", "1", "--iterations", "2"]
    args = args ++ extra

    {cmd, cmd_args} = mix_command()
    System.cmd(cmd, cmd_args ++ args, cd: @repo_root, stderr_to_stdout: true)
  end

  # Plain `mix` from PATH by default. NXQ_BENCH_MIX_CMD (for example
  # "mise exec -- mix") replaces it, matching the Python harness.
  defp mix_command do
    words =
      case System.get_env("NXQ_BENCH_MIX_CMD") do
        value when value in [nil, ""] -> ["mix"]
        value -> OptionParser.split(value)
      end

    [program | rest] = words
    {System.find_executable(program) || raise("#{program} not found on PATH"), rest}
  end
end
