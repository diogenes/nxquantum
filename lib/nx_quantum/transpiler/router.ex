defmodule NxQuantum.Transpiler.Router do
  @moduledoc false

  alias NxQuantum.Transpiler.Topology

  @type routing_result :: %{
          from: NxQuantum.Transpiler.coupling_edge(),
          path: [non_neg_integer()],
          inserted_swaps: [NxQuantum.Transpiler.coupling_edge()],
          routed_edge: NxQuantum.Transpiler.coupling_edge() | nil
        }

  @spec route_violations([NxQuantum.Transpiler.coupling_edge()], NxQuantum.Transpiler.topology()) ::
          {:ok, [routing_result()]} | {:error, NxQuantum.Transpiler.coupling_edge()}
  def route_violations(violations, topology) do
    edges = Topology.coupling_edges(topology)

    violations
    |> Enum.reduce_while({:ok, []}, fn edge, {:ok, acc} ->
      case shortest_path(edge, edges) do
        nil ->
          {:halt, {:error, edge}}

        path ->
          path_edges = path_to_edges(path)
          inserted_swaps = Enum.drop(path_edges, -1)
          routed_edge = List.last(path_edges)

          routed = %{
            from: edge,
            path: path,
            inserted_swaps: inserted_swaps,
            routed_edge: routed_edge
          }

          {:cont, {:ok, [routed | acc]}}
      end
    end)
    |> case do
      {:ok, routing} -> {:ok, Enum.reverse(routing)}
      other -> other
    end
  end

  @spec inserted_swaps([routing_result()]) :: [NxQuantum.Transpiler.coupling_edge()]
  def inserted_swaps(routing), do: Enum.flat_map(routing, & &1.inserted_swaps)

  @spec shortest_path(
          NxQuantum.Transpiler.coupling_edge(),
          [NxQuantum.Transpiler.coupling_edge()]
        ) ::
          [non_neg_integer()] | nil
  def shortest_path({start, target}, _edges) when start == target, do: [start]

  def shortest_path({start, target}, edges) do
    adjacency = build_adjacency(edges)
    bfs([[start]], MapSet.new([start]), target, adjacency)
  end

  defp path_to_edges(path) do
    path
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.map(fn [a, b] -> {a, b} end)
  end

  defp build_adjacency(edges) do
    Enum.reduce(edges, %{}, fn {a, b}, acc ->
      acc
      |> Map.update(a, [b], &[b | &1])
      |> Map.update(b, [a], &[a | &1])
    end)
  end

  defp bfs([], _visited, _target, _adjacency), do: nil

  defp bfs([path | rest], visited, target, adjacency) do
    current = List.last(path)

    if current == target do
      path
    else
      neighbors =
        adjacency
        |> Map.get(current, [])
        |> Enum.sort()
        |> Enum.reject(&MapSet.member?(visited, &1))

      new_paths = Enum.map(neighbors, fn n -> path ++ [n] end)
      new_visited = Enum.reduce(neighbors, visited, &MapSet.put(&2, &1))
      bfs(rest ++ new_paths, new_visited, target, adjacency)
    end
  end
end
