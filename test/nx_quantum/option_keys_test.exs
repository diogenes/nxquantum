defmodule NxQuantum.OptionKeysTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Gates
  alias NxQuantum.OptionKeys
  alias NxQuantum.Sampler

  setup do
    circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.1)
    %{circuit: circuit}
  end

  describe "Sampler.run/2" do
    test "an unknown seed key logs one warning and keeps the default seed", %{circuit: circuit} do
      {:ok, default} = Sampler.run(circuit, shots: 256)

      {result, log} = with_log(fn -> Sampler.run(circuit, shots: 256, seeed: 7) end)

      assert {:ok, misspelled} = result
      assert misspelled.counts == default.counts
      assert misspelled.metadata.unknown_options == [:seeed]
      assert log =~ "NxQuantum.Sampler.run/2"
      assert log =~ "[:seeed]"
      assert count_warnings(log) == 1
    end

    test "valid options log nothing and add no unknown_options entry", %{circuit: circuit} do
      {result, log} = with_log(fn -> Sampler.run(circuit, shots: 256, seed: 7, observable: :pauli_z, wire: 0) end)

      assert {:ok, valid} = result
      assert log == ""
      refute Map.has_key?(valid.metadata, :unknown_options)
    end
  end

  describe "Estimator.run/2" do
    test "a misspelled observable key is reported and the default observable is kept", %{circuit: circuit} do
      {:ok, default} = Estimator.run(circuit)

      {result, log} = with_log(fn -> Estimator.run(circuit, obsrvable: :pauli_x) end)

      assert {:ok, misspelled} = result
      assert Nx.to_flat_list(misspelled.values) == Nx.to_flat_list(default.values)
      assert misspelled.metadata.unknown_options == [:obsrvable]
      assert log =~ "NxQuantum.Estimator.run/2"
      assert log =~ "[:obsrvable]"
      assert count_warnings(log) == 1
    end

    test "KG-22 cache and concurrency keys are known and stay silent", %{circuit: circuit} do
      {result, log} =
        with_log(fn ->
          Estimator.run(circuit,
            cache_evolved_state: true,
            parallel_observables: true,
            max_concurrency: 2
          )
        end)

      assert {:ok, known} = result
      assert log == ""
      refute Map.has_key?(known.metadata, :unknown_options)
    end
  end

  describe "Estimator.expectation_result/2" do
    test "a misspelled seed key logs once and returns the default-seed tensor", %{circuit: circuit} do
      {:ok, default} = Estimator.expectation_result(circuit, shots: 64)

      {result, log} = with_log(fn -> Estimator.expectation_result(circuit, shots: 64, seeed: 7) end)

      assert {:ok, misspelled} = result
      assert Nx.to_number(misspelled) == Nx.to_number(default)
      assert log =~ "NxQuantum.Estimator.expectation_result/2"
      assert log =~ "[:seeed]"
      assert count_warnings(log) == 1
    end

    test "a valid seeded call logs nothing", %{circuit: circuit} do
      {_result, log} = with_log(fn -> Estimator.expectation_result(circuit, shots: 64, seed: 7) end)

      assert log == ""
    end
  end

  describe "OptionKeys" do
    test "validate/3 returns each unknown key once, in order, and ignores known keys" do
      {unknown, log} =
        with_log(fn ->
          OptionKeys.validate([seed: 1, seeed: 2, shots: 8, seeed: 3, sedd: 4], :sampler, "NxQuantum.Sampler.run/2")
        end)

      assert unknown == [:seeed, :sedd]
      assert count_warnings(log) == 1
    end

    test "validate/3 is silent when every key is known" do
      {unknown, log} =
        with_log(fn ->
          OptionKeys.validate([shots: 8, seed: 1], :sampler, "NxQuantum.Sampler.run/2")
        end)

      assert unknown == []
      assert log == ""
    end

    test "put_unknown/2 adds unknown_options only when there are unknown keys" do
      metadata_result = %{metadata: %{shots: 8}}

      assert OptionKeys.put_unknown(metadata_result, []) == metadata_result

      assert OptionKeys.put_unknown(metadata_result, [:seeed]) ==
               %{metadata: %{shots: 8, unknown_options: [:seeed]}}
    end

    test "the allow-list names every KG-22 cache and concurrency key" do
      kg22_keys = [
        :cache_evolved_state,
        :cache_parsed_counts,
        :cache_mask_lookup_plan,
        :parallel_observables,
        :max_concurrency,
        :sampled_parallel_mode
      ]

      for key <- kg22_keys do
        assert key in OptionKeys.estimator_keys(), "#{inspect(key)} must be in the Estimator allow-list"
      end
    end
  end

  defp count_warnings(log) do
    log
    |> String.split("ignores unknown option keys")
    |> length()
    |> Kernel.-(1)
  end
end
