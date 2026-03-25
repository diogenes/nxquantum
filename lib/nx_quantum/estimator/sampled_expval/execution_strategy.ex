defmodule NxQuantum.Estimator.SampledExpval.ExecutionStrategy do
  @moduledoc false

  @default_parallel_threshold 24
  @default_parallel_min_work 8_192

  @type t :: %{
          mode: :scalar | :parallel,
          max_concurrency: pos_integer(),
          chunk_size: pos_integer()
        }

  @spec select(non_neg_integer(), keyword()) :: t()
  def select(unit_count, opts), do: select(unit_count, 1, opts)

  @spec select(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def select(unit_count, _entry_count, _opts) when unit_count <= 1 do
    %{mode: :scalar, max_concurrency: 1, chunk_size: 1}
  end

  def select(unit_count, entry_count, opts) do
    parallel_mode = Keyword.get(opts, :sampled_parallel_mode, :auto)
    parallel? = Keyword.get(opts, :parallel_sampled_terms, true)
    threshold = Keyword.get(opts, :parallel_sampled_terms_threshold, @default_parallel_threshold)
    min_work = Keyword.get(opts, :sampled_parallel_min_work, @default_parallel_min_work)
    max_concurrency = max_concurrency(opts)
    estimated_work = max(1, unit_count) * max(1, entry_count)
    parallel_eligible? = parallel? and unit_count >= threshold and estimated_work >= min_work

    case parallel_mode do
      :force_scalar ->
        scalar_strategy(unit_count)

      :force_parallel ->
        parallel_strategy(unit_count, max_concurrency)

      :auto ->
        if parallel_eligible? do
          parallel_strategy(unit_count, max_concurrency)
        else
          scalar_strategy(unit_count)
        end

      _unsupported ->
        scalar_strategy(unit_count)
    end
  end

  defp parallel_strategy(unit_count, max_concurrency) do
    chunk_size = (unit_count + max_concurrency - 1) |> div(max_concurrency * 2) |> max(1)
    %{mode: :parallel, max_concurrency: max_concurrency, chunk_size: chunk_size}
  end

  defp scalar_strategy(unit_count), do: %{mode: :scalar, max_concurrency: 1, chunk_size: max(1, unit_count)}

  defp max_concurrency(opts) do
    opts
    |> Keyword.get(:max_concurrency, System.schedulers_online())
    |> case do
      value when is_integer(value) and value > 0 -> value
      _ -> System.schedulers_online()
    end
  end
end
