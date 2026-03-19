defmodule NxQuantum.Architecture.DependencyDirectionTest do
  use ExUnit.Case, async: true

  @root "/Users/diogenes/Projects/diogenes/nxquantum"

  @domain_files [
    "lib/nx_quantum/circuit.ex",
    "lib/nx_quantum/circuit/error.ex",
    "lib/nx_quantum/circuit/validation.ex",
    "lib/nx_quantum/gate_operation.ex",
    "lib/nx_quantum/gates.ex",
    "lib/nx_quantum/observables.ex",
    "lib/nx_quantum/observables/error.ex",
    "lib/nx_quantum/observables/schema.ex"
  ]

  test "domain layer does not depend on application or adapters" do
    violations =
      layer_violations(
        @domain_files,
        ["NxQuantum.Application.", "NxQuantum.Adapters."]
      )

    assert violations == []
  end

  test "application layer does not depend on adapters" do
    files = layer_files("lib/nx_quantum/application/**/*.ex")

    violations =
      layer_violations(
        files,
        ["NxQuantum.Adapters."]
      )

    assert violations == []
  end

  test "ports layer does not depend on application or adapters" do
    files = layer_files("lib/nx_quantum/ports/**/*.ex")

    violations =
      layer_violations(
        files,
        ["NxQuantum.Application.", "NxQuantum.Adapters."]
      )

    assert violations == []
  end

  test "adapters do not depend on application layer" do
    files = layer_files("lib/nx_quantum/adapters/**/*.ex")

    violations =
      layer_violations(
        files,
        ["NxQuantum.Application."]
      )

    assert violations == []
  end

  defp layer_files(glob) do
    @root
    |> Path.join(glob)
    |> Path.wildcard()
    |> Enum.map(&Path.relative_to(&1, @root))
    |> Enum.sort()
  end

  defp layer_violations(relative_files, forbidden_prefixes) do
    Enum.flat_map(relative_files, fn rel_path ->
      rel_path
      |> referenced_modules()
      |> Enum.filter(fn mod ->
        Enum.any?(forbidden_prefixes, &String.starts_with?(mod, &1))
      end)
      |> Enum.map(fn dep -> %{file: rel_path, dependency: dep} end)
    end)
  end

  defp referenced_modules(relative_path) do
    path = Path.join(@root, relative_path)
    source = File.read!(path)
    ast = Code.string_to_quoted!(source)

    {_ast, refs} =
      Macro.prewalk(ast, MapSet.new(), fn node, acc ->
        {node, maybe_capture_module(node, acc)}
      end)

    refs
    |> MapSet.to_list()
    |> Enum.sort()
  end

  defp maybe_capture_module({:alias, _meta, alias_args}, acc) when is_list(alias_args) do
    case alias_args do
      [{:__aliases__, _, parts}] when is_list(parts) ->
        MapSet.put(acc, Enum.join(parts, "."))

      [{:__aliases__, _, prefix_parts}, [as: {:__aliases__, _, suffix_parts}]]
      when is_list(prefix_parts) and is_list(suffix_parts) ->
        # alias Foo.{Bar, Baz} expands during compilation; keep explicit prefix for policy checks.
        MapSet.put(acc, Enum.join(prefix_parts, "."))

      _ ->
        acc
    end
  end

  defp maybe_capture_module({{:., _, [{:__aliases__, _, parts}, _fun]}, _, _args}, acc) when is_list(parts) do
    MapSet.put(acc, Enum.join(parts, "."))
  end

  defp maybe_capture_module({:%, _, [{:__aliases__, _, parts}, _struct_map]}, acc) when is_list(parts) do
    MapSet.put(acc, Enum.join(parts, "."))
  end

  defp maybe_capture_module(_node, acc), do: acc
end
