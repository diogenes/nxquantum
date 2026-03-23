defmodule NxQuantum.Estimator.SampledExpval.ParsedCounts do
  @moduledoc false

  @table :nxq_sampled_expval_parsed_counts_cache
  @max_entries 512

  @type t :: %__MODULE__{
          entries: [{non_neg_integer(), float()}],
          values: [non_neg_integer()],
          counts: [float()],
          counts_tensor: Nx.Tensor.t(),
          shots: float(),
          qubits: pos_integer(),
          entry_count: non_neg_integer(),
          hash: non_neg_integer()
        }

  defstruct [
    :entries,
    :values,
    :counts,
    :counts_tensor,
    :shots,
    :qubits,
    :entry_count,
    :hash
  ]

  @spec parse(map(), keyword()) :: {:ok, t()} | {:error, map()}
  def parse(counts, opts \\ [])

  def parse(counts, opts) when is_map(counts) do
    if Keyword.get(opts, :cache_parsed_counts, true) do
      key = cache_key(counts)

      case lookup(key) do
        {:ok, parsed} ->
          {:ok, parsed}

        :miss ->
          with {:ok, parsed} <- parse_uncached(counts) do
            store(key, parsed)
            {:ok, parsed}
          end
      end
    else
      parse_uncached(counts)
    end
  end

  def parse(invalid, _opts), do: {:error, %{code: :invalid_counts_payload, counts: invalid}}

  defp parse_uncached(counts) do
    entries =
      Enum.reduce_while(counts, {:ok, []}, fn {bitstring, count}, {:ok, acc} ->
        with {:ok, normalized_bits} <- normalize_bitstring(bitstring),
             {:ok, normalized_count} <- normalize_count(count),
             {:ok, value} <- parse_bitstring(normalized_bits) do
          {:cont, {:ok, [{normalized_bits, value, normalized_count * 1.0} | acc]}}
        else
          {:error, _} = error -> {:halt, error}
        end
      end)

    with {:ok, raw_entries} <- entries,
         :ok <- ensure_non_empty(raw_entries),
         {:ok, qubits} <- infer_qubits(raw_entries) do
      numeric_entries =
        Enum.map(raw_entries, fn {_bits, value, count} ->
          {value, count}
        end)

      shots =
        numeric_entries
        |> Enum.map(fn {_value, count} -> count end)
        |> Enum.sum()

      if shots > 0 do
        values = Enum.map(numeric_entries, &elem(&1, 0))
        counts_list = Enum.map(numeric_entries, &elem(&1, 1))

        {:ok,
         %__MODULE__{
           entries: numeric_entries,
           values: values,
           counts: counts_list,
           counts_tensor: Nx.tensor(counts_list, type: {:f, 64}),
           shots: shots,
           qubits: qubits,
           entry_count: length(numeric_entries),
           hash: cache_key(counts)
         }}
      else
        {:error, %{code: :invalid_counts_total_shots, counts: counts}}
      end
    end
  end

  defp cache_key(counts) do
    :erlang.phash2(counts)
  end

  defp lookup(key) do
    table = ensure_table()

    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :miss
    end
  rescue
    _ -> :miss
  end

  defp store(key, value) do
    table = ensure_table()

    if table_size(table) >= @max_entries do
      evict_one(table)
    end

    :ets.insert(table, {key, value})
    :ok
  rescue
    _ -> :ok
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

  defp normalize_bitstring(value) when is_binary(value), do: {:ok, value}
  defp normalize_bitstring(value), do: {:error, %{code: :invalid_count_bitstring, bitstring: value}}

  defp normalize_count(value) when is_integer(value) and value >= 0, do: {:ok, value}
  defp normalize_count(value), do: {:error, %{code: :invalid_count_value, count: value}}

  defp parse_bitstring(bitstring) do
    if String.match?(bitstring, ~r/^[01]+$/) do
      {:ok, String.to_integer(bitstring, 2)}
    else
      {:error, %{code: :invalid_count_bitstring, bitstring: bitstring}}
    end
  end

  defp ensure_non_empty([]), do: {:error, %{code: :invalid_counts_payload, counts: %{}}}
  defp ensure_non_empty(_entries), do: :ok

  defp infer_qubits(entries) do
    lengths =
      entries
      |> Enum.map(fn {bits, _value, _count} -> String.length(bits) end)
      |> Enum.uniq()

    case lengths do
      [qubits] when qubits > 0 -> {:ok, qubits}
      _ -> {:error, %{code: :inconsistent_count_bitstring_lengths, lengths: lengths}}
    end
  end
end
