defmodule NxQuantum.TestSupport.Factories do
  @moduledoc false

  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  def one_qubit_circuit(opts \\ []) do
    qubits = Keyword.get(opts, :qubits, 1)
    theta = Keyword.get(opts, :theta, 0.0)

    [qubits: qubits]
    |> Circuit.new()
    |> Gates.ry(0, theta: theta)
  end

  def measured_pauli_z(circuit, wire \\ 0) do
    %{circuit | measurement: %{observable: :pauli_z, wire: wire}}
  end
end
