defmodule NxQuantum.Adapters.Simulators.StateVector.Cache do
  @moduledoc false

  # Structure cache for CNOT permutations, observable masks, and compiled plans.
  #
  # Two caps apply: an entry count (4096) and a byte budget. The byte budget is
  # `:nx_quantum, :state_vector_structure_cache_max_bytes` (default 512 MiB). An entry
  # larger than the budget is returned to the caller but not retained. Otherwise the
  # oldest entries (insertion order) are evicted until the new entry fits.

  @table :nxq_state_vector_matrix_cache
  @max_entries 4096
  @default_max_bytes 512 * 1024 * 1024
  @max_bytes_env :state_vector_structure_cache_max_bytes

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

  # Creates the table if needed, so the caller becomes its owner. The table is deleted when its owner exits.
  @spec reset() :: :ok
  def reset do
    _ = :ets.delete_all_objects(ensure_table())
    :ok
  rescue
    _ -> :ok
  end

  @spec size() :: non_neg_integer()
  def size do
    case :ets.whereis(@table) do
      :undefined -> 0
      table -> table_size(table)
    end
  end

  @spec total_bytes() :: non_neg_integer()
  def total_bytes do
    case :ets.whereis(@table) do
      :undefined -> 0
      table -> table_total_bytes(table)
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

  defp store(table, key, value) do
    bytes = estimate_bytes(value)
    max_bytes = max_bytes()

    if bytes <= max_bytes do
      if table_size(table) >= @max_entries do
        evict_one(table)
      end

      evict_until_fits(table, bytes, max_bytes)
      safe_insert(table, key, value, bytes)
    end

    :ok
  end

  defp evict_one(table) do
    case :ets.first(table) do
      :"$end_of_table" ->
        :ok

      first_key ->
        _ = :ets.delete(table, first_key)
        :ok
    end
  rescue
    _ -> :ok
  end

  # Oldest insertion first. Runs only when an insert would exceed the byte budget.
  defp evict_until_fits(table, incoming_bytes, max_bytes) do
    overflow = table_total_bytes(table) + incoming_bytes - max_bytes

    if overflow > 0 do
      _remaining =
        table
        |> insertion_ordered_entries()
        |> Enum.reduce_while(overflow, fn {key, bytes}, remaining ->
          _ = :ets.delete(table, key)

          if remaining - bytes > 0 do
            {:cont, remaining - bytes}
          else
            {:halt, 0}
          end
        end)
    end

    :ok
  rescue
    _ -> :ok
  end

  defp insertion_ordered_entries(table) do
    rows = :ets.foldl(fn {key, _value, sequence, bytes}, acc -> [{sequence, key, bytes} | acc] end, [], table)

    rows
    |> Enum.sort_by(fn {sequence, _key, _bytes} -> sequence end)
    |> Enum.map(fn {_sequence, key, bytes} -> {key, bytes} end)
  end

  defp table_size(table) do
    case :ets.info(table, :size) do
      size when is_integer(size) -> size
      _ -> 0
    end
  rescue
    _ -> 0
  end

  defp table_total_bytes(table) do
    :ets.foldl(fn {_key, _value, _sequence, bytes}, acc -> acc + bytes end, 0, table)
  rescue
    _ -> 0
  end

  defp safe_lookup(table, key) do
    case :ets.lookup(table, key) do
      [{^key, value, _sequence, _bytes}] -> {:ok, value}
      [] -> :miss
    end
  rescue
    _ -> :miss
  end

  defp safe_insert(table, key, value, bytes) do
    :ets.insert(table, {key, value, insertion_sequence(), bytes})
  rescue
    _ ->
      retry_table = ensure_table()

      try do
        :ets.insert(retry_table, {key, value, insertion_sequence(), bytes})
      rescue
        _ -> :ok
      end
  end

  defp max_bytes do
    case Application.get_env(:nx_quantum, @max_bytes_env, @default_max_bytes) do
      max when is_integer(max) and max >= 0 -> max
      _ -> @default_max_bytes
    end
  end

  # Tensors use their exact data size. Other terms (tuples, lists, plans) use the external
  # term size, which counts the binaries they hold.
  defp estimate_bytes(%Nx.Tensor{} = tensor), do: Nx.byte_size(tensor)
  defp estimate_bytes(value), do: :erlang.external_size(value)

  # Strictly increasing insertion order (FIFO eviction does not depend on timing).
  defp insertion_sequence, do: System.unique_integer([:monotonic, :positive])
end
