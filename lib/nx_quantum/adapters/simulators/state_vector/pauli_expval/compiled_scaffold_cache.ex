defmodule NxQuantum.Adapters.Simulators.StateVector.PauliExpval.CompiledScaffoldCache do
  @moduledoc false

  import Bitwise

  @table :nxq_pauli_compiled_scaffold_cache
  @max_entries 256

  @type scaffold :: %{
          selector: Nx.Tensor.t(),
          signs: Nx.Tensor.t(),
          flipped_indices: Nx.Tensor.t()
        }

  @type batch_scaffold :: %{
          selector: Nx.Tensor.t(),
          signs: Nx.Tensor.t(),
          flipped_indices: Nx.Tensor.t(),
          wire_index: %{required(non_neg_integer()) => non_neg_integer()}
        }

  @spec fetch(pos_integer(), non_neg_integer()) :: scaffold()
  def fetch(qubits, wire) when is_integer(qubits) and qubits > 0 and is_integer(wire) and wire >= 0 do
    key = {qubits, wire}
    table = ensure_table()

    case safe_lookup(table, key) do
      {:ok, value} ->
        value

      :miss ->
        value = build_scaffold(qubits, wire)
        store(table, key, value)
        value
    end
  end

  @spec fetch_batch(pos_integer(), [non_neg_integer()], keyword()) :: batch_scaffold()
  def fetch_batch(qubits, wires, opts \\ []) when is_integer(qubits) and qubits > 0 and is_list(wires) do
    normalized_wires = wires |> Enum.uniq() |> Enum.sort()
    backend = Keyword.get(opts, :backend, Nx.BinaryBackend)
    key = {:batch, qubits, normalized_wires, backend_key(backend)}
    table = ensure_table()

    case safe_lookup(table, key) do
      {:ok, value} ->
        value

      :miss ->
        value = build_batch_scaffold(qubits, normalized_wires, backend)
        store(table, key, value)
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
      :undefined ->
        0

      table ->
        case :ets.info(table, :size) do
          size when is_integer(size) and size >= 0 -> size
          _ -> 0
        end
    end
  rescue
    _ -> 0
  end

  defp build_scaffold(qubits, wire) do
    dim = 1 <<< qubits
    indices = Nx.iota({dim}, type: {:u, 64})
    mask = Nx.tensor(1 <<< wire, type: {:u, 64})
    zeros = Nx.equal(Nx.bitwise_and(indices, mask), Nx.tensor(0, type: {:u, 64}))

    selector = Nx.select(zeros, Nx.tensor(1.0, type: {:f, 64}), Nx.tensor(0.0, type: {:f, 64}))
    signs = Nx.select(zeros, Nx.tensor(1.0, type: {:f, 64}), Nx.tensor(-1.0, type: {:f, 64}))
    flipped_indices = Nx.bitwise_xor(indices, mask)

    %{selector: selector, signs: signs, flipped_indices: flipped_indices}
  end

  defp build_batch_scaffold(qubits, wires, backend) do
    wire_scaffolds = Enum.map(wires, &fetch(qubits, &1))

    selector =
      wire_scaffolds
      |> Enum.map(& &1.selector)
      |> Nx.stack()
      |> maybe_transfer_backend(backend)

    signs =
      wire_scaffolds
      |> Enum.map(& &1.signs)
      |> Nx.stack()
      |> maybe_transfer_backend(backend)

    flipped_indices =
      wire_scaffolds
      |> Enum.map(& &1.flipped_indices)
      |> Nx.stack()
      |> maybe_transfer_backend(backend)

    wire_index =
      wires
      |> Enum.with_index()
      |> Map.new()

    %{
      selector: selector,
      signs: signs,
      flipped_indices: flipped_indices,
      wire_index: wire_index
    }
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

  defp maybe_transfer_backend(tensor, Nx.BinaryBackend), do: tensor

  defp maybe_transfer_backend(tensor, backend) do
    Nx.backend_transfer(tensor, backend)
  rescue
    _ -> tensor
  end

  defp backend_key(Nx.BinaryBackend), do: :binary

  defp backend_key({backend, opts}) when is_atom(backend) and is_list(opts) do
    {backend, Enum.sort_by(opts, &elem(&1, 0))}
  end

  defp backend_key(backend) when is_atom(backend), do: backend
  defp backend_key(backend), do: inspect(backend)
end
