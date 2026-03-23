defmodule NxQuantum.Property.ProviderScenarioInvariantsPropertyTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias NxQuantum.Circuit
  alias NxQuantum.Gates
  alias NxQuantum.Performance
  alias NxQuantum.ProviderBridge.CapabilityContract
  alias NxQuantum.Providers.Capabilities
  alias NxQuantum.Runtime

  property "dynamic capability preflight is deterministic for identical inputs" do
    check all(supports_dynamic <- boolean(), supports_calibration_payload <- boolean(), max_runs: 25) do
      capability = %CapabilityContract{
        supports_estimator: true,
        supports_sampler: true,
        supports_batch: true,
        supports_dynamic: supports_dynamic,
        supports_cancel_in_running: true,
        supports_calibration_payload: supports_calibration_payload,
        target_class: :gate_model
      }

      request = %{workflow: :sampler, dynamic: true}

      first = Capabilities.preflight(capability, request, :scenario_provider, "target-1")
      second = Capabilities.preflight(capability, request, :scenario_provider, "target-1")

      assert first == second

      if supports_dynamic do
        assert first == :ok
      else
        assert {:error, %{code: :provider_capability_mismatch, capability: :supports_dynamic}} = first
      end
    end
  end

  property "runtime fallback selection is reproducible for identical inputs" do
    check all(qubit_count <- integer(21..40), max_runs: 25) do
      first = Runtime.select_simulation_strategy(:auto, qubit_count, dense_threshold: 20)
      second = Runtime.select_simulation_strategy(:auto, qubit_count, dense_threshold: 20)

      assert first == second
      assert {:ok, %{selected_path: selected_path, report: report}} = first
      assert report.qubit_count == qubit_count

      if qubit_count > 20 do
        assert selected_path == :tensor_network_fallback
      else
        assert selected_path == :dense_state_vector
      end
    end
  end

  property "batched expectation remains scalar-equivalent and deterministically ordered" do
    check all(
            batch_size <- integer(1..8),
            values <- list_of(float(min: -2.5, max: 2.5), length: batch_size),
            max_runs: 25
          ) do
      builder = fn theta ->
        [qubits: 1]
        |> Circuit.new()
        |> Gates.ry(0, theta: theta)
      end

      batch = Nx.tensor(values, type: {:f, 32})

      assert {:ok, first} =
               Performance.compare_batched_workflows(builder, batch,
                 runtime_profile: :cpu_portable,
                 observable: :pauli_z,
                 wire: 0
               )

      assert {:ok, second} =
               Performance.compare_batched_workflows(builder, batch,
                 runtime_profile: :cpu_portable,
                 observable: :pauli_z,
                 wire: 0
               )

      assert Nx.to_flat_list(first.batched_values) == Nx.to_flat_list(first.scalar_values)
      assert Nx.to_flat_list(first.batched_values) == Nx.to_flat_list(second.batched_values)
      assert first.metrics == second.metrics
    end
  end
end
