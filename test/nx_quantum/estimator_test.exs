defmodule NxQuantum.EstimatorTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Estimator.Result
  alias NxQuantum.Gates

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
end
