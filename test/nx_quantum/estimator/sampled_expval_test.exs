defmodule NxQuantum.Estimator.SampledExpvalTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Estimator
  alias NxQuantum.Estimator.SampledExpval.MaskLookupCache
  alias NxQuantum.Estimator.SampledExpval.ParsedCounts
  alias NxQuantum.Observables.SparsePauli

  test "sampled_expectation_from_counts/2 computes Pauli-Z expectation for one qubit" do
    counts = %{"0" => 80, "1" => 20}

    assert {:ok, tensor} =
             Estimator.sampled_expectation_from_counts(counts,
               observable: :pauli_z,
               wire: 0
             )

    assert_in_delta Nx.to_number(tensor), 0.6, 1.0e-6
  end

  test "sampled_expectation_from_counts/2 preserves observable ordering for batch path" do
    counts = %{"00" => 70, "01" => 20, "10" => 5, "11" => 5}

    assert {:ok, values} =
             Estimator.sampled_expectation_from_counts(counts,
               observables: [%{observable: :pauli_z, wire: 1}, %{observable: :pauli_z, wire: 0}]
             )

    assert Nx.shape(values) == {2}
    [first, second] = Nx.to_flat_list(values)
    assert_in_delta first, 0.8, 1.0e-6
    assert_in_delta second, 0.5, 1.0e-6
  end

  test "sampled_expectation_from_counts/2 supports sparse-pauli diagonal operators" do
    counts = %{"00" => 50, "01" => 10, "10" => 30, "11" => 10}

    {:ok, sparse_pauli} =
      SparsePauli.new(2, [
        %{x_mask: 0, z_mask: 1, coeff: 0.7},
        %{x_mask: 0, z_mask: 2, coeff: 0.3}
      ])

    assert {:ok, tensor} =
             Estimator.sampled_expectation_from_counts(counts,
               sparse_pauli: sparse_pauli
             )

    # z_mask=1 => 0.6, z_mask=2 => 0.2
    assert_in_delta Nx.to_number(tensor), 0.7 * 0.6 + 0.3 * 0.2, 1.0e-6
  end

  test "sampled_expectation_from_counts/2 returns typed error for non-diagonal sparse terms" do
    counts = %{"0" => 10, "1" => 10}
    {:ok, sparse_pauli} = SparsePauli.new(1, [%{x_mask: 1, z_mask: 0, coeff: 1.0}])

    assert {:error, %{code: :unsupported_sampled_non_diagonal_term}} =
             Estimator.sampled_expectation_from_counts(counts, sparse_pauli: sparse_pauli)
  end

  test "sampled_expectation_from_counts/2 returns typed error for Pauli-X observable from z-basis counts" do
    counts = %{"0" => 10, "1" => 10}

    assert {:error, %{code: :unsupported_sampled_non_diagonal_term}} =
             Estimator.sampled_expectation_from_counts(counts, observable: :pauli_x, wire: 0)
  end

  test "sampled_expectation_from_counts/2 validates count bitstring shape consistency" do
    counts = %{"0" => 10, "11" => 20}

    assert {:error, %{code: :inconsistent_count_bitstring_lengths}} =
             Estimator.sampled_expectation_from_counts(counts, observable: :pauli_z, wire: 0)
  end

  test "sampled_expectation_from_counts/2 keeps deterministic values across strategy thresholds" do
    counts = %{"00" => 70, "01" => 20, "10" => 5, "11" => 5}

    opts = [
      observables: [%{observable: :pauli_z, wire: 1}, %{observable: :pauli_z, wire: 0}, %{observable: :pauli_z, wire: 1}]
    ]

    assert {:ok, scalar} =
             Estimator.sampled_expectation_from_counts(
               counts,
               opts ++ [parallel_sampled_terms: true, parallel_sampled_terms_threshold: 99]
             )

    assert {:ok, parallel} =
             Estimator.sampled_expectation_from_counts(
               counts,
               opts ++ [parallel_sampled_terms: true, parallel_sampled_terms_threshold: 1, max_concurrency: 4]
             )

    assert Nx.to_flat_list(scalar) == Nx.to_flat_list(parallel)
  end

  test "sampled_expectation_from_counts/2 keeps deterministic values across reducer backends" do
    counts = %{"000" => 500, "001" => 200, "010" => 150, "111" => 150}

    {:ok, sparse_pauli} =
      SparsePauli.new(3, [
        %{x_mask: 0, z_mask: 1, coeff: 0.4},
        %{x_mask: 0, z_mask: 2, coeff: -0.3},
        %{x_mask: 0, z_mask: 4, coeff: 0.2}
      ])

    assert {:ok, elixir_value} =
             Estimator.sampled_expectation_from_counts(counts,
               sparse_pauli: sparse_pauli,
               sampled_reducer_backend: :elixir
             )

    assert {:ok, nx_value} =
             Estimator.sampled_expectation_from_counts(counts,
               sparse_pauli: sparse_pauli,
               sampled_reducer_backend: :nx
             )

    assert_in_delta Nx.to_number(elixir_value), Nx.to_number(nx_value), 1.0e-10
  end

  test "parsed counts cache and mask lookup plan are deterministic" do
    counts = %{"00" => 5, "01" => 3, "10" => 2}

    assert {:ok, parsed_a} = ParsedCounts.parse(counts, cache_parsed_counts: true)
    assert {:ok, parsed_b} = ParsedCounts.parse(counts, cache_parsed_counts: true)
    assert parsed_a.hash == parsed_b.hash
    assert parsed_a.entries == parsed_b.entries

    terms = [
      %{x_mask: 0, z_mask: 1, coeff: {1.0, 0.0}},
      %{x_mask: 0, z_mask: 2, coeff: {1.0, 0.0}},
      %{x_mask: 0, z_mask: 1, coeff: {2.0, 0.0}}
    ]

    plan_a = MaskLookupCache.for_terms(terms, cache_mask_lookup_plan: true)
    plan_b = MaskLookupCache.for_terms(terms, cache_mask_lookup_plan: true)

    assert plan_a == plan_b
    assert Enum.sort(plan_a.unique_masks) == [1, 2]
    assert plan_a.ordered_masks == [1, 2, 1]
  end
end
