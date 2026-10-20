defmodule NxQuantum.DomainCoverageWave2Test do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias NxQuantum.Circuit
  alias NxQuantum.Compiler
  alias NxQuantum.Compiler.Passes.Cancel
  alias NxQuantum.Compiler.Passes.Fuse
  alias NxQuantum.Compiler.Passes.Resynthesize1Q
  alias NxQuantum.DynamicIR
  alias NxQuantum.DynamicIR.Executor.SubsetV04
  alias NxQuantum.DynamicIR.Validator
  alias NxQuantum.Estimator
  alias NxQuantum.Estimator.Batch
  alias NxQuantum.Estimator.Batch.Strategies.Deterministic
  alias NxQuantum.Estimator.Batch.Strategies.ScalarFallback
  alias NxQuantum.Estimator.ObservableSpecs
  alias NxQuantum.Estimator.Result, as: EstimatorResult
  alias NxQuantum.Estimator.ResultBuilder
  alias NxQuantum.Estimator.RuntimeAutoSelector
  alias NxQuantum.Estimator.RuntimeProfile
  alias NxQuantum.Estimator.SampledExpval
  alias NxQuantum.Estimator.SampledExpval.CountsReducer
  alias NxQuantum.Estimator.SampledExpval.ExecutionStrategy
  alias NxQuantum.Estimator.SampledExpval.MaskLookupCache
  alias NxQuantum.Estimator.SampledExpval.ParsedCounts
  alias NxQuantum.Estimator.Stochastic
  alias NxQuantum.Estimator.StrategyObservability
  alias NxQuantum.Gates
  alias NxQuantum.Grad
  alias NxQuantum.Grad.Error, as: GradError
  alias NxQuantum.Kernels
  alias NxQuantum.Mitigation.CalibrationPayload
  alias NxQuantum.Mitigation.Passes.ZneLinear
  alias NxQuantum.Observables.Schema
  alias NxQuantum.Observables.SparsePauli
  alias NxQuantum.Runtime
  alias NxQuantum.Runtime.Detection
  alias NxQuantum.Runtime.Scale
  alias NxQuantum.Sampler
  alias NxQuantum.Sampler.Batch.Strategies.Parallel
  alias NxQuantum.Transpiler

  defmodule FakeExlaBackend do
    @moduledoc false
  end

  defmodule FakeExlaClient do
    @moduledoc false
    def get_supported_platforms do
      case Process.get(:nxq_fake_exla_platforms, %{host: :ok, cuda: :ok}) do
        :raise -> raise "boom"
        :exit -> exit(:boom)
        :throw -> throw(:boom)
        value -> value
      end
    end

    def fetch!(_client) do
      case Process.get(:nxq_fake_exla_fetch_mode, {:ok, :client}) do
        :raise -> raise "boom"
        :exit -> exit(:boom)
        :throw -> throw(:boom)
        :ok -> :ok
        :map -> %{}
        :other -> :invalid
        value -> value
      end
    end
  end

  defmodule FakeSparsePauli do
    @moduledoc false
    def single_pauli_term(_observable, _wire, _coeff), do: {:error, %{code: :fake_sparse_pauli_failure}}
  end

  test "covers circuit/gates/runtime wrapper branches and defaults" do
    assert %Circuit{qubits: 1} = Circuit.new()
    assert_raise KeyError, fn -> Circuit.expectation(Circuit.new()) end

    circuit =
      [qubits: 2]
      |> Circuit.new()
      |> Gates.y(0)
      |> Gates.z(1)

    assert length(circuit.operations) == 2

    assert is_list(Runtime.capabilities())
    assert is_list(Runtime.available_profile_ids())

    assert {:ok, _} = Scale.select(:auto, 1)
  end

  test "runtime detection covers env override and EXLA client safety branches" do
    previous = Application.get_env(:nx_quantum, Detection)

    Application.put_env(:nx_quantum, Detection,
      exla_backend_module: FakeExlaBackend,
      exla_client_module: FakeExlaClient
    )

    on_exit(fn ->
      if previous == nil do
        Application.delete_env(:nx_quantum, Detection)
      else
        Application.put_env(:nx_quantum, Detection, previous)
      end
    end)

    key = "NXQ_PROFILE_CPU_COMPILED_AVAILABLE"
    prev = System.get_env(key)

    on_exit(fn ->
      if prev, do: System.put_env(key, prev), else: System.delete_env(key)
    end)

    System.put_env(key, "true")
    assert Detection.default_profile_available?(:cpu_compiled)
    System.put_env(key, "false")
    refute Detection.default_profile_available?(:cpu_compiled)
    System.delete_env(key)
    assert Detection.runtime_available?(:cpu_compiled, runtime_available?: true) == true
    assert Detection.runtime_available?(:cpu_compiled, runtime_available?: false) == false

    refute Detection.runtime_available?(:cpu_compiled, capabilities: %{cpu_compiled: false})
    assert Detection.runtime_available?(:cpu_compiled, capabilities: %{cpu_compiled: true})

    Process.put(:nxq_fake_exla_platforms, %{host: :ok, cuda: :ok})
    Process.put(:nxq_fake_exla_fetch_mode, {:ok, :client})
    assert Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_fetch_mode, :ok)
    assert Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_fetch_mode, :map)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_fetch_mode, :other)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_platforms, :raise)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_platforms, :exit)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_platforms, :throw)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_platforms, %{host: :ok})
    Process.put(:nxq_fake_exla_fetch_mode, :raise)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_fetch_mode, :exit)
    refute Detection.default_profile_available?(:cpu_compiled)

    Process.put(:nxq_fake_exla_fetch_mode, :throw)
    refute Detection.default_profile_available?(:cpu_compiled)
  end

  test "covers dynamic ir unsupported mode and validator shape failures" do
    assert {:error, %{code: :unsupported_dynamic_execution_mode}} =
             DynamicIR.execute(%{nodes: [], registers: MapSet.new()}, mode: :invalid)

    assert {:error, %{reason: :invalid_ir_shape}} = DynamicIR.validate(:invalid)
    assert {:error, %{reason: :invalid_node_shape}} = DynamicIR.validate(%{nodes: [:bad], registers: MapSet.new()})

    ir = %{nodes: [%{}], registers: MapSet.new()}
    assert {:error, %{reason: :invalid_node_shape}} = Validator.validate(ir)
    assert {:error, %{reason: :invalid_ir_shape}} = SubsetV04.execute(:invalid)
  end

  test "covers estimator wrappers and explicit scalar-fallback batch path" do
    assert is_tuple(Compiler.optimize(Circuit.new(qubits: 1)))
    assert match?(%Nx.Tensor{}, Estimator.expectation(Circuit.new(qubits: 1)))
    assert {:ok, _} = Estimator.run(Circuit.new(qubits: 1))
    assert {:ok, _} = Estimator.sampled_expectation_from_counts(%{"0" => 1})

    assert_raise ArgumentError, fn ->
      Estimator.expectation(Circuit.new(qubits: 1), runtime_profile: :unknown_profile)
    end

    assert {:error, %{code: :invalid_counts_payload}} = SampledExpval.from_counts(:bad, [])
    assert {:error, %{code: :invalid_observables_option}} = SampledExpval.from_counts(%{"0" => 1}, observables: :bad)

    assert {:error, %{code: :invalid_batch_shape}} =
             Estimator.batched_expectation(fn _ -> Circuit.new(qubits: 1) end, Nx.tensor([[1.0]]))

    assert {:error, %{code: :unsupported_runtime_profile}} =
             Estimator.batched_expectation(
               fn _ -> Circuit.new(qubits: 1) end,
               Nx.tensor([0.1, 0.2]),
               runtime_profile: :unknown_profile
             )

    circuit = Circuit.new(qubits: 1)
    observable_specs = [%{observable: :pauli_z, wire: 0}]
    assert {:ok, _} = Batch.run(circuit, observable_specs, shots: 16, seed: 1)

    assert_raise RuntimeError, ~r/cannot build empty tensor/, fn ->
      Deterministic.run(circuit, [], runtime_profile: :cpu_portable)
    end

    assert {:ok, _} = ScalarFallback.run(circuit, observable_specs, shots: 16, seed: 2)
    assert {:error, %{code: :unsupported_observable}} = ScalarFallback.run(circuit, [%{observable: :bad, wire: 0}], [])

    assert {:ok, _} = RuntimeProfile.resolve_with_context(runtime_profile: :cpu_portable)

    assert {:ok, _} = SampledExpval.from_counts(%{"0" => 1}, runtime_profile: %{id: :cpu_portable})
    assert {:ok, _} = SampledExpval.from_counts(%{"0" => 1}, runtime_profile: "bad")

    counts30 = %{String.duplicate("0", 30) => 1}

    observables30 =
      Enum.map(0..29, fn wire ->
        %{observable: :pauli_z, wire: wire}
      end)

    assert {:ok, _} =
             SampledExpval.from_counts(counts30,
               observables: observables30,
               runtime_profile: :auto,
               capabilities: %{cpu_compiled: false},
               sampled_parallel_min_work: 1
             )

    assert {:ok, _} =
             SampledExpval.from_counts(counts30,
               observables: observables30,
               runtime_profile: :auto,
               capabilities: %{cpu_compiled: true},
               sampled_parallel_min_work: 1
             )
  end

  test "covers estimator option normalization and metadata branches" do
    assert {:error, %{code: :invalid_observables_option}} = ObservableSpecs.normalize(observables: :bad)
    assert {:error, %{code: :unsupported_observable}} = ObservableSpecs.normalize(observables: [123])

    result = ResultBuilder.build(Nx.tensor([1.0]), [], runtime_profile: %{id: :cpu_compiled})
    assert result.metadata.strategy_observability.runtime_lane == :compiled

    result2 = ResultBuilder.build(Nx.tensor([1.0]), [], runtime_profile: "bad")
    assert result2.metadata.runtime_profile == :cpu_portable

    assert {:ok, %{id: :cpu_portable}} = RuntimeProfile.resolve(runtime_profile: %{id: :cpu_portable})

    obs_opts =
      StrategyObservability.apply(
        [estimator_cache_status: :hit],
        %{selected_profile: :cpu_portable},
        [%{observable: :pauli_z, wire: 0}],
        executed?: false
      )

    assert obs_opts[:estimator_cache_status] == :hit
  end

  test "covers auto-selector sampled/batch/general fallback branches" do
    assert RuntimeAutoSelector.choose(capabilities: %{cpu_compiled: true}).reason == :compiled_preferred_general

    assert RuntimeAutoSelector.choose([capabilities: %{cpu_compiled: false}],
             kind: :sampled,
             sampled_unit_count: 128,
             sampled_entry_count: 8192,
             sampled_parallel_mode: :force_parallel
           ).reason ==
             :portable_fallback_compiled_unavailable

    assert RuntimeAutoSelector.choose([capabilities: %{cpu_compiled: true}],
             kind: :batch,
             qubits: 20,
             observable_specs: [%{observable: :pauli_z, wire: 0}]
           ).reason ==
             :compiled_preferred_general

    assert RuntimeAutoSelector.choose([capabilities: %{cpu_compiled: true}],
             kind: :batch,
             qubits: 8,
             observable_specs: [%{observable: :invalid, wire: 0}]
           ).reason ==
             :compiled_preferred_general

    invalid_specs =
      for idx <- 0..23 do
        if idx == 23, do: %{bad: :shape}, else: %{observable: :pauli_z, wire: 0}
      end

    assert RuntimeAutoSelector.choose([capabilities: %{cpu_compiled: false}],
             kind: :batch,
             qubits: 4,
             observable_specs: invalid_specs
           ).reason == :portable_fallback_compiled_unavailable
  end

  test "covers sampled-expval edge branches and reducer strategy variants" do
    counts = %{"0" => 5, "1" => 5}
    {:ok, sp} = SparsePauli.new(2, [%{x_mask: 0, z_mask: 1, coeff: 1.0}])
    assert {:error, %{code: :sparse_pauli_qubit_mismatch}} = SampledExpval.from_counts(counts, sparse_pauli: sp)
    assert {:error, %{code: :invalid_sparse_pauli_option}} = SampledExpval.from_counts(counts, sparse_pauli: :bad)

    {:ok, sp_complex} = SparsePauli.new(1, [%{x_mask: 0, z_mask: 1, coeff: {1.0, 0.5}}])

    assert {:error, %{code: :unsupported_sampled_complex_coefficient}} =
             SampledExpval.from_counts(counts, sparse_pauli: sp_complex)

    assert {:ok, _} =
             SampledExpval.from_counts(counts,
               observable: :pauli_z,
               wire: 0,
               runtime_profile: :auto,
               sampled_parallel_mode: :force_parallel,
               capabilities: %{cpu_compiled: true}
             )

    prev_sampled_env = Application.get_env(:nx_quantum, SampledExpval)

    Application.put_env(:nx_quantum, SampledExpval, sparse_pauli_module: FakeSparsePauli)

    on_exit(fn ->
      if prev_sampled_env == nil do
        Application.delete_env(:nx_quantum, SampledExpval)
      else
        Application.put_env(:nx_quantum, SampledExpval, prev_sampled_env)
      end
    end)

    assert {:error, %{code: :fake_sparse_pauli_failure}} =
             SampledExpval.from_counts(counts, observables: [%{observable: :pauli_z, wire: 0}])

    {:ok, parsed} = ParsedCounts.parse(%{"00" => 1, "01" => 1}, cache_parsed_counts: false)
    assert CountsReducer.lookup(parsed, [1]) == %{1 => 0.0}
    assert CountsReducer.lookup(parsed, [], []) == %{}
    assert match?(%{mode: :scalar}, ExecutionStrategy.select(1, []))
    assert match?(%{mode: :scalar}, ExecutionStrategy.select(4, 1, sampled_parallel_mode: :force_scalar))
    assert match?(%{mode: :parallel}, ExecutionStrategy.select(4, 1, sampled_parallel_mode: :force_parallel))
    assert match?(%{mode: :scalar}, ExecutionStrategy.select(4, 1, sampled_parallel_mode: :unsupported))
    assert match?(%{mode: :scalar}, ExecutionStrategy.select(4, 1, max_concurrency: 0))

    terms = [%{x_mask: 0, z_mask: 1, coeff: {1.0, 0.0}}]
    assert MaskLookupCache.for_terms(terms, cache_mask_lookup_plan: false).ordered_masks == [1]
    assert MaskLookupCache.for_terms(terms).ordered_masks == [1]

    for idx <- 0..520 do
      MaskLookupCache.for_terms([%{x_mask: 0, z_mask: idx + 1, coeff: {1.0, 0.0}}])
    end

    assert ParsedCounts.parse(%{"0" => 1}) == ParsedCounts.parse(%{"0" => 1})

    for idx <- 1..521 do
      bits = Integer.to_string(idx, 2)
      _ = ParsedCounts.parse(%{bits => 1})
    end

    assert CountsReducer.lookup(parsed, [0, 1],
             sampled_parallel_mode: :force_parallel,
             sampled_reducer_backend: :elixir,
             max_concurrency: 2
           ) == %{0 => 1.0, 1 => 0.0}

    assert_raise RuntimeError, ~r/parallel sampled expectation lookup failed/, fn ->
      CountsReducer.unwrap_parallel_chunk_result({:exit, :boom})
    end

    table_name_counts = :nxq_counts_table_test
    :ets.new(table_name_counts, [:named_table, :set, :public])
    assert ParsedCounts.safe_new_named_table(table_name_counts, [:named_table, :set, :public]) == table_name_counts
    assert ParsedCounts.normalize_table_size(:undefined) == 0
    :ets.delete(table_name_counts)

    table_name_mask = :nxq_mask_table_test
    :ets.new(table_name_mask, [:named_table, :set, :public])
    assert MaskLookupCache.safe_new_named_table(table_name_mask, [:named_table, :set, :public]) == table_name_mask
    assert MaskLookupCache.normalize_table_size(:undefined) == 0
    :ets.delete(table_name_mask)
  end

  test "covers parsed-counts validation branches and sparse-pauli edge constructors" do
    assert {:error, %{code: :invalid_counts_payload}} = ParsedCounts.parse(:bad)
    assert {:error, %{code: :invalid_count_bitstring}} = ParsedCounts.parse(%{1 => 1})
    assert {:error, %{code: :invalid_count_value}} = ParsedCounts.parse(%{"0" => -1})
    assert {:error, %{code: :invalid_count_bitstring}} = ParsedCounts.parse(%{"ab" => 1})
    assert {:error, %{code: :invalid_counts_payload}} = ParsedCounts.parse(%{})
    assert {:error, %{code: :invalid_counts_total_shots}} = ParsedCounts.parse(%{"0" => 0, "1" => 0})

    assert {:ok, _} = SparsePauli.single_pauli_term(:pauli_z, 0)
    assert {:ok, _} = SparsePauli.single_pauli_term(:pauli_y, 0, 1.0)
    assert {:error, %{code: :unsupported_observable}} = SparsePauli.single_pauli_term(:bad, 0, 1.0)
    assert {:error, %{code: :invalid_qubit_count}} = SparsePauli.new(0, [%{x_mask: 0, z_mask: 1, coeff: 1.0}])
    assert {:error, %{code: :invalid_sparse_pauli_term}} = SparsePauli.new(1, [%{bad: :shape}])

    assert {:error, %{code: :invalid_sparse_pauli_coefficient}} =
             SparsePauli.new(1, [%{x_mask: 0, z_mask: 1, coeff: :bad}])

    assert {:error, %{code: :sparse_pauli_mask_out_of_range}} = SparsePauli.new(1, [%{x_mask: 2, z_mask: 0, coeff: 1.0}])

    assert {:ok, _} = SparsePauli.new(1, [%{x_mask: 0, z_mask: 1, coeff: Nx.tensor(1.0)}])

    {:ok, sp} = SparsePauli.new(1, [%{x_mask: 0, z_mask: 1, coeff: 1.0}, %{x_mask: 1, z_mask: 0, coeff: 1.0}])
    assert length(SparsePauli.diagonal_terms(sp)) == 1

    assert {:ok, %SparsePauli{terms: []}} =
             SparsePauli.new(1, [%{x_mask: 0, z_mask: 1, coeff: 1.0}, %{x_mask: 0, z_mask: 1, coeff: -1.0}])

    assert {:error, %{code: :unsupported_observable}} =
             SparsePauli.from_observable_specs(1, [%{observable: :bad, wire: 0}])

    assert Nx.shape(SparsePauli.to_dense(%SparsePauli{qubits: 1, terms: []})) == {2, 2}

    assert_raise RuntimeError, ~r/parallel sparse-pauli generation failed/, fn ->
      SparsePauli.unwrap_parallel_term_entries_result({:exit, :boom})
    end

    assert Nx.shape(
             SparsePauli.to_dense(%SparsePauli{qubits: 1, terms: [%{x_mask: 0, z_mask: 1, coeff: {1.0, 0.0}}]},
               parallel_threshold: 1,
               max_concurrency: 0
             )
           ) == {2, 2}
  end

  test "covers stochastic clamp and sampler/transpiler/compiler pass edge branches" do
    assert Stochastic.apply_noise(2.0, noise: [depolarizing: 0.0, amplitude_damping: 0.0]) == 1.0
    assert Stochastic.apply_noise(-2.0, noise: [depolarizing: 0.0, amplitude_damping: 0.0]) == -1.0
    assert Stochastic.maybe_sample(0.2, shots: "invalid") == 0.2

    assert Parallel.run([1, 2], [max_concurrency: 1], fn value -> value * 2 end) == [2, 4]
    old_flag = Process.flag(:trap_exit, true)

    capture_log(fn ->
      assert {:error, %{code: :batch_parallel_worker_crash}} =
               hd(Parallel.run([1], [max_concurrency: 1], fn _ -> exit(:boom) end))
    end)

    Process.flag(:trap_exit, old_flag)

    assert {:error, %{code: :unsupported_runtime_profile}} =
             Sampler.batched_run(fn _ -> Circuit.new(qubits: 1) end, Nx.tensor([0.1]), runtime_profile: :unknown_profile)

    assert {:ok, _} = Sampler.run(Circuit.new(qubits: 1))
    assert {:ok, [_]} = Sampler.batched_run(fn _ -> Circuit.new(qubits: 1) end, Nx.tensor([0.2]))

    assert {:ok, _, _} = Transpiler.run(Circuit.new(qubits: 1))
    assert {:ok, _} = Compiler.compile(Circuit.new(qubits: 1))
    assert Cancel.run([]) == []
    assert Fuse.run([]) == []
    assert is_list(Resynthesize1Q.run([]))
    assert is_list(Resynthesize1Q.run([NxQuantum.GateOperation.new(:x, [0]), NxQuantum.GateOperation.new(:x, [0])]))
  end

  test "covers grad unsupported mode and adjoint error/detail branches plus kernels defaults" do
    {_v_bp, g_bp} = Grad.value_and_grad(fn x -> Nx.multiply(x, x) end, Nx.tensor(0.2))
    assert Nx.shape(g_bp) == {}

    assert_raise ArgumentError, ~r/unsupported gradient mode/, fn ->
      Grad.value_and_grad(fn x -> x end, Nx.tensor(1.0), mode: :bad)
    end

    assert_raise GradError, fn ->
      Grad.value_and_grad(fn x -> x end, Nx.tensor(1.0), mode: :adjoint, circuit_builder: fn _ -> :bad end)
    end

    assert_raise GradError, fn ->
      Grad.value_and_grad(
        fn p -> Nx.sum(p) end,
        Nx.tensor([1.0]),
        mode: :adjoint,
        circuit_builder: fn _ ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.rx(0, theta: 0.1)
          |> Gates.ry(0, theta: 0.2)
          |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
        end
      )
    end

    assert_raise GradError, fn ->
      Grad.value_and_grad(
        fn _p ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.h(0)
          |> Circuit.expectation(observable: :pauli_z, wire: 0)
        end,
        Nx.tensor(0.0),
        mode: :adjoint,
        circuit_builder: fn _ ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.h(0)
          |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
        end
      )
    end

    assert_raise GradError, fn ->
      Grad.value_and_grad(
        fn p ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: p)
          |> Circuit.expectation(observable: :pauli_z, wire: 0)
        end,
        Nx.tensor(0.2),
        mode: :adjoint,
        circuit_builder: fn t ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: t)
        end
      )
    end

    {val_x, grad_x} =
      Grad.value_and_grad(
        fn p ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: p)
          |> Circuit.expectation(observable: :pauli_x, wire: 0)
        end,
        Nx.tensor(0.2),
        mode: :adjoint,
        circuit_builder: fn t ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: t)
          |> Map.put(:measurement, %{observable: :pauli_x, wire: 0})
        end
      )

    assert is_number(Nx.to_number(val_x))
    assert Nx.shape(grad_x) == {}

    assert_raise GradError, fn ->
      Grad.value_and_grad(
        fn p ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: p)
          |> Circuit.expectation(observable: :pauli_z, wire: 0)
        end,
        Nx.tensor(0.2),
        mode: :adjoint,
        circuit_builder: fn t ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: t)
          |> Map.put(:measurement, %{observable: :unsupported, wire: 0})
        end
      )
    end

    objective = fn params ->
      [a, b, c] = Nx.to_flat_list(params)

      [qubits: 2]
      |> Circuit.new()
      |> Gates.h(0)
      |> Gates.x(1)
      |> Gates.y(0)
      |> Gates.z(1)
      |> Gates.rx(0, theta: a)
      |> Gates.ry(1, theta: b)
      |> Gates.rz(0, theta: c)
      |> Gates.cnot(control: 0, target: 1)
      |> Circuit.expectation(observable: :pauli_y, wire: 1)
    end

    {_value, grad} =
      Grad.value_and_grad(
        objective,
        Nx.tensor([0.1, 0.2, 0.3]),
        mode: :adjoint,
        circuit_builder: fn params ->
          [a, b, c] = Nx.to_flat_list(params)

          [qubits: 2]
          |> Circuit.new()
          |> Gates.h(0)
          |> Gates.x(1)
          |> Gates.y(0)
          |> Gates.z(1)
          |> Gates.rx(0, theta: a)
          |> Gates.ry(1, theta: b)
          |> Gates.rz(0, theta: c)
          |> Gates.cnot(control: 0, target: 1)
          |> Map.put(:measurement, %{observable: :pauli_y, wire: 1})
        end
      )

    assert Nx.shape(grad) == {3}

    assert Nx.shape(Kernels.matrix(Nx.tensor([[1.0, 2.0], [3.0, 4.0]]))) == {2, 2}
  end

  test "covers mitigation/observable schema misc branches" do
    assert {:error, %{code: :invalid_mitigation_input}} =
             ZneLinear.apply(%EstimatorResult{values: Nx.tensor([1.0]), metadata: %{}}, scales: :bad)

    assert {:error, %{code: :invalid_calibration_payload}} = CalibrationPayload.validate(%{matrix: Nx.tensor([1.0, 0.0])})
    assert {:error, %{code: :invalid_calibration_payload}} = CalibrationPayload.validate(%{source: "s"})
    assert {:error, %{code: :invalid_mitigation_input}} = ZneLinear.apply(%{}, scales: :bad)

    assert Schema.measurement!(:pauli_z, 0, 1) == %{observable: :pauli_z, wire: 0}
  end
end
