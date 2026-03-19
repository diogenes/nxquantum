defmodule NxQuantum.Transpiler.Topology do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation

  @spec unsupported_edges(Circuit.t(), NxQuantum.Transpiler.topology()) ::
          [NxQuantum.Transpiler.coupling_edge()]
  def unsupported_edges(%Circuit{} = circuit, topology) do
    Enum.reduce(circuit.operations, [], fn
      %GateOperation{name: :cnot, wires: [a, b]}, acc ->
        if supported_edge?(topology, {a, b}), do: acc, else: acc ++ [{a, b}]

      _op, acc ->
        acc
    end)
  end

  @spec coupling_edges(NxQuantum.Transpiler.topology()) :: [NxQuantum.Transpiler.coupling_edge()]
  def coupling_edges(:all_to_all), do: []
  def coupling_edges({:all_to_all, _metadata}), do: []
  def coupling_edges({:heavy_hex, coupling_map}), do: coupling_map
  def coupling_edges({:coupling_map, coupling_map}), do: coupling_map

  @spec topology_id(NxQuantum.Transpiler.topology()) :: atom()
  def topology_id(:all_to_all), do: :all_to_all
  def topology_id({:all_to_all, _}), do: :all_to_all
  def topology_id({:heavy_hex, _}), do: :heavy_hex
  def topology_id({:coupling_map, _}), do: :coupling_map

  @spec supported_edge?(
          NxQuantum.Transpiler.topology(),
          NxQuantum.Transpiler.coupling_edge()
        ) :: boolean()
  def supported_edge?(:all_to_all, _edge), do: true
  def supported_edge?({:all_to_all, _metadata}, _edge), do: true

  def supported_edge?({:heavy_hex, coupling_map}, edge), do: edge_in_map?(coupling_map, edge)
  def supported_edge?({:coupling_map, coupling_map}, edge), do: edge_in_map?(coupling_map, edge)

  def supported_edge?(unknown_topology, _edge) do
    raise ArgumentError, "unsupported topology #{inspect(unknown_topology)}"
  end

  defp edge_in_map?(coupling_map, {a, b}) when is_list(coupling_map) do
    Enum.any?(coupling_map, fn
      {^a, ^b} -> true
      {^b, ^a} -> true
      _ -> false
    end)
  end
end
