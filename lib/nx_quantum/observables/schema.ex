defmodule NxQuantum.Observables.Schema do
  @moduledoc false

  alias NxQuantum.Observables
  alias NxQuantum.Observables.Error

  @type measurement :: %{observable: Observables.observable(), wire: non_neg_integer()}

  @spec normalize_observable(term()) :: {:ok, Observables.observable()} | {:error, map()}
  def normalize_observable(observable) do
    if observable in Observables.supported() do
      {:ok, observable}
    else
      {:error, %{code: :unsupported_observable, observable: observable}}
    end
  end

  @spec normalize_wire(term()) :: {:ok, non_neg_integer()} | {:error, map()}
  def normalize_wire(wire) when is_integer(wire) and wire >= 0, do: {:ok, wire}

  def normalize_wire(wire) do
    {:error, %{code: :invalid_measurement_wire, wire: wire, expected: "integer >= 0"}}
  end

  @spec measurement(term(), term(), term()) :: {:ok, measurement()} | {:error, map()}
  def measurement(observable, wire, qubits) do
    with {:ok, normalized_observable} <- normalize_observable(observable),
         {:ok, normalized_wire} <- normalize_wire(wire),
         :ok <- validate_wire_in_qubits(normalized_wire, qubits) do
      {:ok, %{observable: normalized_observable, wire: normalized_wire}}
    end
  end

  @spec measurement!(term(), term(), term()) :: measurement()
  def measurement!(observable, wire, qubits) do
    case measurement(observable, wire, qubits) do
      {:ok, value} ->
        value

      {:error, %{code: code} = metadata} ->
        raise Error.new(code, Map.delete(metadata, :code))
    end
  end

  defp validate_wire_in_qubits(wire, qubits) when is_integer(qubits) and qubits >= 1 do
    if wire < qubits do
      :ok
    else
      {:error, %{code: :measurement_wire_out_of_range, wire: wire, qubits: qubits}}
    end
  end

  defp validate_wire_in_qubits(_wire, qubits) do
    {:error, %{code: :invalid_qubit_count, qubits: qubits, expected: "integer >= 1"}}
  end
end
