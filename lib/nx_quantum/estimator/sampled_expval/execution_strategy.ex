defmodule NxQuantum.Estimator.SampledExpval.ExecutionStrategy do
  @moduledoc false

  @default_parallel_threshold 24

  @type t :: %{
          mode: :scalar | :parallel,
          max_concurrency: pos_integer(),
          chunk_size: pos_integer()
        }

  @spec select(non_neg_integer(), keyword()) :: t()
  def select(unit_count, _opts) when unit_count <= 1 do
    %{mode: :scalar, max_concurrency: 1, chunk_size: 1}
  end

  def select(unit_count, opts) do
    parallel? = Keyword.get(opts, :parallel_sampled_terms, true)
    threshold = Keyword.get(opts, :parallel_sampled_terms_threshold, @default_parallel_threshold)
    max_concurrency = max_concurrency(opts)

    if parallel? and unit_count >= threshold do
      chunk_size = (unit_count + max_concurrency - 1) |> div(max_concurrency * 2) |> max(1)
      %{mode: :parallel, max_concurrency: max_concurrency, chunk_size: chunk_size}
    else
      %{mode: :scalar, max_concurrency: 1, chunk_size: max(1, unit_count)}
    end
  end

  defp max_concurrency(opts) do
    opts
    |> Keyword.get(:max_concurrency, System.schedulers_online())
    |> case do
      value when is_integer(value) and value > 0 -> value
      _ -> System.schedulers_online()
    end
  end
end
