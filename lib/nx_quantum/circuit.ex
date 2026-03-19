defmodule NxQuantum.Circuit do
  @moduledoc """
  Domain aggregate for quantum circuit definition.
  """

  alias NxQuantum.Circuit.Error
  alias NxQuantum.Circuit.Validation
  alias NxQuantum.Estimator
  alias NxQuantum.GateOperation
  alias NxQuantum.Observables
  alias NxQuantum.Observables.Schema

  @enforce_keys [:qubits]
  defstruct qubits: nil, operations: [], measurement: nil, bindings: %{}, metadata: %{}

  @type measurement :: %{
          observable: Observables.observable(),
          wire: non_neg_integer()
        }

  @type t :: %__MODULE__{
          qubits: pos_integer(),
          operations: [GateOperation.t()],
          measurement: measurement() | nil,
          bindings: map(),
          metadata: map()
        }

  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    qubits = opts |> Keyword.get(:qubits, 1) |> Validation.validate_qubits!()

    %__MODULE__{qubits: qubits, metadata: Map.new(opts)}
  end

  @spec bind(t(), keyword() | map()) :: t()
  def bind(%__MODULE__{} = circuit, params) do
    normalized = Validation.normalize_params!(params)
    %{circuit | bindings: Map.merge(circuit.bindings, normalized)}
  end

  @spec add_gate(t(), GateOperation.t()) :: t()
  def add_gate(%__MODULE__{} = circuit, %GateOperation{} = operation) do
    Validation.validate_operation_wires_in_circuit!(operation.wires, circuit.qubits)
    %{circuit | operations: circuit.operations ++ [operation]}
  end

  @spec expectation(t(), keyword()) :: Nx.Tensor.t()
  def expectation(%__MODULE__{} = circuit, opts \\ []) do
    observable = Keyword.fetch!(opts, :observable)
    wire = Keyword.fetch!(opts, :wire)
    measurement = normalize_measurement!(observable, wire, circuit.qubits)

    circuit
    |> Map.put(:measurement, measurement)
    |> Estimator.expectation(opts)
  end

  defp normalize_measurement!(observable, wire, qubits) do
    case Schema.measurement(observable, wire, qubits) do
      {:ok, measurement} ->
        measurement

      {:error, %{code: code} = metadata} ->
        raise Error.new(code, Map.delete(metadata, :code))
    end
  end
end
