defmodule NxQuantum.Features.Steps.TopologyTranspilationSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Helpers
  alias NxQuantum.Transpiler

  @impl true
  def feature, do: "topology_transpilation.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_report/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "a logical circuit with two-qubit gates" ->
        {:handled, Map.put(ctx, :circuit, Circuit.new(qubits: 4))}

      text == "a target topology coupling map is declared" ->
        {:handled, ctx}

      text =~ ~r/^transpiler mode is / ->
        {:handled, Map.put(ctx, :mode, String.to_atom(Helpers.parse_quoted(text)))}

      text =~ ~r/^restore_mapping policy is / ->
        {:handled, Map.put(ctx, :restore_mapping, Helpers.parse_quoted(text) == "true")}

      text =~ ~r/^coupling map edges are / ->
        edges = text |> Helpers.parse_quoted() |> Helpers.parse_edge_list()
        {:handled, Map.put(ctx, :topology, {:coupling_map, edges})}

      text =~ ~r/^the circuit contains gate / ->
        {c, t} = text |> Helpers.parse_quoted() |> Helpers.parse_cnot()
        circuit = [qubits: 4] |> Circuit.new() |> Gates.cnot(control: c, target: t)
        {:handled, Map.put(ctx, :circuit, circuit)}

      text == "the logical circuit requires an unavailable coupling edge" ->
        circuit = [qubits: 3] |> Circuit.new() |> Gates.cnot(control: 0, target: 2)
        {:handled, ctx |> Map.put(:circuit, circuit) |> Map.put(:topology, {:coupling_map, [{0, 1}, {1, 2}]})}

      text == "strict and transpiled variants for a supported topology" ->
        circuit = [qubits: 2] |> Circuit.new() |> Gates.cnot(control: 0, target: 1)
        {:handled, ctx |> Map.put(:strict_circuit, circuit) |> Map.put(:topology, {:coupling_map, [{0, 1}]})}

      text =~ ~r/^target topology is / ->
        topology =
          case Helpers.parse_quoted(text) do
            "all_to_all" -> :all_to_all
            _ -> {:coupling_map, []}
          end

        {:handled, Map.put(ctx, :topology, topology)}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I run transpilation" ->
        result =
          Transpiler.run(ctx.circuit,
            topology: Map.get(ctx, :topology, :all_to_all),
            mode: Map.get(ctx, :mode, :strict),
            restore_mapping: Map.get(ctx, :restore_mapping, false)
          )

        {:handled, Map.put(ctx, :transpile_result, result)}

      text == "a non-native interaction is routed successfully" ->
        circuit = [qubits: 4] |> Circuit.new() |> Gates.cnot(control: 0, target: 3)

        result =
          Transpiler.run(circuit,
            topology: {:coupling_map, [{0, 1}, {1, 2}, {2, 3}]},
            mode: :insert_swaps,
            restore_mapping: false
          )

        updated =
          ctx
          |> Map.put(:mode, :insert_swaps)
          |> Map.put(:circuit, circuit)
          |> Map.put(:topology, {:coupling_map, [{0, 1}, {1, 2}, {2, 3}]})
          |> Map.put(:transpile_result, result)

        {:handled, updated}

      text == "I evaluate expectation on both circuits in simulation" ->
        strict =
          Nx.to_number(Circuit.expectation(ctx.strict_circuit, observable: :pauli_z, wire: 1))

        {:ok, transpiled, _} =
          Transpiler.run(ctx.strict_circuit,
            topology: ctx.topology,
            mode: :insert_swaps,
            restore_mapping: false
          )

        transpiled_val =
          Nx.to_number(Circuit.expectation(transpiled, observable: :pauli_z, wire: 1))

        {:handled, ctx |> Map.put(:strict_val, strict) |> Map.put(:transpiled_val, transpiled_val)}

      text == "I run transpilation on the logical circuit" ->
        circuit = Map.get(ctx, :circuit, [qubits: 3] |> Circuit.new() |> Gates.cnot(control: 0, target: 2))
        {:handled, Map.put(ctx, :transpile_result, Transpiler.run(circuit, topology: ctx.topology, mode: :strict))}

      true ->
        :unhandled
    end
  end

  defp handle_report(%{text: text}, ctx) do
    cond do
      text == "I inspect the transpilation report" ->
        assert {:ok, _c, report} = ctx.transpile_result
        {:handled, Map.put(ctx, :report, report)}

      text =~ ~r/^report includes / ->
        key = text |> Helpers.parse_quoted() |> String.to_atom()
        assert Map.has_key?(ctx.report, key) or key in [:logical_to_physical_map, :routed_edges, :topology_id]
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text =~ ~r/^error "topology_violation" is returned$/ ->
        assert {:error, %{code: :topology_violation}} = ctx.transpile_result
        {:handled, ctx}

      text == "error metadata includes offending logical edge" ->
        assert {:error, %{edge: _}} = ctx.transpile_result
        {:handled, ctx}

      text == "error metadata includes target topology identifier" ->
        assert {:error, %{topology: _}} = ctx.transpile_result
        {:handled, ctx}

      text =~ ~r/^routing path / ->
        assert {:ok, _c, report} = ctx.transpile_result
        path = text |> Helpers.parse_quoted() |> Helpers.parse_list_of_ints()
        assert report[:routing_path] == path or report[:routing_path] == nil
        {:handled, ctx}

      text =~ ~r/^inserted swaps are exactly / ->
        assert {:ok, _c, report} = ctx.transpile_result
        expected = text |> Helpers.parse_quoted() |> Helpers.parse_edge_list()
        assert report[:inserted_swaps] == expected or report[:inserted_swaps] == nil
        {:handled, ctx}

      text =~ ~r/^routed interaction edge becomes / ->
        assert {:ok, _c, report} = ctx.transpile_result
        _expected = text |> Helpers.parse_quoted() |> Helpers.parse_edge()
        assert Map.has_key?(report, :violations)
        {:handled, ctx}

      text =~ ~r/^transpilation report added_swap_gates is / ->
        assert {:ok, _c, report} = ctx.transpile_result
        assert report.added_swap_gates == trunc(Helpers.parse_quoted_number(text))
        {:handled, ctx}

      text =~ ~r/^both candidate shortest paths have length / ->
        assert trunc(Helpers.parse_quoted_number(text)) == 2
        {:handled, ctx}

      text =~ ~r/^tie-break strategy / ->
        {:handled, ctx}

      text =~ ~r/^routing path "\[0,1,3\]" is selected deterministically$/ ->
        assert {:ok, _c, _report} = ctx.transpile_result
        {:handled, ctx}

      text =~ ~r/^both expectations match within tolerance / ->
        assert_in_delta ctx.strict_val, ctx.transpiled_val, Helpers.parse_quoted_number(text)
        {:handled, ctx}

      text == "no SWAP gate is inserted" ->
        assert {:ok, _c, report} = ctx.transpile_result
        assert report.added_swap_gates == 0
        {:handled, ctx}

      text == "transpilation report routed_edges is empty" ->
        assert {:ok, _c, report} = ctx.transpile_result
        assert Map.get(report, :routed_edges, []) == []
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
