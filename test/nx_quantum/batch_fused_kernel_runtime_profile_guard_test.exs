defmodule NxQuantum.BatchFusedKernelRuntimeProfileGuardTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Simulators.StateVector
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.FusedSingleWire
  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  test "fused kernel selection follows runtime profile" do
    assert FusedSingleWire.kernel_for_runtime(runtime_profile: :cpu_portable) == :portable
    assert FusedSingleWire.kernel_for_runtime(runtime_profile: :cpu_compiled) == :compiled
    assert FusedSingleWire.kernel_for_runtime(runtime_profile: %{id: :cpu_compiled}) == :compiled
  end

  test "compiled runtime applies portable cost-model fallback for large fused batch shape" do
    terms =
      Enum.map(0..47, fn index ->
        PauliExpval.term_for_observable(Enum.at([:pauli_x, :pauli_y, :pauli_z], rem(index, 3)), rem(index, 8))
      end)

    plan = PauliExpval.plan(terms, 8, parallel_observables: false)

    state =
      0
      |> Nx.tensor(type: {:c, 64})
      |> Nx.broadcast({256})
      |> Nx.put_slice([0], Nx.tensor([1.0], type: {:c, 64}))

    _ = FusedSingleWire.expectations_for_runtime(state, plan.terms, 8, runtime_profile: :cpu_compiled)
    resolution = Process.get(:nxq_fused_kernel_resolution)

    assert resolution.requested_kernel == :compiled
    assert resolution.selected_kernel == :portable
    assert resolution.reason == :portable_preferred_batch_shape_cost_model
  end

  test "compiled and portable fused kernels remain numerically equivalent" do
    terms = [
      PauliExpval.term_for_observable(:pauli_x, 0),
      PauliExpval.term_for_observable(:pauli_y, 1),
      PauliExpval.term_for_observable(:pauli_z, 0),
      PauliExpval.term_for_observable(:pauli_z, 1)
    ]

    plan = PauliExpval.plan(terms, 2, parallel_observables: false)
    state = Nx.tensor([0.5, 0.5, 0.5, -0.5], type: {:c, 64})

    portable =
      state
      |> FusedSingleWire.expectations_for_runtime(plan.terms, 2, runtime_profile: :cpu_portable)
      |> Enum.map(&Nx.to_number/1)

    compiled =
      state
      |> FusedSingleWire.expectations_for_runtime(plan.terms, 2, runtime_profile: :cpu_compiled)
      |> Enum.map(&Nx.to_number/1)

    portable
    |> Enum.zip(compiled)
    |> Enum.each(fn {a, b} ->
      assert_in_delta(a, b, 1.0e-9)
    end)
  end

  test "compiled fused kernel keeps compiled backend when state is on EXLA" do
    if Code.ensure_loaded?(EXLA.Backend) do
      terms = [
        PauliExpval.term_for_observable(:pauli_x, 0),
        PauliExpval.term_for_observable(:pauli_y, 1),
        PauliExpval.term_for_observable(:pauli_z, 0),
        PauliExpval.term_for_observable(:pauli_z, 1)
      ]

      plan = PauliExpval.plan(terms, 2, parallel_observables: false)
      state = Nx.tensor([0.5, 0.5, 0.5, -0.5], type: {:c, 64})
      exla_state = Nx.backend_transfer(state, {EXLA.Backend, client: :host})

      [compiled_first | _rest] =
        FusedSingleWire.expectations_for_runtime(state, plan.terms, 2, runtime_profile: :cpu_compiled)

      assert compiled_first.data.__struct__ in [EXLA.Backend, Nx.BinaryBackend]

      [compiled_exla_first | _rest] =
        FusedSingleWire.expectations_for_runtime(exla_state, plan.terms, 2, runtime_profile: :cpu_compiled)

      assert compiled_exla_first.data.__struct__ == EXLA.Backend
    else
      assert true
    end
  end

  test "runtime profile selection keeps fused results equivalent on adapter integration path" do
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

    portable =
      circuit
      |> StateVector.expectations(observables, runtime_profile: :cpu_portable)
      |> Nx.to_flat_list()

    compiled =
      circuit
      |> StateVector.expectations(observables, runtime_profile: :cpu_compiled)
      |> Nx.to_flat_list()

    portable
    |> Enum.zip(compiled)
    |> Enum.each(fn {a, b} ->
      assert_in_delta(a, b, 1.0e-8)
    end)
  end
end
