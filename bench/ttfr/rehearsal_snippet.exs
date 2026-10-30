alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates

circuit =
  Circuit.new(qubits: 1)
  |> Gates.ry(0, theta: Nx.tensor(1.2))

circuit
|> Estimator.expectation(observable: :pauli_z, wire: 0)
|> Nx.to_number()
|> IO.puts()
