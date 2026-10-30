defmodule NxQuantum.BenchTimedRefusalTest do
  use ExUnit.Case, async: false

  # Timed mode must refuse while the scenario table says tolerances_confirmed=false.
  # Runs the real harness script from a temp copy of bench/ whose table has the flag
  # flipped, so the committed table is never touched.
  @repo_root Path.expand("../..", __DIR__)
  @python Path.join(@repo_root, ".venv-bench/bin/python")

  @moduletag skip: if(File.exists?(@python), do: false, else: ".venv-bench is not present")

  setup do
    root = Path.join(System.tmp_dir!(), "nxq_refusal_#{System.unique_integer([:positive])}")
    File.mkdir_p!(Path.join(root, "bench"))

    File.cp!(
      Path.join(@repo_root, "bench/python_alternatives_benchmark.py"),
      Path.join(root, "bench/python_alternatives_benchmark.py")
    )

    File.cp_r!(Path.join(@repo_root, "bench/scenarios"), Path.join(root, "bench/scenarios"))
    on_exit(fn -> File.rm_rf!(root) end)
    %{root: root}
  end

  # An unknown scenario id raises right after the flag check, so no timed run can start.
  defp run_timed(root) do
    script = Path.join(root, "bench/python_alternatives_benchmark.py")
    args = ["-I", script, "--mode", "timed", "--cache-mode", "hot", "--scenario", "no_such_scenario"]
    System.cmd(@python, args, stderr_to_stdout: true)
  end

  test "timed mode refuses when tolerances_confirmed is false", %{root: root} do
    table_path = Path.join(root, "bench/scenarios/python_alternatives.json")
    table = table_path |> File.read!() |> JSON.decode!()
    assert table["tolerances_confirmed"] == true

    File.write!(table_path, table |> Map.put("tolerances_confirmed", false) |> JSON.encode!())

    {output, status} = run_timed(root)
    assert status != 0
    assert output =~ "REFUSED: timed mode needs \"tolerances_confirmed\": true"
  end

  test "timed mode does not refuse on the flag when it is true (stops at the unknown-scenario guard)", %{root: root} do
    {output, status} = run_timed(root)
    assert status != 0
    refute output =~ "REFUSED"
    assert output =~ "no_such_scenario"
    assert output =~ "FIXTURE sha256="
  end
end
