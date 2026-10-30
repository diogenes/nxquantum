alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates

circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.2)
{:ok, result} = Estimator.run(circuit, observable: :pauli_z, wire: 0)

# The expectation of Z after RY(1.2) is cos(1.2), about 0.3623577.
Nx.to_flat_list(result.values)
