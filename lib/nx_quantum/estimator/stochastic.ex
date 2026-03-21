defmodule NxQuantum.Estimator.Stochastic do
  @moduledoc false

  alias NxQuantum.Random.Seed

  @spec apply_noise(number(), keyword()) :: number()
  def apply_noise(expectation, opts) do
    noise = Keyword.get(opts, :noise, [])
    depolarizing = Keyword.get(noise, :depolarizing, 0.0)
    amplitude_damping = Keyword.get(noise, :amplitude_damping, 0.0)

    expectation
    |> Kernel.*(1.0 - depolarizing)
    |> Kernel.*(1.0 - amplitude_damping)
    |> Kernel.+(amplitude_damping * 1.0)
    |> clamp()
  end

  @spec maybe_sample(number(), keyword()) :: number()
  def maybe_sample(expectation, opts) do
    shots = Keyword.get(opts, :shots)

    cond do
      is_nil(shots) ->
        expectation

      not is_integer(shots) or shots <= 0 ->
        expectation

      true ->
        seed = Keyword.get(opts, :seed, 0)
        Seed.seed(seed, :estimator_stochastic)

        p_plus = (expectation + 1.0) / 2.0
        plus_count = sample_plus_count(shots, p_plus)

        (2.0 * plus_count - shots) / shots
    end
  end

  defp clamp(v) when v > 1.0, do: 1.0
  defp clamp(v) when v < -1.0, do: -1.0
  defp clamp(v), do: v

  defp sample_plus_count(shots, p_plus) do
    Enum.reduce(1..shots, 0, fn _, acc -> acc + draw_plus(p_plus) end)
  end

  defp draw_plus(p_plus) do
    if :rand.uniform() <= p_plus, do: 1, else: 0
  end
end
