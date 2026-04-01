defmodule NxQuantum.DomainCoreCoverageTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Circuit.Error, as: CircuitError
  alias NxQuantum.Circuit.Validation
  alias NxQuantum.Compiler.PassPipeline
  alias NxQuantum.Compiler.Target
  alias NxQuantum.Compiler.Theta
  alias NxQuantum.GateOperation
  alias NxQuantum.Gates
  alias NxQuantum.Mitigation.Passes.Readout
  alias NxQuantum.Mitigation.Passes.ZneLinear
  alias NxQuantum.Mitigation.PassPipeline, as: MitigationPassPipeline
  alias NxQuantum.Observables
  alias NxQuantum.Observables.Error, as: ObservablesError
  alias NxQuantum.Observables.Schema
  alias NxQuantum.Runtime
  alias NxQuantum.Runtime.Detection
  alias NxQuantum.Runtime.Fallback
  alias NxQuantum.Sampler
  alias NxQuantum.Sampler.Engine
  alias NxQuantum.Transpiler
  alias NxQuantum.Transpiler.Router
  alias NxQuantum.Transpiler.Topology

  describe "NxQuantum facade delegates" do
    test "delegates circuit, runtime, estimator and sampler entrypoints" do
      assert %Circuit{qubits: 2} = NxQuantum.new_circuit(qubits: 2)
      assert NxQuantum.runtime_profiles() == Runtime.supported_profiles()

      capabilities =
        NxQuantum.runtime_capabilities(
          detector: fn
            :cpu_portable -> true
            _ -> false
          end
        )

      assert Enum.find(capabilities, &(&1.id == :cpu_portable)).available

      circuit = Circuit.new(qubits: 1)

      assert {:ok, estimate} = NxQuantum.estimate(circuit, observable: :pauli_z, wire: 0)
      assert match?(%Nx.Tensor{}, estimate.values)

      assert {:ok, sample} = NxQuantum.sample(circuit, shots: 32, seed: 17)
      assert sample.counts["0"] + sample.counts["1"] == 32
    end

    test "delegates AI requests and returns typed tool errors" do
      request = %{
        schema_version: "v1",
        request_id: "req-core-1",
        correlation_id: "corr-core-1",
        tool_name: "unknown-tool",
        input: %{}
      }

      assert {:error, %{code: :ai_tool_unsupported, details: %{tool_name: "unknown-tool"}}} =
               NxQuantum.run_ai_tool(request)
    end
  end

  describe "domain helper modules" do
    test "observables supported and normalize" do
      assert Observables.supported() == [:pauli_x, :pauli_y, :pauli_z]
      assert Observables.normalize(:pauli_y) == :pauli_y
    end

    test "typed circuit/observable errors allow default details" do
      assert %CircuitError{code: :invalid_wire_index, details: %{}} =
               CircuitError.new(:invalid_wire_index)

      assert %ObservablesError{code: :unsupported_observable, details: %{}} =
               ObservablesError.new(:unsupported_observable)
    end

    test "observable schema covers wire validation and invalid qubits branches" do
      assert {:ok, 0} = Schema.normalize_wire(0)

      assert {:error, %{code: :invalid_measurement_wire}} =
               Schema.normalize_wire(-1)

      assert {:error, %{code: :invalid_measurement_wire}} =
               Schema.normalize_wire("0")

      assert {:error, %{code: :invalid_qubit_count, qubits: 0}} =
               Schema.measurement(:pauli_x, 0, 0)

      assert_raise ObservablesError, fn ->
        Schema.measurement!(:pauli_z, 2, 2)
      end
    end
  end

  describe "compiler internals" do
    test "theta helpers cover numeric and tensor branches" do
      op = %GateOperation{name: :rx, wires: [0], params: %{theta: 0.2}}
      assert Theta.value(op) == 0.2
      assert Theta.value(%{op | params: %{}}) == 0.0
      assert Theta.to_number(Nx.tensor(0.5)) == 0.5
      assert Theta.to_number(0.7) == 0.7
      assert Theta.put(op, 1.2).params.theta == 1.2

      assert Theta.add(0.1, 0.2) == 0.30000000000000004
      assert Nx.to_number(Theta.add(Nx.tensor(0.5), Nx.tensor(0.25))) == 0.75
      assert Nx.to_number(Theta.add(Nx.tensor(0.5), 0.25)) == 0.75
      assert Nx.to_number(Theta.add(0.5, Nx.tensor(0.25))) == 0.75
    end

    test "pass pipeline returns unchanged operations for unknown pass" do
      operations = [%GateOperation{name: :h, wires: [0], params: %{}}]
      assert PassPipeline.run(:unknown, operations, []) == operations
    end

    test "pass pipeline executes each named pass branch" do
      operations =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.h(0)
        |> Gates.rx(0, theta: 0.1)
        |> Gates.rx(0, theta: 0.2)
        |> Map.fetch!(:operations)

      assert is_list(PassPipeline.run(:simplify, operations, []))
      assert is_list(PassPipeline.run(:simplify, operations))
      assert is_list(PassPipeline.run(:fuse, operations, []))
      assert is_list(PassPipeline.run(:cancel, operations, []))
      assert is_list(PassPipeline.run(:resynthesize_1q, operations, resynthesis_tolerance: 1.0e-4))
    end

    test "compiler compile covers target parsing and routing error branches" do
      circuit =
        [qubits: 3]
        |> Circuit.new()
        |> Gates.cnot(control: 0, target: 2)

      assert {:ok, %{report: report}} = NxQuantum.Compiler.compile(circuit, optimization_level: 0)
      assert report.optimizer.passes == [:simplify]

      assert {:ok, %{report: report}} =
               NxQuantum.Compiler.compile(circuit,
                 optimization_level: 1,
                 calibration_profile: :latency_first,
                 scheduling_strategy: :none
               )

      assert report.cost_model.profile == :latency_first
      assert report.scheduling.strategy == :none

      assert {:error, %{code: :compiler_invalid_target, stage: :validation, reason: :invalid_gateset}} =
               NxQuantum.Compiler.compile(circuit, target: %{coupling_map: []})

      strict_target = %Target{gateset: [:cnot], coupling_map: [{0, 1}, {1, 2}]}

      assert {:error, %{code: :compiler_topology_violation, stage: :routing}} =
               NxQuantum.Compiler.compile(circuit, target: strict_target, routing_strategy: :shortest_path)

      assert {:ok, %{report: report}} =
               NxQuantum.Compiler.compile(circuit,
                 target: %Target{gateset: [:cnot], coupling_map: []},
                 calibration_profile: :balanced
               )

      assert report.cost_model.profile == :balanced
    end
  end

  describe "runtime detection and scale branches" do
    test "runtime_available?/2 precedence and capabilities override branches" do
      assert Detection.runtime_available?(:unknown_profile,
               runtime_available?: true,
               capabilities: %{unknown_profile: false}
             )

      refute Detection.runtime_available?(:unknown_profile, capabilities: %{})
      assert Detection.runtime_available?(:unknown_profile, capabilities: %{unknown_profile: true})
    end

    test "default_profile_available?/1 supports env overrides and unknown profile fallback" do
      key = "NXQ_PROFILE_CPU_COMPILED_AVAILABLE"
      previous = System.get_env(key)

      on_exit(fn ->
        if previous == nil, do: System.delete_env(key), else: System.put_env(key, previous)
      end)

      System.put_env(key, "1")
      assert Detection.default_profile_available?(:cpu_compiled)

      System.put_env(key, "0")
      refute Detection.default_profile_available?(:cpu_compiled)

      assert Detection.default_profile_available?(:unknown_profile) == false
    end

    test "default_profile_available?/1 evaluates each built-in profile branch" do
      assert Detection.default_profile_available?(:cpu_portable) == true
      assert is_boolean(Detection.default_profile_available?(:cpu_compiled))
      assert is_boolean(Detection.default_profile_available?(:nvidia_gpu_compiled))
      assert is_boolean(Detection.default_profile_available?(:torch_interop_runtime))
    end

    test "runtime fallback allow_cpu_compiled branches for nvidia and non-nvidia profiles" do
      assert {:ok, %{id: :cpu_compiled}} =
               Fallback.resolve(%{id: :nvidia_gpu_compiled}, false, :allow_cpu_compiled)

      assert {:ok, %{id: :cpu_portable}} =
               Fallback.resolve(%{id: :cpu_portable}, false, :allow_cpu_compiled)
    end

    test "runtime scale invalid strategy branch returns typed error" do
      assert {:error, %{code: :invalid_scale_strategy, strategy: :invalid}} =
               Runtime.select_simulation_strategy(:invalid, 4)
    end

    test "runtime scale large_scale_preferred branch selects fallback above threshold" do
      assert {:ok, %{selected_path: :tensor_network_fallback}} =
               Runtime.select_simulation_strategy(:large_scale_preferred, 24, dense_threshold: 20)
    end
  end

  describe "transpiler topology/router branches" do
    test "topology helpers cover supported variants and explicit unknown topology error" do
      circuit =
        [qubits: 3]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 2)

      assert Topology.unsupported_edges(circuit, {:coupling_map, [{0, 1}, {1, 2}]}) == [{0, 2}]
      assert Topology.coupling_edges(:all_to_all) == []
      assert Topology.coupling_edges({:all_to_all, %{source: :test}}) == []
      assert Topology.coupling_edges({:heavy_hex, [{0, 1}]}) == [{0, 1}]
      assert Topology.coupling_edges({:coupling_map, [{1, 2}]}) == [{1, 2}]

      assert Topology.topology_id(:all_to_all) == :all_to_all
      assert Topology.topology_id({:all_to_all, %{}}) == :all_to_all
      assert Topology.topology_id({:heavy_hex, []}) == :heavy_hex
      assert Topology.topology_id({:coupling_map, []}) == :coupling_map

      assert Topology.supported_edge?({:coupling_map, [{0, 1}]}, {1, 0})
      refute Topology.supported_edge?({:coupling_map, [{0, 1}]}, {0, 2})
      assert Topology.supported_edge?({:heavy_hex, [{0, 1}]}, {1, 0})
      assert Topology.supported_edge?(:all_to_all, {10, 11})
      assert Topology.supported_edge?({:all_to_all, %{name: :metadata}}, {10, 12})

      assert_raise ArgumentError, ~r/unsupported topology/, fn ->
        Topology.supported_edge?({:unknown, []}, {0, 1})
      end
    end

    test "router shortest path and route violation error branches" do
      assert Router.shortest_path({2, 2}, [{0, 1}]) == [2]
      assert Router.shortest_path({0, 2}, [{0, 1}]) == nil

      assert {:error, {0, 3}} =
               Router.route_violations([{0, 3}], {:coupling_map, [{0, 1}, {1, 2}]})

      assert {:ok, [%{inserted_swaps: [{0, 1}], routed_edge: {1, 2}, path: [0, 1, 2]}]} =
               Router.route_violations([{0, 2}], {:coupling_map, [{0, 1}, {1, 2}]})
    end

    test "transpiler unsupported mode branch returns typed error" do
      circuit =
        [qubits: 3]
        |> Circuit.new()
        |> Gates.cnot(control: 0, target: 2)

      assert {:error, %{code: :unsupported_transpiler_mode, mode: :manual}} =
               Transpiler.run(circuit, topology: {:coupling_map, [{0, 1}, {1, 2}]}, mode: :manual)
    end

    test "transpiler insert-swaps with unroutable topology returns typed topology error" do
      circuit =
        [qubits: 4]
        |> Circuit.new()
        |> Gates.cnot(control: 0, target: 3)

      assert {:error, %{code: :topology_violation, edge: {0, 3}}} =
               Transpiler.run(circuit, topology: {:coupling_map, [{0, 1}, {1, 2}]}, mode: :insert_swaps)
    end
  end

  describe "mitigation pass pipeline unsupported pass branches" do
    test "pipeline halts on unsupported mitigation pass tuple shape" do
      assert {:ok, sample} = Sampler.run(Circuit.new(qubits: 1), shots: 16, seed: 5)

      assert {:error, %{code: :unsupported_mitigation_pass, pass: :custom}} =
               MitigationPassPipeline.run(sample, [{:custom, []}])

      assert {:error, %{code: :unsupported_mitigation_pass, pass: :invalid_shape}} =
               MitigationPassPipeline.run(sample, [:invalid_shape])
    end

    test "readout and zne passes cover invalid input branches deterministically" do
      estimator_result = %NxQuantum.Estimator.Result{values: Nx.tensor([1.0]), metadata: %{}}
      sampler_result = %NxQuantum.Sampler.Result{probabilities: Nx.tensor([0.5, 0.5]), counts: %{}, metadata: %{shots: 8}}

      assert {:error, %{code: :invalid_mitigation_input, reason: :readout_requires_sampler_result}} =
               Readout.apply(estimator_result, [])

      assert {:error, %{code: :invalid_mitigation_input, reason: :readout_requires_sampler_result}} =
               Readout.apply(:not_a_result, [])

      assert {:error, %{code: :invalid_mitigation_input, reason: :missing_calibration_matrix}} =
               Readout.apply(sampler_result, calibration: :missing)

      bad_sampler_result = %{sampler_result | probabilities: Nx.tensor([0.5])}

      assert {:error, %{code: :invalid_mitigation_input, reason: :non_invertible_calibration}} =
               Readout.apply(bad_sampler_result, calibration: Nx.tensor([[1.0, 0.0], [0.0, 1.0]]))

      assert {:error, %{code: :invalid_mitigation_input, reason: :invalid_scales}} =
               ZneLinear.apply(:not_a_result, scales: [1.0])

      assert {:ok, sampler_zne} = ZneLinear.apply(sampler_result, scales: [1.0, 2.0])
      assert sampler_zne.metadata.mitigation_trace == [%{pass: :zne_linear, scales: [1.0, 2.0]}]
    end
  end

  describe "circuit validation and sampler engine edge branches" do
    test "circuit bind/add_gate and validation errors are typed" do
      circuit = Circuit.new(qubits: 2)
      assert Circuit.bind(circuit, a: 1).bindings == %{a: 1}
      assert Circuit.bind(circuit, %{b: 2}).bindings == %{b: 2}

      assert_raise CircuitError, fn ->
        Circuit.bind(circuit, "invalid")
      end

      assert %Circuit{operations: [%GateOperation{name: :x}]} =
               Circuit.add_gate(circuit, GateOperation.new(:x, [1]))

      assert_raise CircuitError, fn ->
        Circuit.add_gate(circuit, GateOperation.new(:x, [2]))
      end
    end

    test "circuit expectation and validation utility branches are deterministic and typed" do
      assert Validation.validate_qubits!(1) == 1
      assert Validation.validate_wire!(0) == 0
      assert Validation.validate_wire_in_circuit!(1, 2) == 1
      assert Validation.validate_operation_wires_in_circuit!([0, 1], 2) == :ok
      assert Validation.validate_wire_pair!(0, 1) == {0, 1}
      assert Validation.fetch_wire_option!([wire: 0], :wire) == 0

      assert_raise CircuitError, fn ->
        Validation.validate_qubits!(0)
      end

      assert_raise CircuitError, fn ->
        Validation.validate_wire!(-1)
      end

      assert_raise CircuitError, fn ->
        Validation.validate_wire_in_circuit!(2, 2)
      end

      assert_raise CircuitError, fn ->
        Validation.validate_wire_pair!(0, 0)
      end

      assert_raise CircuitError, fn ->
        Validation.fetch_wire_option!([], :wire)
      end

      assert_raise CircuitError, fn ->
        Circuit.expectation(Circuit.new(qubits: 1), observable: :unsupported, wire: 0)
      end
    end

    test "sampler engine clamps probabilities at boundaries" do
      assert Engine.sample_counts(2.0, 10, 7) == {10, 0}
      assert Engine.sample_counts(-2.0, 10, 7) == {0, 10}
    end
  end
end
