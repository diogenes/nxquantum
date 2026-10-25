defmodule NxQuantum.Transpiler.Router do
  @moduledoc false

  alias NxQuantum.GateOperation
  alias NxQuantum.Transpiler.SwapInsertion
  alias NxQuantum.Transpiler.Topology

  @type routing_result :: %{
          from: NxQuantum.Transpiler.coupling_edge(),
          path: [non_neg_integer()],
          inserted_swaps: [NxQuantum.Transpiler.coupling_edge()],
          routed_edge: NxQuantum.Transpiler.coupling_edge() | nil
        }

  @type layout :: %{non_neg_integer() => non_neg_integer()}

  @doc """
  Routes operations in place, starting from the identity layout.

  A CNOT whose current physical wires are not coupled is brought onto a coupled
  edge by SWAPs along the shortest physical path, and the CNOT is rewritten onto
  the routed edge. Every later gate is rewritten through the updated layout, so
  the routed operations equal the input up to the returned final layout
  (logical wire -> physical wire).
  """
  @spec route_operations(
          [GateOperation.t()],
          pos_integer(),
          NxQuantum.Transpiler.topology()
        ) ::
          {:ok, [GateOperation.t()], [routing_result()], layout()}
          | {:error, NxQuantum.Transpiler.coupling_edge()}
  def route_operations(operations, qubits, topology) do
    edges = Topology.coupling_edges(topology)
    identity = Map.new(0..(qubits - 1), &{&1, &1})

    operations
    |> Enum.reduce_while({:ok, {[], [], identity}}, fn op, {:ok, {emitted, routing, layout}} ->
      case route_operation(op, layout, topology, edges) do
        {:ok, ops, records, next_layout} ->
          {:cont, {:ok, {Enum.reverse(ops, emitted), Enum.reverse(records, routing), next_layout}}}

        {:error, _edge} = error ->
          {:halt, error}
      end
    end)
    |> case do
      {:ok, {emitted, routing, layout}} -> {:ok, Enum.reverse(emitted), Enum.reverse(routing), layout}
      {:error, _edge} = error -> error
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

  defp route_operation(%GateOperation{name: :cnot, wires: [control, target]} = op, layout, topology, edges) do
    if Topology.supported_edge?(topology, {layout[control], layout[target]}) do
      {:ok, [remap(op, layout)], [], layout}
    else
      route_cnot(control, target, layout, edges)
    end
  end

  defp route_operation(op, layout, _topology, _edges), do: {:ok, [remap(op, layout)], [], layout}

  defp route_cnot(control, target, layout, edges) do
    case shortest_path({layout[control], layout[target]}, edges) do
      nil ->
        {:error, {control, target}}

      path ->
        path_edges = path_to_edges(path)
        swaps = Enum.drop(path_edges, -1)
        routed_edge = List.last(path_edges)

        {moved_layout, swap_ops} =
          Enum.reduce(swaps, {layout, []}, fn {a, b}, {current, acc} ->
            {swap_layout(current, a, b), [SwapInsertion.swap_operation(a, b) | acc]}
          end)

        cnot = %GateOperation{
          name: :cnot,
          wires: [moved_layout[control], moved_layout[target]],
          params: %{}
        }

        record = %{
          from: {control, target},
          path: path,
          inserted_swaps: swaps,
          routed_edge: routed_edge
        }

        {:ok, Enum.reverse([cnot | swap_ops]), [record], moved_layout}
    end
  end

  defp remap(%GateOperation{wires: wires} = op, layout) do
    %{op | wires: Enum.map(wires, &layout[&1])}
  end

  defp swap_layout(layout, a, b) do
    Map.new(layout, fn
      {logical, ^a} -> {logical, b}
      {logical, ^b} -> {logical, a}
      pair -> pair
    end)
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
