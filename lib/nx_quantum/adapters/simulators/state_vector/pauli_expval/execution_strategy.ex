defmodule NxQuantum.Adapters.Simulators.StateVector.PauliExpval.ExecutionStrategy do
  @moduledoc false

  @default_parallel_threshold 96

  @type t :: %{
          mode: :scalar | :parallel,
          max_concurrency: pos_integer(),
          chunk_size: pos_integer()
        }

  @spec select(non_neg_integer(), keyword()) :: t()
  def select(term_count, _opts) when term_count <= 1 do
    %{mode: :scalar, max_concurrency: 1, chunk_size: 1}
  end

  def select(term_count, opts) do
    parallel? = Keyword.get(opts, :parallel_observables, true)
    threshold = Keyword.get(opts, :parallel_observables_threshold, @default_parallel_threshold)
    max_concurrency = max_concurrency(opts)

    if parallel? and term_count >= threshold do
      chunk_size = (term_count + max_concurrency - 1) |> div(max_concurrency * 2) |> max(1)
      %{mode: :parallel, max_concurrency: max_concurrency, chunk_size: chunk_size}
    else
      %{mode: :scalar, max_concurrency: 1, chunk_size: max(1, term_count)}
    end
  end

  defp max_concurrency(opts) do
    opts
    |> Keyword.get(:observable_max_concurrency, Keyword.get(opts, :max_concurrency, System.schedulers_online()))
    |> case do
      value when is_integer(value) and value > 0 -> value
      _ -> System.schedulers_online()
    end
  end
end
