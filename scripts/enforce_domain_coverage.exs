defmodule NxQuantum.DomainCoverageGate do
  @moduledoc false

  @domain_exact [
    "NxQuantum",
    "NxQuantum.Circuit",
    "NxQuantum.Observables",
    "NxQuantum.Runtime",
    "NxQuantum.Estimator",
    "NxQuantum.Sampler",
    "NxQuantum.Mitigation",
    "NxQuantum.Grad",
    "NxQuantum.Compiler",
    "NxQuantum.Transpiler",
    "NxQuantum.DynamicIR",
    "NxQuantum.GateOperation",
    "NxQuantum.Gates",
    "NxQuantum.Kernels"
  ]

  @domain_prefixes [
    "NxQuantum.Circuit.",
    "NxQuantum.Observables.",
    "NxQuantum.Runtime.",
    "NxQuantum.Estimator.",
    "NxQuantum.Sampler.",
    "NxQuantum.Mitigation.",
    "NxQuantum.Grad.",
    "NxQuantum.Compiler.",
    "NxQuantum.Transpiler.",
    "NxQuantum.DynamicIR."
  ]

  @export_name "domain_gate"
  @cover_output_dir "cover"

  def run do
    {output, status} = run_mix_test_unit_cover()

    IO.write(output)

    if status != 0 do
      IO.puts("\nDomain coverage gate aborted because test execution failed.")
      System.halt(status)
    end

    module_coverage = analyze_exported_coverage()
    domain_coverage = select_domain_modules(module_coverage)

    case domain_coverage do
      [] ->
        IO.puts("\nDomain coverage gate could not find any configured domain modules in coverage output.")
        System.halt(1)

      modules ->
        failures =
          Enum.filter(modules, fn {_mod, percent} ->
            percent < 100.0
          end)

        if failures == [] do
          IO.puts("\nDomain coverage gate passed: all domain modules are at 100.00%.")
          System.halt(0)
        else
          IO.puts("\nDomain coverage gate failed. The following domain modules are below 100.00%:")

          failures
          |> Enum.sort_by(fn {mod, _percent} -> mod end)
          |> Enum.each(fn {mod, percent} ->
            IO.puts("  - #{mod}: #{format_percent(percent)}%")
          end)

          System.halt(1)
        end
    end
  end

  defp run_mix_test_unit_cover do
    mix_args = ["test.unit", "--cover", "--export-coverage", @export_name]
    env = [{"MIX_ENV", "test"}]
    File.mkdir_p!(@cover_output_dir)
    File.rm(Path.join(@cover_output_dir, "#{@export_name}.coverdata"))

    case System.find_executable("mix") do
      nil ->
        System.cmd("mise", ["exec", "--", "mix" | mix_args], stderr_to_stdout: true, env: env)

      mix_path ->
        System.cmd(mix_path, mix_args, stderr_to_stdout: true, env: env)
    end
  end

  defp analyze_exported_coverage do
    export_path = Path.join(@cover_output_dir, "#{@export_name}.coverdata")

    if not File.exists?(export_path) do
      IO.puts("\nDomain coverage gate could not find exported coverage file at #{export_path}.")
      System.halt(1)
    end

    :cover.stop()
    {:ok, _pid} = :cover.start()
    :cover.local_only()

    beams =
      beam_dirs_for_current_app()
      |> Enum.flat_map(fn beam_dir ->
        beam_dir
        |> File.ls!()
        |> Enum.filter(&String.ends_with?(&1, ".beam"))
        |> Enum.map(&Path.join(beam_dir, &1))
      end)
      |> Enum.map(&String.to_charlist/1)

    case :cover.compile_beam(beams) do
      results when is_list(results) ->
        :ok

      {:error, reason} ->
        IO.puts("\nDomain coverage gate failed to compile beams for coverage: #{inspect(reason)}")
        System.halt(1)
    end

    :ok = :cover.import(String.to_charlist(export_path))
    {:result, lines, _failed} = :cover.analyse(:coverage, :line)
    modules = :cover.modules()
    gather_module_coverage(lines, modules)
  end

  defp gather_module_coverage(lines, modules) do
    module_set = MapSet.new(modules)
    table = :ets.new(__MODULE__, [:set, :private])

    try do
      Enum.each(lines, fn
        {{module, line}, {1, 0}} when line != 0 ->
          if module in module_set, do: :ets.insert(table, {{module, line}, true})

        {{module, line}, {0, 1}} when line != 0 ->
          if module in module_set, do: :ets.insert_new(table, {{module, line}, false})

        _ ->
          :ok
      end)

      Map.new(modules, fn module ->
        covered = :ets.select_count(table, [{{{module, :_}, true}, [], [true]}])
        not_covered = :ets.select_count(table, [{{{module, :_}, false}, [], [true]}])
        {inspect(module), percentage(covered, not_covered)}
      end)
    after
      :ets.delete(table)
      :cover.stop()
    end
  end

  defp select_domain_modules(module_coverage) do
    Enum.filter(module_coverage, fn {module, _percent} ->
      module in @domain_exact or Enum.any?(@domain_prefixes, &String.starts_with?(module, &1))
    end)
  end

  defp format_percent(percent) do
    :erlang.float_to_binary(percent, decimals: 2)
  end

  defp percentage(0, 0), do: 100.0
  defp percentage(covered, not_covered), do: covered / (covered + not_covered) * 100

  defp beam_dirs_for_current_app do
    case :code.which(NxQuantum) do
      path when is_list(path) ->
        [path |> List.to_string() |> Path.dirname()]

      _ ->
        mix_env = System.get_env("MIX_ENV", "test")

        "_build/#{mix_env}/lib/*/ebin/Elixir.NxQuantum.beam"
        |> Path.wildcard()
        |> Enum.map(&Path.dirname/1)
        |> Enum.uniq()
        |> Enum.filter(&File.dir?/1)
        |> case do
          [] ->
            IO.puts("\nDomain coverage gate could not locate beam directory for Elixir.NxQuantum.beam.")
            System.halt(1)

          dirs ->
            dirs
        end
    end
  end
end

NxQuantum.DomainCoverageGate.run()
