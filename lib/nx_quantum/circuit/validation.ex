defmodule NxQuantum.Circuit.Validation do
  @moduledoc false

  alias NxQuantum.Circuit.Error

  @spec validate_qubits!(term()) :: pos_integer()
  def validate_qubits!(qubits) when is_integer(qubits) and qubits >= 1, do: qubits

  def validate_qubits!(qubits) do
    raise Error.new(:invalid_qubit_count, %{qubits: qubits, expected: "integer >= 1"})
  end

  @spec validate_wire!(term()) :: non_neg_integer()
  def validate_wire!(wire) when is_integer(wire) and wire >= 0, do: wire

  def validate_wire!(wire) do
    raise Error.new(:invalid_wire_index, %{wire: wire, expected: "integer >= 0"})
  end

  @spec validate_wire_in_circuit!(term(), pos_integer()) :: non_neg_integer()
  def validate_wire_in_circuit!(wire, qubits) do
    normalized = validate_wire!(wire)

    if normalized < qubits do
      normalized
    else
      raise Error.new(:wire_out_of_range, %{wire: wire, qubits: qubits})
    end
  end

  @spec validate_operation_wires_in_circuit!(list(), pos_integer()) :: :ok
  def validate_operation_wires_in_circuit!(wires, qubits) when is_list(wires) do
    Enum.each(wires, &validate_wire_in_circuit!(&1, qubits))
    :ok
  end

  @spec validate_wire_pair!(term(), term()) :: {non_neg_integer(), non_neg_integer()}
  def validate_wire_pair!(a, b) do
    wa = validate_wire!(a)
    wb = validate_wire!(b)

    if wa == wb do
      raise Error.new(:invalid_two_qubit_wires, %{control: a, target: b, reason: :must_differ})
    end

    {wa, wb}
  end

  @spec fetch_wire_option!(keyword(), atom()) :: non_neg_integer()
  def fetch_wire_option!(opts, key) when is_list(opts) and is_atom(key) do
    case Keyword.fetch(opts, key) do
      {:ok, wire} ->
        validate_wire!(wire)

      :error ->
        raise Error.new(:missing_gate_option, %{option: key})
    end
  end

  @spec normalize_params!(keyword() | map()) :: map()
  def normalize_params!(params) when is_list(params), do: Map.new(params)
  def normalize_params!(params) when is_map(params), do: params

  def normalize_params!(params) do
    raise Error.new(:invalid_gate_params, %{params: params, expected: "keyword or map"})
  end
end
