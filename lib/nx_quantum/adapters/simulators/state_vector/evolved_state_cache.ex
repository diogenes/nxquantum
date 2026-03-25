defmodule NxQuantum.Adapters.Simulators.StateVector.EvolvedStateCache do
  @moduledoc false

  @table :nxq_state_vector_evolved_cache
  @max_entries 128

  @spec fetch(term(), (-> term())) :: term()
  def fetch(key, builder_fun) when is_function(builder_fun, 0) do
    table = ensure_table()

    case safe_lookup(table, key) do
      {:ok, value} ->
        value

      :miss ->
        value = builder_fun.()
        store(table, key, value)
        value
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        try do
          :ets.new(@table, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])
        rescue
          _ -> @table
        end

      _ ->
        @table
    end
  end

  defp safe_lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :miss
    end
  rescue
    _ -> :miss
  end

  defp store(table, key, value) do
    if table_size(table) >= @max_entries do
      evict_one(table)
    end

    :ets.insert(table, {key, value})
    :ok
  rescue
    _ -> :ok
  end

  defp table_size(table) do
    case :ets.info(table, :size) do
      size when is_integer(size) -> size
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp evict_one(table) do
    case :ets.first(table) do
      :"$end_of_table" -> :ok
      first_key -> :ets.delete(table, first_key)
    end
  rescue
    _ -> :ok
  end
end
