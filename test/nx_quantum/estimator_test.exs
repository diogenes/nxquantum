defmodule NxQuantum.EstimatorTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Simulators.StateVector
  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Estimator.Result
  alias NxQuantum.Estimator.StrategyObservability
  alias NxQuantum.Gates
  alias NxQuantum.Ports.Simulator

  describe "expectation_result/2" do
    test "returns typed error for unsupported runtime profile" do
      circuit = [qubits: 1] |> Circuit.new() |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})

      assert {:error, %{code: :unsupported_runtime_profile}} =
               Estimator.expectation_result(circuit, runtime_profile: :unknown_profile)
    end

    test "returns typed error for strict unavailable runtime" do
      circuit = [qubits: 1] |> Circuit.new() |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})

      assert {:error, %{code: :backend_unavailable}} =
               Estimator.expectation_result(circuit,
                 runtime_profile: :nvidia_gpu_compiled,
                 fallback_policy: :strict,
                 runtime_available?: false
               )
    end

    test "supports deterministic shot estimation with seed" do
      circuit = [qubits: 1] |> Circuit.new() |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})

      {:ok, a} = Estimator.expectation_result(circuit, shots: 128, seed: 123)
      {:ok, b} = Estimator.expectation_result(circuit, shots: 128, seed: 123)

      assert Nx.to_number(a) == Nx.to_number(b)
    end

    test "depolarizing noise shrinks absolute expectation magnitude" do
      circuit = [qubits: 1] |> Circuit.new() |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})

      {:ok, ideal} = Estimator.expectation_result(circuit)
      {:ok, noisy} = Estimator.expectation_result(circuit, noise: [depolarizing: 0.2])

      assert abs(Nx.to_number(noisy)) < abs(Nx.to_number(ideal))
    end

    test "amplitude damping biases expectation toward ground state" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.ry(0, theta: :math.pi())
        |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})

      {:ok, ideal} = Estimator.expectation_result(circuit)
      {:ok, noisy} = Estimator.expectation_result(circuit, noise: [amplitude_damping: 0.2])

      assert Nx.to_number(ideal) < -0.99
      assert Nx.to_number(noisy) > Nx.to_number(ideal)
    end
  end

  describe "run/2" do
    test "returns typed result for multi-observable batch" do
      circuit = Circuit.new(qubits: 1)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit, observables: [:pauli_x, :pauli_y, :pauli_z], wire: 0)

      assert Nx.shape(result.values) == {3}
      assert result.metadata.mode == :estimator
      assert length(result.metadata.observables) == 3
    end

    test "matches scalar expectations for each observable on deterministic batch path" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rx(0, theta: Nx.tensor(0.41))
        |> Gates.rz(0, theta: Nx.tensor(0.27))

      observables = [:pauli_x, :pauli_y, :pauli_z]

      assert {:ok, %Result{} = batch} = Estimator.run(circuit, observables: observables, wire: 0)

      scalar_values =
        Enum.map(observables, fn observable ->
          {:ok, tensor} = Estimator.expectation_result(circuit, observable: observable, wire: 0)
          Nx.to_number(tensor)
        end)

      assert Nx.to_flat_list(batch.values) == scalar_values
    end

    test "returns typed error for unsupported runtime profile in batch mode" do
      circuit = Circuit.new(qubits: 1)

      assert {:error, %{code: :unsupported_runtime_profile}} =
               Estimator.run(circuit, observables: [:pauli_x, :pauli_z], wire: 0, runtime_profile: :unknown_profile)
    end

    test "parallel observable evaluation preserves ordering and values" do
      circuit =
        [qubits: 3]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.ry(1, theta: Nx.tensor(0.31))
        |> Gates.rx(2, theta: Nx.tensor(0.23))

      observables = [:pauli_x, :pauli_y, :pauli_z, :pauli_x, :pauli_z, :pauli_y]

      assert {:ok, sequential} =
               Estimator.run(circuit,
                 observables: observables,
                 wire: 0,
                 parallel_observables: false
               )

      assert {:ok, parallel} =
               Estimator.run(circuit,
                 observables: observables,
                 wire: 0,
                 parallel_observables: true,
                 parallel_observables_threshold: 2,
                 max_concurrency: 4
               )

      assert Nx.to_flat_list(sequential.values) == Nx.to_flat_list(parallel.values)
      assert sequential.metadata.observables == parallel.metadata.observables
    end

    test "returns typed error for invalid observable" do
      circuit = Circuit.new(qubits: 1)

      assert {:error, %{code: :unsupported_observable, observable: :unsupported}} =
               Estimator.run(circuit, observables: [:unsupported], wire: 0)
    end

    test "returns typed error for invalid wire schema" do
      circuit = Circuit.new(qubits: 1)

      assert {:error, %{code: :invalid_measurement_wire}} =
               Estimator.run(circuit, observables: [:pauli_z], wire: -1)
    end

    test "runtime_profile auto prefers portable for fused-single-wire batch workloads" do
      circuit =
        [qubits: 4]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 1)
        |> Gates.cnot(control: 1, target: 2)
        |> Gates.cnot(control: 2, target: 3)

      cycle = [:pauli_x, :pauli_y, :pauli_z]

      observables =
        Enum.map(0..23, fn index ->
          Enum.at(cycle, rem(index, 3))
        end)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit,
                 observables: observables,
                 wire: 0,
                 runtime_profile: :auto,
                 capabilities: %{cpu_compiled: true, cpu_portable: true}
               )

      assert result.metadata.runtime_profile == :cpu_portable
      assert result.metadata.runtime_selection.requested_profile == :auto
      assert result.metadata.runtime_selection.selected_profile == :cpu_portable
      assert result.metadata.runtime_selection.reason == :portable_preferred_fused_single_wire_batch
      assert result.metadata.strategy_observability.requested_runtime_profile == :auto
      assert result.metadata.strategy_observability.resolved_runtime_profile == :cpu_portable
      assert result.metadata.strategy_observability.selection_reason == :portable_preferred_fused_single_wire_batch
      assert result.metadata.strategy_observability.runtime_lane == :portable
      assert result.metadata.strategy_observability.cache_mode == :enabled
      assert result.metadata.strategy_observability.cache_status in [:hit, :miss]
      assert :portable in result.metadata.strategy_observability.strategy_tags
    end

    test "runtime_profile auto prefers compiled for general deterministic workloads" do
      circuit = Circuit.new(qubits: 1)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit,
                 observables: [:pauli_z],
                 wire: 0,
                 runtime_profile: :auto,
                 capabilities: %{cpu_compiled: true, cpu_portable: true}
               )

      assert result.metadata.runtime_profile == :cpu_compiled
      assert result.metadata.runtime_selection.requested_profile == :auto
      assert result.metadata.runtime_selection.selected_profile == :cpu_compiled
      assert result.metadata.runtime_selection.reason == :compiled_preferred_general
      assert result.metadata.strategy_observability.resolved_runtime_profile == :cpu_compiled
      assert result.metadata.strategy_observability.runtime_lane == :compiled
      assert :compiled in result.metadata.strategy_observability.strategy_tags
    end

    test "compiled runtime uses portable fused kernel on batch cost-model shape with explicit reason" do
      circuit =
        [qubits: 8]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 1)
        |> Gates.cnot(control: 1, target: 2)
        |> Gates.cnot(control: 2, target: 3)
        |> Gates.cnot(control: 3, target: 4)
        |> Gates.cnot(control: 4, target: 5)
        |> Gates.cnot(control: 5, target: 6)
        |> Gates.cnot(control: 6, target: 7)

      observable_cycle = [:pauli_x, :pauli_y, :pauli_z]

      observables =
        Enum.map(0..47, fn index ->
          %{observable: Enum.at(observable_cycle, rem(index, 3)), wire: rem(index, 8)}
        end)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit,
                 observables: observables,
                 runtime_profile: :cpu_compiled
               )

      assert result.metadata.strategy_observability.fused_kernel_requested == :compiled
      assert result.metadata.strategy_observability.fused_kernel_selected == :portable
      assert result.metadata.strategy_observability.fused_kernel_reason == :portable_preferred_batch_shape_cost_model
      assert :portable in result.metadata.strategy_observability.strategy_tags
    end

    test "strategy observability marks cache bypass when evolved-state cache is disabled" do
      circuit = Circuit.new(qubits: 1)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit,
                 observables: [:pauli_z],
                 wire: 0,
                 cache_evolved_state: false
               )

      assert result.metadata.strategy_observability.cache_mode == :disabled
      assert result.metadata.strategy_observability.cache_status == :bypass
    end

    test "strategy observability emits hit-or-miss cache telemetry for repeated workloads" do
      circuit =
        [qubits: 2]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 1)
        |> Gates.ry(1, theta: Nx.tensor(0.424_242))

      opts = [observables: [:pauli_z], wire: 1, cache_evolved_state: true]

      assert {:ok, %Result{} = first} = Estimator.run(circuit, opts)
      assert {:ok, %Result{} = second} = Estimator.run(circuit, opts)

      assert first.metadata.strategy_observability.cache_status in [:hit, :miss]
      assert second.metadata.strategy_observability.cache_status in [:hit, :miss]
    end
  end

  describe "simulation metadata (KG-20)" do
    test "default backend on the real path reports real_pauli_z and the portable state backend" do
      circuit = real_path_circuit(0.271_828)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit, observables: [:pauli_z], wire: 1, cache_evolved_state: false)

      assert result.metadata.simulation == %{
               method: :state_vector,
               evolution_path: :real_pauli_z,
               state_backend: :portable,
               expectation_path: :generic
             }
    end

    test "a pauli_x observable takes the complex evolution path" do
      circuit = real_path_circuit(0.314_159)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit, observables: [:pauli_x], wire: 1, cache_evolved_state: false)

      assert result.metadata.simulation.evolution_path == :complex
      assert result.metadata.simulation.state_backend == :portable
    end

    test "a fused single-wire Pauli batch reports the fused expectation path" do
      circuit = fused_circuit(4)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit, observables: fused_observables(24, 4), cache_evolved_state: false)

      assert result.metadata.simulation == %{
               method: :state_vector,
               evolution_path: :complex,
               state_backend: :portable,
               expectation_path: :fused_single_wire
             }

      assert result.metadata.strategy_observability.fused_kernel_selected == :portable
    end

    test "23 single-wire Pauli terms are below the fused gate and take the generic path" do
      circuit = fused_circuit(4)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit, observables: fused_observables(23, 4), cache_evolved_state: false)

      assert result.metadata.simulation.expectation_path == :generic
      assert result.metadata.strategy_observability.fused_kernel_selected == :unknown
    end

    test "13 qubits is above the fused gate and takes the generic path" do
      circuit = fused_circuit(13)

      assert {:ok, %Result{} = result} =
               Estimator.run(circuit, observables: fused_observables(24, 13), cache_evolved_state: false)

      assert result.metadata.simulation.expectation_path == :generic
      assert result.metadata.strategy_observability.fused_kernel_selected == :unknown
    end

    test "a repeated run served from the evolved-state cache reports the state-vector method and no evolution path" do
      circuit = real_path_circuit(0.577_215)
      opts = [observables: [:pauli_z], wire: 1]

      assert {:ok, %Result{}} = Estimator.run(circuit, opts)
      assert {:ok, %Result{} = second} = Estimator.run(circuit, opts)

      assert second.metadata.strategy_observability.cache_status == :hit

      assert second.metadata.simulation == %{
               method: :state_vector,
               evolution_path: nil,
               state_backend: :portable,
               expectation_path: :generic
             }
    end

    test "a direct adapter call does not leak its simulation into the next Estimator.run" do
      direct_circuit = Map.put(real_path_circuit(0.141_592), :measurement, %{observable: :pauli_x, wire: 1})
      _ = StateVector.expectation(direct_circuit, runtime_profile: :cpu_portable, cache_evolved_state: false)

      assert {:ok, %Result{} = result} =
               Estimator.run(real_path_circuit(0.161_803), observables: [:pauli_z], wire: 1, cache_evolved_state: false)

      assert result.metadata.simulation == %{
               method: :state_vector,
               evolution_path: :real_pauli_z,
               state_backend: :portable,
               expectation_path: :generic
             }
    end

    test "a scalar expectation call does not leak its simulation into the next Estimator.run" do
      scalar_circuit = real_path_circuit(0.122_333)

      assert {:ok, _tensor} =
               Estimator.expectation_result(scalar_circuit, observable: :pauli_x, wire: 1, cache_evolved_state: false)

      assert {:ok, %Result{} = result} =
               Estimator.run(fused_circuit(4), observables: fused_observables(23, 4), cache_evolved_state: false)

      assert result.metadata.simulation.evolution_path == :complex
      assert result.metadata.simulation.expectation_path == :generic
    end

    test "simulation facts are returned, not written to the process dictionary" do
      assert {:ok, %Result{}} =
               Estimator.run(real_path_circuit(0.200_001), observables: [:pauli_z], wire: 1, cache_evolved_state: false)

      assert Process.get(:nxq_estimator_simulation) == nil
      assert Process.get(:nxq_estimator_cache_status) == nil
      assert Process.get(:nxq_fused_kernel_resolution) == nil
    end

    test "a run with no simulator facts reports nil fields" do
      opts = StrategyObservability.apply([], %{selected_profile: :cpu_portable}, [], executed?: false)

      assert Keyword.fetch!(opts, :estimator_simulation) == %{
               method: nil,
               evolution_path: nil,
               state_backend: nil,
               expectation_path: nil
             }
    end

    test "facts from several calls in one run are merged, and conflicts are reported as mixed" do
      complex_portable = facts(evolution_path: :complex, state_backend: :portable)
      real_compiled = facts(evolution_path: :real_pauli_z, state_backend: :compiled)

      merged = StrategyObservability.merge_facts([complex_portable, real_compiled])

      opts =
        StrategyObservability.apply([], %{selected_profile: :cpu_portable}, [], simulation: merged, executed?: true)

      assert Keyword.fetch!(opts, :estimator_simulation) == %{
               method: :state_vector,
               evolution_path: :mixed,
               state_backend: :mixed,
               expectation_path: :generic
             }
    end

    test "a run that only hit the cache reports no expectation path when not executed" do
      cached = facts(evolution_path: nil, state_backend: :portable, cache_status: :hit)

      opts =
        StrategyObservability.apply([], %{selected_profile: :cpu_portable}, [], simulation: cached, executed?: false)

      assert Keyword.fetch!(opts, :estimator_simulation) == %{
               method: :state_vector,
               evolution_path: nil,
               state_backend: :portable,
               expectation_path: nil
             }

      assert Keyword.fetch!(opts, :estimator_cache_status) == :hit
    end

    test "observable strategy is parallel only when enabled and at or above the threshold" do
      specs = [%{observable: :pauli_z, wire: 0}, %{observable: :pauli_x, wire: 1}]
      selection = %{selected_profile: :cpu_portable}

      parallel =
        StrategyObservability.apply([parallel_observables: true, parallel_observables_threshold: 2], selection, specs,
          executed?: false
        )

      below_threshold =
        StrategyObservability.apply([parallel_observables: true, parallel_observables_threshold: 3], selection, specs,
          executed?: false
        )

      disabled =
        StrategyObservability.apply([parallel_observables: false, parallel_observables_threshold: 2], selection, specs,
          executed?: false
        )

      assert Keyword.fetch!(parallel, :estimator_observable_strategy) == :parallel
      assert Keyword.fetch!(below_threshold, :estimator_observable_strategy) == :scalar
      assert Keyword.fetch!(disabled, :estimator_observable_strategy) == :scalar
    end

    test "runtime lane is compiled only for compiled profiles" do
      for profile <- [:cpu_compiled, :nvidia_gpu_compiled] do
        opts = StrategyObservability.apply([], %{selected_profile: profile}, [], executed?: false)
        assert Keyword.fetch!(opts, :estimator_runtime_lane) == :compiled
      end

      opts = StrategyObservability.apply([], %{selected_profile: :cpu_portable}, [], executed?: false)
      assert Keyword.fetch!(opts, :estimator_runtime_lane) == :portable
    end

    test "disabled state cache reports bypass and is reflected in the strategy tags" do
      opts =
        StrategyObservability.apply([cache_evolved_state: false], %{selected_profile: :cpu_portable}, [],
          simulation: facts(cache_status: :hit),
          executed?: true
        )

      assert Keyword.fetch!(opts, :estimator_cache_mode) == :disabled
      assert Keyword.fetch!(opts, :estimator_cache_status) == :bypass
      assert opts |> Keyword.fetch!(:estimator_strategy_tags) |> Enum.take(3) == [:scalar, :portable, :bypass]
    end

    test "merging no facts or a single call's facts keeps them unchanged" do
      assert StrategyObservability.merge_facts([]) == Simulator.unreported_facts()

      single = facts(evolution_path: :complex, state_backend: :portable)
      assert StrategyObservability.merge_facts([single]) == single
    end
  end

  defp facts(overrides) do
    Map.merge(
      Simulator.unreported_facts(),
      Map.merge(%{method: :state_vector, expectation_path: :generic}, Map.new(overrides))
    )
  end

  defp fused_circuit(qubits) do
    [qubits: qubits]
    |> Circuit.new()
    |> Gates.h(0)
    |> Gates.cnot(control: 0, target: 1)
    |> Gates.cnot(control: 1, target: 2)
  end

  defp fused_observables(count, wires) do
    Enum.map(0..(count - 1), fn index ->
      %{observable: Enum.at([:pauli_x, :pauli_y, :pauli_z], rem(index, 3)), wire: rem(index, wires)}
    end)
  end

  describe "batched_expectation/3" do
    test "returns deterministic batch values for fixed inputs" do
      builder = fn theta ->
        [qubits: 1]
        |> Circuit.new()
        |> Gates.ry(0, theta: theta)
      end

      batch = Nx.tensor([0.0, 1.0, 2.0])

      assert {:ok, a} = Estimator.batched_expectation(builder, batch, observable: :pauli_z, wire: 0)
      assert {:ok, b} = Estimator.batched_expectation(builder, batch, observable: :pauli_z, wire: 0)
      assert Nx.to_flat_list(a) == Nx.to_flat_list(b)
      assert Nx.shape(a) == {3}
    end

    test "returns typed error for invalid batch shape" do
      builder = fn theta -> [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: theta) end

      assert {:error, %{code: :invalid_batch_shape, received: {2, 2}}} =
               Estimator.batched_expectation(builder, Nx.tensor([[0.1, 0.2], [0.3, 0.4]]),
                 observable: :pauli_z,
                 wire: 0
               )
    end

    test "parallel batch execution preserves deterministic values and ordering" do
      builder = fn theta ->
        [qubits: 1]
        |> Circuit.new()
        |> Gates.ry(0, theta: theta)
      end

      batch = Nx.tensor([0.0, 0.3, 0.7, 1.1, 1.5, 1.9, 2.2, 2.6], type: {:f, 32})

      assert {:ok, sequential} =
               Estimator.batched_expectation(builder, batch,
                 observable: :pauli_z,
                 wire: 0
               )

      assert {:ok, parallel} =
               Estimator.batched_expectation(builder, batch,
                 observable: :pauli_z,
                 wire: 0,
                 parallel: true,
                 max_concurrency: 4
               )

      assert Nx.to_flat_list(sequential) == Nx.to_flat_list(parallel)
    end
  end

  defp real_path_circuit(theta) do
    [qubits: 2]
    |> Circuit.new()
    |> Gates.h(0)
    |> Gates.cnot(control: 0, target: 1)
    |> Gates.ry(1, theta: Nx.tensor(theta))
  end
end
