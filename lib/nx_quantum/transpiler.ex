defmodule NxQuantum.Transpiler do
  @moduledoc """
  Topology-aware transpilation facade.

  Public contract remains stable while internal responsibilities are split into
  focused modules:

  - NxQuantum.Transpiler.Topology
  - NxQuantum.Transpiler.Router
  - NxQuantum.Transpiler.SwapInsertion
  - NxQuantum.Transpiler.Report
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Transpiler.Report
  alias NxQuantum.Transpiler.Router
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
        report = Map.put(Report.base(mode, topology), :final_layout, identity_layout(circuit.qubits))
        {:ok, attach_transpilation_metadata(circuit, topology), report}

      [first_edge | _] when mode == :strict ->
        {:error, %{code: :topology_violation, edge: first_edge, topology: topology}}

      _violations when mode == :insert_swaps ->
        case Router.route_circuit(circuit, topology) do
          {:ok, %{operations: operations, routing: routing, final_layout: final_layout}} ->
            swaps = Router.inserted_swaps(routing)
            routed = %{circuit | operations: operations}
            report = Map.put(Report.with_routing(mode, topology, violations, routing, swaps), :final_layout, final_layout)

            {:ok, attach_transpilation_metadata(routed, topology), report}

          {:error, edge} ->
            {:error, %{code: :topology_violation, edge: edge, topology: topology}}
        end

      _ ->
        {:error, %{code: :unsupported_transpiler_mode, mode: mode}}
    end
  end

  defp identity_layout(qubits), do: Map.new(0..(qubits - 1), &{&1, &1})

  defp attach_transpilation_metadata(%Circuit{} = circuit, topology) do
    metadata = Map.put(circuit.metadata, :topology, topology)
    %{circuit | metadata: metadata}
  end
end
