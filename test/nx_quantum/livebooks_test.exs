defmodule NxQuantum.LivebooksTest do
  # async: false. Notebook cells run in a spawned process, but they share global state with
  # other tests (module table, telemetry handlers, OS environment).
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO, only: [with_io: 2]

  @repo_root Path.expand("../..", __DIR__)
  @notebooks "examples/livebook/*.livemd" |> Path.expand(@repo_root) |> Path.wildcard() |> Enum.sort()
  @goldens_dir Path.expand("test/fixtures/livebooks", @repo_root)
  @getting_started Path.expand("test/fixtures/docs/getting_started_first_result.elixir", @repo_root)

  # The only setup cell form the test accepts. Livebook resolves the relative path against the
  # notebook directory, which is examples/livebook/, so "../.." is the repository root.
  @setup_cell_ast quote(do: Mix.install([{:nx_quantum, path: "../.."}]))

  @checkpoint_marker ~r/\A\s*#\s*checkpoint:\s*([a-z][a-z0-9_]*)\s*$/m
  @env_functions [:get_env, :fetch_env, :fetch_env!, :put_env, :delete_env, :get_env]
  @float_tolerance 1.0e-6

  test "the repository ships at least three notebooks" do
    assert length(@notebooks) >= 3
  end

  for notebook <- @notebooks do
    @notebook notebook
    name = Path.basename(notebook, ".livemd")

    describe "notebook #{name}" do
      test "has the exact setup cell and no executable live-lane reads" do
        {setup, cells} = split_setup!(@notebook)

        assert normalize_ast(Code.string_to_quoted!(setup.code)) == normalize_ast(@setup_cell_ast),
               "#{rel(@notebook)}:#{setup.line}: setup cell must be exactly " <>
                 ~s|Mix.install([{:nx_quantum, path: "../.."}])|

        assert File.exists?(Path.join(Path.expand("../..", Path.dirname(@notebook)), "mix.exs"))

        for cell <- cells, offence <- live_lane_reads(cell.code) do
          flunk(
            "#{rel(@notebook)}:#{cell.line}: executable live-lane access (#{offence}); show live keys as text instead"
          )
        end
      end

      test "runs twice with identical checkpoints that match the goldens" do
        {_setup, cells} = split_setup!(@notebook)
        assert_no_live_env!()

        first = run_cells!(@notebook, cells)
        second = run_cells!(@notebook, cells)

        assert first.checkpoints != %{}, "#{rel(@notebook)} declares no `# checkpoint:` cell"
        assert first.checkpoints == second.checkpoints
        assert_matches_goldens!(@notebook, first.checkpoints)
      end
    end
  end

  describe "getting-started first result snippet" do
    test "evaluates to cos(1.2) within the documented f32 tolerance, twice" do
      code = File.read!(@getting_started)
      cells = [%{line: 1, code: code, checkpoint: "first_result"}]

      first = run_cells!(@getting_started, cells)
      second = run_cells!(@getting_started, cells)

      assert first.checkpoints == second.checkpoints
      [value] = List.wrap(first.checkpoints["first_result"])
      assert_in_delta value, :math.cos(1.2), @float_tolerance
    end

    test "uses stable API only" do
      code = File.read!(@getting_started)
      refute code =~ "Sampler"
      assert code =~ "Estimator."
    end
  end

  describe "extractor" do
    test "rejects a setup cell that Livebook would read as a Hex package" do
      bad = Code.string_to_quoted!(~s|Mix.install(path: "../..")|)
      refute normalize_ast(bad) == normalize_ast(@setup_cell_ast)
    end

    test "flags executable live-lane env reads but not text mentions" do
      assert [_] = live_lane_reads(~s|System.get_env("NXQ_PROVIDER_LIVE_IBM_RUNTIME")|)
      assert [_] = live_lane_reads(~s|System.put_env("NXQ_PROVIDER_LIVE", "1")|)
      assert [_] = live_lane_reads("System.get_env(key)")
      assert [] = live_lane_reads(~s|keys = ["NXQ_PROVIDER_LIVE_IBM_RUNTIME"]|)
    end

    test "tolerance applies to floats only" do
      assert values_match?(0.5, 0.5 + 5.0e-7)
      refute values_match?(0.5, 0.5 + 5.0e-6)
      refute values_match?(1325, 1326)
      refute values_match?("v1:aa", "v1:ab")
    end
  end

  # -- extraction ---------------------------------------------------------------------------

  defp rel(path), do: Path.relative_to(path, @repo_root)

  defp split_setup!(notebook) do
    case extract_cells(File.read!(notebook)) do
      [setup | cells] -> {setup, cells}
      [] -> flunk("#{rel(notebook)} has no elixir cells")
    end
  end

  # Returns the fenced `elixir` blocks in order. Blocks tagged anything else (`text`, `bash`)
  # are documentation and never run.
  defp extract_cells(markdown) do
    markdown
    |> String.split("\n")
    |> Enum.with_index(1)
    |> Enum.reduce({nil, []}, fn
      {"```elixir", line}, {nil, acc} ->
        {%{line: line + 1, lines: []}, acc}

      {"```" <> _, _line}, {nil, acc} ->
        {:other, acc}

      {_text, _line}, {nil, acc} ->
        {nil, acc}

      {"```", _line}, {:other, acc} ->
        {nil, acc}

      {_text, _line}, {:other, acc} ->
        {:other, acc}

      {"```", _line}, {cell, acc} ->
        code = cell.lines |> Enum.reverse() |> Enum.join("\n")
        {nil, [%{line: cell.line, code: code, checkpoint: checkpoint_name(code)} | acc]}

      {text, _line}, {cell, acc} ->
        {%{cell | lines: [text | cell.lines]}, acc}
    end)
    |> then(fn {_state, acc} -> Enum.reverse(acc) end)
  end

  defp checkpoint_name(code) do
    case Regex.run(@checkpoint_marker, first_line(code)) do
      [_, name] -> name
      nil -> nil
    end
  end

  defp first_line(code), do: code |> String.trim_leading() |> String.split("\n", parts: 2) |> hd()

  defp normalize_ast(ast), do: Macro.prewalk(ast, &Macro.update_meta(&1, fn _ -> [] end))

  # -- live-lane guard ----------------------------------------------------------------------

  defp live_lane_reads(code) do
    {_ast, offences} =
      code
      |> Code.string_to_quoted!()
      |> Macro.prewalk([], fn
        {{:., _, [{:__aliases__, _, [:System]}, fun]}, _, [key | _]} = node, acc when fun in @env_functions ->
          {node, offence(fun, key, acc)}

        node, acc ->
          {node, acc}
      end)

    Enum.reverse(offences)
  end

  defp offence(fun, key, acc) when is_binary(key) do
    if String.starts_with?(key, "NXQ_PROVIDER_LIVE"), do: ["System.#{fun}(#{inspect(key)})" | acc], else: acc
  end

  defp offence(fun, _dynamic_key, acc), do: ["System.#{fun}/N with a non-literal key" | acc]

  defp assert_no_live_env! do
    live = for {key, _} <- System.get_env(), String.starts_with?(key, "NXQ_PROVIDER_LIVE"), do: key
    assert live == [], "unset #{inspect(live)}: notebooks must run in the fixture lane"
  end

  # -- evaluation ---------------------------------------------------------------------------

  # Runs every cell in one fresh process, the way a Livebook runtime evaluates a notebook:
  # one process dictionary, one carried binding, one carried env (aliases and imports).
  # The process, the processes linked to it, the modules the cells defined, and any telemetry
  # handlers the cells attached are gone when this returns.
  defp run_cells!(source, cells) do
    modules_before = MapSet.new(:code.all_loaded(), &elem(&1, 0))
    handlers_before = MapSet.new(:telemetry.list_handlers([]), & &1.id)
    previous_conflict = Code.get_compiler_option(:ignore_module_conflict)
    Code.put_compiler_option(:ignore_module_conflict, true)

    try do
      parent = self()

      {outcome, stderr} =
        with_io(:stderr, fn ->
          {pid, ref} = spawn_monitor(fn -> send(parent, {:notebook_run, self(), eval_cells(source, cells)}) end)

          receive do
            {:notebook_run, ^pid, result} ->
              await_down(pid, ref)
              result

            {:DOWN, ^ref, :process, ^pid, reason} ->
              {:crash, reason}
          after
            60_000 ->
              Process.exit(pid, :kill)
              {:crash, :timeout}
          end
        end)

      assert_no_warnings!(source, stderr)

      case outcome do
        {:ok, checkpoints} -> %{checkpoints: checkpoints}
        {:crash, reason} -> flunk("#{rel(source)} crashed: #{inspect(reason)}")
      end
    after
      Code.put_compiler_option(:ignore_module_conflict, previous_conflict)

      for %{id: id} <- :telemetry.list_handlers([]), not MapSet.member?(handlers_before, id) do
        :telemetry.detach(id)
      end

      for {module, _} <- :code.all_loaded(), not MapSet.member?(modules_before, module) do
        :code.purge(module)
        :code.delete(module)
        :code.purge(module)
      end
    end
  end

  defp await_down(pid, ref) do
    receive do
      {:DOWN, ^ref, :process, ^pid, _} -> :ok
    after
      5_000 -> flunk("notebook process did not exit")
    end
  end

  defp assert_no_warnings!(source, stderr) do
    refute stderr =~ "warning", "#{rel(source)} printed warnings:\n#{stderr}"
  end

  defp eval_cells(source, cells) do
    env = Code.env_for_eval(file: source)

    try do
      {checkpoints, _binding, _env} =
        Enum.reduce(cells, {%{}, [], env}, fn cell, {checkpoints, binding, env} ->
          {value, binding, env} = eval_cell(source, cell, binding, env)
          {record_checkpoint(checkpoints, source, cell, value), binding, env}
        end)

      {:ok, checkpoints}
    rescue
      error -> {:crash, Exception.format(:error, error, __STACKTRACE__)}
    after
      stop_linked_processes()
    end
  end

  defp eval_cell(source, cell, binding, env) do
    quoted = Code.string_to_quoted!(cell.code, file: source, line: cell.line)
    Code.eval_quoted_with_env(quoted, binding, env)
  end

  defp record_checkpoint(checkpoints, _source, %{checkpoint: nil}, _value), do: checkpoints

  defp record_checkpoint(checkpoints, source, %{checkpoint: name, line: line}, value) do
    if Map.has_key?(checkpoints, name), do: raise("#{rel(source)}:#{line}: duplicate checkpoint #{name}")
    Map.put(checkpoints, name, plain!(value, "#{rel(source)}:#{line} checkpoint #{name}"))
  end

  # Supervisors the cells started are linked to the run process. Stop them and wait, so a
  # second run never sees the first run's registered names.
  defp stop_linked_processes do
    {:links, links} = Process.info(self(), :links)

    for pid <- links, is_pid(pid), pid != Process.whereis(:user) do
      ref = Process.monitor(pid)
      Process.exit(pid, :shutdown)

      receive do
        {:DOWN, ^ref, :process, ^pid, _} -> :ok
      after
        2_000 ->
          Process.exit(pid, :kill)

          receive do
            {:DOWN, ^ref, :process, ^pid, _} -> :ok
          end
      end
    end
  end

  # Checkpoints are plain data so they can be compared exactly and written as goldens.
  defp plain!(%Nx.Tensor{} = tensor, _where), do: Nx.to_flat_list(tensor)
  defp plain!(%_{}, where), do: raise("#{where}: structs are not valid checkpoint values; extract plain fields")
  defp plain!(map, where) when is_map(map), do: Map.new(map, fn {k, v} -> {plain!(k, where), plain!(v, where)} end)
  defp plain!(list, where) when is_list(list), do: Enum.map(list, &plain!(&1, where))

  defp plain!(tuple, where) when is_tuple(tuple),
    do: tuple |> Tuple.to_list() |> Enum.map(&plain!(&1, where)) |> List.to_tuple()

  defp plain!(value, _where) when is_number(value) or is_binary(value) or is_atom(value), do: value
  defp plain!(value, where), do: raise("#{where}: unsupported checkpoint value #{inspect(value)}")

  # -- goldens ------------------------------------------------------------------------------

  defp assert_matches_goldens!(notebook, checkpoints) do
    path = Path.join(@goldens_dir, Path.basename(notebook, ".livemd") <> ".golden")
    assert File.exists?(path), "missing goldens file #{rel(path)}"
    {goldens, _} = Code.eval_file(path)

    assert Enum.sort(Map.keys(goldens)) == Enum.sort(Map.keys(checkpoints)),
           "#{rel(path)} and the notebook's checkpoints must name the same cells"

    for {name, golden} <- goldens do
      actual = Map.fetch!(checkpoints, name)

      assert values_match?(golden, actual),
             "#{rel(notebook)} checkpoint #{name}: expected #{inspect(golden)}, got #{inspect(actual)}"
    end
  end

  # Exact for integers, binaries, atoms (counts, ids, fingerprints). Floats (f32 results) get
  # an absolute tolerance of 1.0e-6, the floor documented in docs/backend-support.md.
  defp values_match?(a, b) when is_float(a) and is_float(b), do: abs(a - b) <= @float_tolerance

  defp values_match?(a, b) when is_list(a) and is_list(b) and length(a) == length(b),
    do: Enum.all?(Enum.zip(a, b), fn {x, y} -> values_match?(x, y) end)

  defp values_match?(a, b) when is_tuple(a) and is_tuple(b), do: values_match?(Tuple.to_list(a), Tuple.to_list(b))

  defp values_match?(a, b) when is_map(a) and is_map(b) do
    Enum.sort(Map.keys(a)) == Enum.sort(Map.keys(b)) and Enum.all?(a, fn {k, v} -> values_match?(v, Map.fetch!(b, k)) end)
  end

  defp values_match?(a, b), do: a === b
end
