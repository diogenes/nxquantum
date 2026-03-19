defmodule NxQuantum.Estimator.Measurement do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.Observables.Schema

  @spec apply(Circuit.t(), keyword()) :: {:ok, Circuit.t()} | {:error, map()}
  def apply(%Circuit{measurement: %{observable: observable, wire: wire}, qubits: qubits} = circuit, _opts) do
    with {:ok, measurement} <- Schema.measurement(observable, wire, qubits) do
      {:ok, %{circuit | measurement: measurement}}
    end
  end

  def apply(%Circuit{} = circuit, opts) do
    observable = Keyword.get(opts, :observable, :pauli_z)
    wire = Keyword.get(opts, :wire, 0)

    with {:ok, measurement} <- Schema.measurement(observable, wire, circuit.qubits) do
      {:ok, %{circuit | measurement: measurement}}
    end
  end
end
