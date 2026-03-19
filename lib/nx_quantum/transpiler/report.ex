defmodule NxQuantum.Transpiler.Report do
  @moduledoc false

  alias NxQuantum.Transpiler.Topology

  @spec base(NxQuantum.Transpiler.mode(), NxQuantum.Transpiler.topology()) :: map()
  def base(mode, topology) do
    %{
      mode: mode,
      topology: topology,
      added_swap_gates: 0,
      depth_delta: 0,
      violations: [],
      routed_edges: [],
      routing_path: nil,
      inserted_swaps: nil,
      topology_id: Topology.topology_id(topology)
    }
  end

  @spec with_routing(
          NxQuantum.Transpiler.mode(),
          NxQuantum.Transpiler.topology(),
          [NxQuantum.Transpiler.coupling_edge()],
          [map()],
          [NxQuantum.Transpiler.coupling_edge()]
        ) :: map()
  def with_routing(mode, topology, violations, routing, swaps) do
    mode
    |> base(topology)
    |> Map.merge(%{
      added_swap_gates: length(swaps),
      depth_delta: length(swaps) * 2,
      violations: violations,
      routed_edges: Enum.map(routing, & &1.routed_edge),
      routing_path: routing |> List.first() |> Map.get(:path),
      inserted_swaps: routing |> List.first() |> Map.get(:inserted_swaps),
      topology_id: Topology.topology_id(topology)
    })
  end
end
