defmodule NxQuantum.Transpiler do
  @moduledoc """
  Topology-aware transpilation facade.

  Public contract remains stable while internal responsibilities are split into
  focused modules:

  - `NxQuantum.Transpiler.Topology`
  - `NxQuantum.Transpiler.Router`
  - `NxQuantum.Transpiler.SwapInsertion`
  - `NxQuantum.Transpiler.Report`
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Transpiler.Report
  alias NxQuantum.Transpiler.Router
  alias NxQuantum.Transpiler.SwapInsertion
  alias NxQuantum.Transpiler.Topology

  @type mode :: :strict | :insert_swaps
  @type coupling_edge :: {non_neg_integer(), non_neg_integer()}
  @type topology ::
          :all_to_all
          | {:all_to_all, term()}
          | {:heavy_hex, [coupling_edge()]}
          | {:coupling_map, [coupling_edge()]}

  @spec run(Circuit.t(), keyword()) :: {:ok, Circuit.t(), map()} | {:error, map()}
  def run(%Circuit{} = circuit, opts \\ []) do
    mode = Keyword.get(opts, :mode, :strict)
    topology = Keyword.get(opts, :topology, :all_to_all)
    violations = Topology.unsupported_edges(circuit, topology)

    case violations do
      [] ->
        {:ok, attach_transpilation_metadata(circuit, topology), Report.base(mode, topology)}

      [first_edge | _] when mode == :strict ->
        {:error, %{code: :topology_violation, edge: first_edge, topology: topology}}

      _violations when mode == :insert_swaps ->
        case Router.route_violations(violations, topology) do
          {:ok, routing} ->
            swaps = Router.inserted_swaps(routing)
            routed = SwapInsertion.prepend_swaps(circuit, swaps)

            {:ok, attach_transpilation_metadata(routed, topology),
             Report.with_routing(mode, topology, violations, routing, swaps)}

          {:error, edge} ->
            {:error, %{code: :topology_violation, edge: edge, topology: topology}}
        end

      _ ->
        {:error, %{code: :unsupported_transpiler_mode, mode: mode}}
    end
  end

  defp attach_transpilation_metadata(%Circuit{} = circuit, topology) do
    metadata = Map.put(circuit.metadata, :topology, topology)
    %{circuit | metadata: metadata}
  end
end
