defmodule NxQuantum.Estimator.SampledExpval.CountsReducer do
  @moduledoc false

  import Bitwise
  import Nx.Defn

  alias NxQuantum.Estimator.SampledExpval.ExecutionStrategy
  alias NxQuantum.Estimator.SampledExpval.ParsedCounts

  @spec lookup(ParsedCounts.t(), [non_neg_integer()], keyword()) :: %{non_neg_integer() => float()}
  def lookup(%ParsedCounts{} = parsed, unique_masks, opts \\ []) when is_list(unique_masks) do
    strategy = ExecutionStrategy.select(length(unique_masks), opts)
    backend = select_backend(parsed, unique_masks, opts)

    unique_masks
    |> execute_lookup(parsed, strategy, backend)
    |> Map.new()
  end

  defp execute_lookup([], _parsed, _strategy, _backend), do: []

  defp execute_lookup(masks, parsed, %{mode: :scalar}, backend) do
    Enum.map(masks, fn z_mask -> {z_mask, expectation(parsed, z_mask, backend)} end)
  end

  defp execute_lookup(masks, parsed, %{mode: :parallel} = strategy, backend) do
    masks
    |> Enum.chunk_every(strategy.chunk_size)
    |> Task.async_stream(
      fn chunk ->
        Enum.map(chunk, fn z_mask -> {z_mask, expectation(parsed, z_mask, backend)} end)
      end,
      max_concurrency: strategy.max_concurrency,
      ordered: true,
      timeout: :infinity
    )
    |> Enum.flat_map(fn
      {:ok, values} -> values
      {:exit, reason} -> raise "parallel sampled expectation lookup failed: #{inspect(reason)}"
    end)
  end

  defp expectation(parsed, z_mask, :elixir), do: expectation_elixir(parsed, z_mask)
  defp expectation(parsed, z_mask, :nx), do: expectation_nx(parsed, z_mask)

  defp expectation_elixir(%ParsedCounts{entries: entries, shots: shots}, z_mask) do
    signed_sum =
      Enum.reduce(entries, 0.0, fn {bitstring_value, count}, acc ->
        sign = if odd_parity?(bitstring_value &&& z_mask), do: -1.0, else: 1.0
        acc + sign * count
      end)

    signed_sum / shots
  end

  defp expectation_nx(%ParsedCounts{values: values, counts_tensor: counts_tensor, shots: shots}, z_mask) do
    signs =
      values
      |> Enum.map(fn value ->
        if odd_parity?(value &&& z_mask), do: -1.0, else: 1.0
      end)
      |> Nx.tensor(type: {:f, 64})

    counts_tensor
    |> weighted_sum(signs)
    |> Nx.divide(shots)
    |> Nx.to_number()
  end

  defn weighted_sum(counts, signs) do
    Nx.dot(counts, signs)
  end

  defp select_backend(parsed, masks, opts) do
    case Keyword.get(opts, :sampled_reducer_backend, :auto) do
      :elixir ->
        :elixir

      :nx ->
        :nx

      :auto ->
        nx_threshold = Keyword.get(opts, :sampled_nx_reducer_threshold, 4_096)

        if length(masks) * parsed.entry_count >= nx_threshold do
          :nx
        else
          :elixir
        end
    end
  end

  defp odd_parity?(value), do: rem(popcount(value), 2) == 1

  defp popcount(value), do: popcount(value, 0)
  defp popcount(0, acc), do: acc
  defp popcount(value, acc), do: popcount(value &&& value - 1, acc + 1)
end
