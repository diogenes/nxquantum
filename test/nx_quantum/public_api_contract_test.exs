defmodule NxQuantum.PublicApiContractTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.DynamicIR
  alias NxQuantum.Estimator
  alias NxQuantum.Gates
  alias NxQuantum.Kernels
  alias NxQuantum.Mitigation
  alias NxQuantum.Performance
  alias NxQuantum.Runtime
  alias NxQuantum.Sampler
  alias NxQuantum.Transpiler

  describe "stable facade exports" do
    test "core modules expose v0.2 stable contract functions" do
      assert_exported(Circuit, :new, 1)
      assert_exported(Circuit, :bind, 2)
      assert_exported(Circuit, :expectation, 2)

      assert_exported(Gates, :h, 2)
      assert_exported(Gates, :rx, 3)
      assert_exported(Gates, :ry, 3)
      assert_exported(Gates, :rz, 3)
      assert_exported(Gates, :cnot, 2)

      assert_exported(Runtime, :supported_profiles, 0)
      assert_exported(Runtime, :profile!, 1)
      assert_exported(Runtime, :resolve, 2)
      assert_exported(Runtime, :capabilities, 1)
      assert_exported(Runtime, :select_simulation_strategy, 3)

      assert_exported(Estimator, :expectation, 2)
      assert_exported(Estimator, :expectation_result, 2)
      assert_exported(Estimator, :run, 2)

      assert_exported(Sampler, :run, 2)
    end
  end

  describe "experimental facade exports" do
    test "advanced modules expose explicit entrypoints" do
      assert_exported(NxQuantum.Grad, :value_and_grad, 2)
      assert_exported(NxQuantum.Compiler, :optimize, 1)
      assert_exported(Kernels, :matrix, 1)
      assert_exported(Estimator, :batched_expectation, 3)
      assert_exported(Estimator, :sampled_expectation_from_counts, 2)
      assert_exported(Sampler, :batched_run, 3)
      assert_exported(Mitigation, :pipeline, 2)
      assert_exported(Transpiler, :run, 2)
      assert_exported(DynamicIR, :validate, 1)
      assert_exported(DynamicIR, :execute, 2)
      assert_exported(Performance, :compare_batched_workflows, 3)
      assert_exported(Performance, :benchmark_matrix, 2)
      assert_exported(Performance, :evaluate_gates, 2)
      assert_exported(Circuit, :to_qasm, 2)
    end
  end

  test "stable expectation_result return contract is typed tuple" do
    circuit = Circuit.new(qubits: 1)

    assert {:ok, %Nx.Tensor{}} =
             Estimator.expectation_result(circuit, observable: :pauli_z, wire: 0)
  end

  test "runtime resolve return contract is deterministic typed tuple" do
    assert {:ok, %{id: :cpu_portable}} = Runtime.resolve(:cpu_portable, runtime_available?: true)

    assert {:error, %{code: :unsupported_runtime_profile}} =
             Runtime.resolve(:unknown_profile, runtime_available?: false)
  end

  defp assert_exported(module, function, arity) do
    assert Code.ensure_loaded?(module)
    assert {function, arity} in module.__info__(:functions)
  end
end
