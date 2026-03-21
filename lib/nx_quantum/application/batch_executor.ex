defmodule NxQuantum.Application.BatchExecutor do
  @moduledoc false

  @spec run([term()], keyword(), (term() -> term())) :: [term()]
  def run(values, opts, fun) when is_list(values) and is_function(fun, 1) do
    if Keyword.get(opts, :parallel, false) do
      max_concurrency = Keyword.get(opts, :max_concurrency, System.schedulers_online())

      values
      |> Task.async_stream(fun,
        max_concurrency: max_concurrency,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(fn
        {:ok, result} -> result
        {:exit, reason} -> {:error, %{code: :batch_parallel_worker_crash, reason: reason}}
      end)
    else
      Enum.map(values, fun)
    end
  end
end
