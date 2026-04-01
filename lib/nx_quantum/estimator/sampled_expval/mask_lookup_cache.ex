defmodule NxQuantum.Estimator.SampledExpval.MaskLookupCache do
  @moduledoc false

  @table :nxq_sampled_expval_mask_lookup_cache
  @max_entries 512

  @type plan :: %{
          unique_masks: [non_neg_integer()],
          ordered_masks: [non_neg_integer()]
        }

  @spec for_terms([map()], keyword()) :: plan()
  def for_terms(terms, opts \\ []) when is_list(terms) do
    if Keyword.get(opts, :cache_mask_lookup_plan, true) do
      key = cache_key(terms)

      case lookup(key) do
        {:ok, plan} ->
          plan

        :miss ->
          plan = build_plan(terms)
          store(key, plan)
          plan
      end
    else
      build_plan(terms)
    end
  end

  defp build_plan(terms) do
    ordered_masks = Enum.map(terms, & &1.z_mask)
    unique_masks = Enum.uniq(ordered_masks)
    %{unique_masks: unique_masks, ordered_masks: ordered_masks}
  end

  defp cache_key(terms) do
    :erlang.phash2(terms)
  end

  defp lookup(key) do
    table = ensure_table()

    case :ets.lookup(table, key) do
      [{^key, value}] -> {:ok, value}
      [] -> :miss
    end
  end

  defp store(key, value) do
    table = ensure_table()

    if table_size(table) >= @max_entries do
      evict_one(table)
    end

    :ets.insert(table, {key, value})
    :ok
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined ->
        safe_new_named_table(@table, [:named_table, :set, :public, read_concurrency: true, write_concurrency: true])

      _ ->
        @table
    end
  end

  defp table_size(table) do
    table
    |> :ets.info(:size)
    |> normalize_table_size()
  end

  defp evict_one(table) do
    first_key = :ets.first(table)

    if first_key != :"$end_of_table" do
      :ets.delete(table, first_key)
    end

    :ok
  end

  @doc false
  def safe_new_named_table(table_name, options) do
    :ets.new(table_name, options)
  rescue
    ArgumentError -> table_name
  end

  @doc false
  def normalize_table_size(size) when is_integer(size), do: size
  def normalize_table_size(_), do: 0
end
