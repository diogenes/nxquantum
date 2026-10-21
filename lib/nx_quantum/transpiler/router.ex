defmodule NxQuantum.Transpiler.Router do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
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

  @doc """
  Routes a whole circuit while tracking the logical-to-physical layout.

  Each two-qubit gate is rewritten onto the physical wires its logical qubits occupy at that point. When they
  are not adjacent, the first qubit is moved along a shortest path with explicit `:swap` operations. Every
  later gate sees the moved layout, so the routed circuit implements the original unitary, with logical qubit
  `l` ending on physical wire `final_layout[l]`.
  """
  @spec route_circuit(Circuit.t(), NxQuantum.Transpiler.topology()) ::
          {:ok, %{operations: [GateOperation.t()], routing: [routing_result()], final_layout: map()}}
          | {:error, NxQuantum.Transpiler.coupling_edge()}
  def route_circuit(%Circuit{} = circuit, topology) do
    edges = Topology.coupling_edges(topology)
    layout = Map.new(0..(circuit.qubits - 1), &{&1, &1})

    circuit.operations
    |> Enum.reduce_while({:ok, layout, [], []}, fn operation, {:ok, current_layout, ops, routing} ->
      case route_operation(operation, current_layout, topology, edges) do
        {:ok, next_layout, emitted, route} ->
          routing = if route, do: [route | routing], else: routing
          {:cont, {:ok, next_layout, Enum.reverse(emitted, ops), routing}}

        {:error, edge} ->
          {:halt, {:error, edge}}
      end
    end)
    |> case do
      {:ok, final_layout, ops, routing} ->
        {:ok, %{operations: Enum.reverse(ops), routing: Enum.reverse(routing), final_layout: final_layout}}

      {:error, _edge} = error ->
        error
    end
  end

  defp route_operation(%GateOperation{wires: [wire]} = operation, layout, _topology, _edges) do
    {:ok, layout, [%{operation | wires: [Map.fetch!(layout, wire)]}], nil}
  end

  defp route_operation(%GateOperation{wires: [a, b]} = operation, layout, topology, edges) do
    physical_a = Map.fetch!(layout, a)
    physical_b = Map.fetch!(layout, b)

    if Topology.supported_edge?(topology, {physical_a, physical_b}) do
      {:ok, layout, [%{operation | wires: [physical_a, physical_b]}], nil}
    else
      route_non_adjacent(operation, {a, b}, {physical_a, physical_b}, layout, topology, edges)
    end
  end

  defp route_non_adjacent(operation, {a, b} = logical_edge, {physical_a, physical_b}, layout, _topology, edges) do
    case shortest_path({physical_a, physical_b}, edges) do
      nil ->
        {:error, logical_edge}

      path ->
        path_edges = path_to_edges(path)
        moves = Enum.drop(path_edges, -1)

        {moved_layout, swap_ops} =
          Enum.reduce(moves, {layout, []}, fn {p, q}, {acc_layout, acc_ops} ->
            {swap_layout(acc_layout, p, q), [GateOperation.new(:swap, [p, q]) | acc_ops]}
          end)

        # Coupling support is undirected (Topology.edge_in_map?), so the shortest path ends adjacent to physical_b.
        routed = %{operation | wires: [Map.fetch!(moved_layout, a), Map.fetch!(moved_layout, b)]}
        route = %{from: logical_edge, path: path, inserted_swaps: moves, routed_edge: List.last(path_edges)}
        {:ok, moved_layout, Enum.reverse(swap_ops, [routed]), route}
    end
  end

  defp swap_layout(layout, p, q) do
    Map.new(layout, fn {logical, physical} -> {logical, swap_physical(physical, p, q)} end)
  end

  defp swap_physical(physical, p, q) do
    cond do
      physical == p -> q
      physical == q -> p
      true -> physical
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
