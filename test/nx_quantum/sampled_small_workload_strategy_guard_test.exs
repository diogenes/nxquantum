defmodule NxQuantum.SampledSmallWorkloadStrategyGuardTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Estimator.SampledExpval.ExecutionStrategy

  test "auto strategy selects scalar for small sampled workload" do
    strategy =
      ExecutionStrategy.select(
        48,
        10,
        parallel_sampled_terms: true,
        parallel_sampled_terms_threshold: 8,
        sampled_parallel_mode: :auto,
        sampled_parallel_min_work: 8_192
      )

    assert strategy.mode == :scalar
  end

  test "auto strategy selects parallel for large sampled workload" do
    strategy =
      ExecutionStrategy.select(
        128,
        512,
        parallel_sampled_terms: true,
        parallel_sampled_terms_threshold: 8,
        sampled_parallel_mode: :auto,
        sampled_parallel_min_work: 8_192,
        max_concurrency: 8
      )

    assert strategy.mode == :parallel
  end
end
