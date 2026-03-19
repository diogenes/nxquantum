defmodule NxQuantum.Sampler.Engine do
  @moduledoc false

  @spec sample_counts(number(), pos_integer(), integer()) :: {non_neg_integer(), non_neg_integer()}
  def sample_counts(expectation_value, shots, seed) do
    p_one = clamp_probability((1.0 - expectation_value) / 2.0)
    seed_rng(seed)
    one_count = draw_ones(shots, p_one)
    zero_count = shots - one_count
    {zero_count, one_count}
  end

  defp draw_ones(shots, p_one) do
    Enum.reduce(1..shots, 0, fn _, acc ->
      if :rand.uniform() <= p_one, do: acc + 1, else: acc
    end)
  end

  defp seed_rng(seed) do
    a = rem(:erlang.phash2({seed, :sampler_a}), 30_000) + 1
    b = rem(:erlang.phash2({seed, :sampler_b}), 30_000) + 1
    c = rem(:erlang.phash2({seed, :sampler_c}), 30_000) + 1
    :rand.seed(:exsplus, {a, b, c})
  end

  defp clamp_probability(value) when value < 0.0, do: 0.0
  defp clamp_probability(value) when value > 1.0, do: 1.0
  defp clamp_probability(value), do: value
end
