defmodule NxQuantum.Adapters.Simulators.StateVector.EvolvedStateCache do
  @moduledoc false

  @table :nxq_state_vector_evolved_cache
  @default_max_bytes 16 * 1024 * 1024
  @default_ttl_ms 60_000

  @spec fetch(term(), (-> term()), keyword()) :: term()
  def fetch(key, builder_fun, opts \\ []) when is_function(builder_fun, 0) do
    table = ensure_table()
    now_ms = now_ms()
    ttl_ms = ttl_ms(opts)
    max_bytes = max_bytes(opts)

    cleanup_expired(table, now_ms)

    case safe_lookup(table, key, now_ms) do
      {:ok, value} ->
        value

      :miss ->
        value = builder_fun.()
        store(table, key, value, ttl_ms, max_bytes, now_ms)
        value
    end
  end

  @spec reset() :: :ok
  def reset do
    case :ets.whereis(@table) do
      :undefined -> :ok
      table -> :ets.delete_all_objects(table)
    end

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
  rescue
    _ -> 0
  end

  @spec total_bytes() :: non_neg_integer()
  def total_bytes do
    case :ets.whereis(@table) do
      :undefined -> 0
      table -> table_total_bytes(table)
    end
  rescue
    _ -> 0
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

  defp safe_lookup(table, key, now_ms) do
    case :ets.lookup(table, key) do
      [{^key, value, inserted_at_ms, expires_at_ms, bytes}] ->
        if expired?(expires_at_ms, now_ms) do
          :ets.delete(table, key)
          :miss
        else
          :ets.insert(table, {key, value, inserted_at_ms, expires_at_ms, bytes})
          {:ok, value}
        end

      [] ->
        :miss
    end
  rescue
    _ -> :miss
  end

  defp store(table, key, value, ttl_ms, max_bytes, now_ms) do
    expires_at_ms = expiry_from_ttl(now_ms, ttl_ms)
    bytes = estimate_bytes(value)

    existing_bytes =
      case :ets.lookup(table, key) do
        [{^key, _value, _inserted_at_ms, _expires_at_ms, prior_bytes}] -> prior_bytes
        _ -> 0
      end

    current_bytes = table_total_bytes(table) - existing_bytes
    overflow = current_bytes + bytes - max_bytes

    if overflow > 0 do
      evict_until_capacity(table, overflow, now_ms)
    end

    :ets.insert(table, {key, value, now_ms, expires_at_ms, bytes})
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

  defp table_total_bytes(table) do
    table
    |> :ets.tab2list()
    |> Enum.reduce(0, fn
      {_key, _value, _inserted_at_ms, _expires_at_ms, bytes}, acc when is_integer(bytes) and bytes > 0 -> acc + bytes
      _, acc -> acc
    end)
  rescue
    _ -> 0
  end

  defp cleanup_expired(table, now_ms) do
    table
    |> :ets.tab2list()
    |> Enum.each(fn
      {key, _value, _inserted_at_ms, expires_at_ms, _bytes} ->
        if expired?(expires_at_ms, now_ms) do
          :ets.delete(table, key)
        end

      _ ->
        :ok
    end)

    :ok
  rescue
    _ -> :ok
  end

  defp evict_until_capacity(table, bytes_to_free, now_ms) when bytes_to_free > 0 do
    _remaining =
      table
      |> oldest_entries(now_ms)
      |> Enum.reduce_while(bytes_to_free, fn {key, bytes}, remaining ->
        :ets.delete(table, key)
        updated = remaining - bytes

        if updated > 0 do
          {:cont, updated}
        else
          {:halt, 0}
        end
      end)

    :ok
  rescue
    _ -> :ok
  end

  defp evict_until_capacity(_table, _bytes_to_free, _now_ms), do: :ok

  defp oldest_entries(table, now_ms) do
    table
    |> :ets.tab2list()
    |> Enum.filter(fn
      {_key, _value, _inserted_at_ms, expires_at_ms, bytes} ->
        not expired?(expires_at_ms, now_ms) and is_integer(bytes) and bytes > 0

      _ ->
        false
    end)
    |> Enum.sort_by(fn {key, _value, inserted_at_ms, _expires_at_ms, _bytes} -> {inserted_at_ms, inspect(key)} end)
    |> Enum.map(fn {key, _value, _inserted_at_ms, _expires_at_ms, bytes} -> {key, bytes} end)
  end

  defp expired?(:infinity, _now_ms), do: false
  defp expired?(expires_at_ms, now_ms) when is_integer(expires_at_ms), do: expires_at_ms <= now_ms
  defp expired?(_expires_at_ms, _now_ms), do: false

  defp expiry_from_ttl(_now_ms, :infinity), do: :infinity
  defp expiry_from_ttl(now_ms, ttl_ms) when is_integer(ttl_ms), do: now_ms + ttl_ms

  defp ttl_ms(opts) do
    case Keyword.get(opts, :evolved_state_cache_ttl_ms, @default_ttl_ms) do
      ttl when is_integer(ttl) and ttl > 0 -> ttl
      :infinity -> :infinity
      _ -> @default_ttl_ms
    end
  end

  defp max_bytes(opts) do
    case Keyword.get(opts, :evolved_state_cache_max_bytes, @default_max_bytes) do
      max when is_integer(max) and max > 0 -> max
      _ -> @default_max_bytes
    end
  end

  defp estimate_bytes(%Nx.Tensor{} = tensor) do
    tensor
    |> Nx.to_binary()
    |> byte_size()
  rescue
    _ -> 0
  end

  defp estimate_bytes(value) do
    value
    |> :erlang.term_to_binary()
    |> byte_size()
  rescue
    _ -> 0
  end

  defp now_ms, do: System.monotonic_time(:millisecond)
end
