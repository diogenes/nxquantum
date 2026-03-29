defmodule NxQuantum.AI.Tools.KernelRerank.ExecutionStrategy do
  @moduledoc false

  @default_parallel_threshold 32
  @default_parallel_min_work 16_384

  @type reason ::
          :forced_scalar
          | :forced_parallel
          | :parallel_threshold_met
          | :below_parallel_threshold
          | :parallel_disabled

  @type t :: %{
          mode: :scalar | :parallel,
          max_concurrency: pos_integer(),
          chunk_size: pos_integer(),
          reason: reason(),
          estimated_work: pos_integer()
        }

  @spec select(non_neg_integer(), non_neg_integer(), keyword()) :: t()
  def select(candidate_count, dim, opts) do
    parallel_mode = Keyword.get(opts, :parallel_mode, :auto)
    parallel? = Keyword.get(opts, :parallel, true)
    threshold = Keyword.get(opts, :parallel_threshold, @default_parallel_threshold)
    min_work = Keyword.get(opts, :parallel_min_work, @default_parallel_min_work)
    max_concurrency = max_concurrency(opts)

    estimated_work = max(1, candidate_count) * max(1, dim)
    parallel_eligible? = parallel? and candidate_count >= threshold and estimated_work >= min_work

    case parallel_mode do
      :force_scalar ->
        scalar_strategy(candidate_count, :forced_scalar, estimated_work)

      :force_parallel ->
        parallel_strategy(candidate_count, max_concurrency, :forced_parallel, estimated_work)

      :auto ->
        auto_strategy(candidate_count, max_concurrency, parallel?, parallel_eligible?, estimated_work)

      _unsupported ->
        scalar_strategy(candidate_count, :below_parallel_threshold, estimated_work)
    end
  end

  defp parallel_strategy(candidate_count, max_concurrency, reason, estimated_work) do
    chunk_size = (candidate_count + max_concurrency - 1) |> div(max_concurrency * 2) |> max(1)

    %{
      mode: :parallel,
      max_concurrency: max_concurrency,
      chunk_size: chunk_size,
      reason: reason,
      estimated_work: estimated_work
    }
  end

  defp scalar_strategy(candidate_count, reason, estimated_work) do
    %{
      mode: :scalar,
      max_concurrency: 1,
      chunk_size: max(1, candidate_count),
      reason: reason,
      estimated_work: estimated_work
    }
  end

  defp max_concurrency(opts) do
    opts
    |> Keyword.get(:max_concurrency, System.schedulers_online())
    |> case do
      value when is_integer(value) and value > 0 -> value
      _ -> System.schedulers_online()
    end
  end

  defp auto_strategy(candidate_count, max_concurrency, parallel?, parallel_eligible?, estimated_work) do
    cond do
      not parallel? ->
        scalar_strategy(candidate_count, :parallel_disabled, estimated_work)

      parallel_eligible? ->
        parallel_strategy(candidate_count, max_concurrency, :parallel_threshold_met, estimated_work)

      true ->
        scalar_strategy(candidate_count, :below_parallel_threshold, estimated_work)
    end
  end
end
