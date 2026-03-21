defmodule NxQuantum.Adapters.Simulators.StateVector.Matrices do
  @moduledoc false

  alias NxQuantum.Adapters.Simulators.StateVector.CompiledPlan
  alias NxQuantum.Adapters.Simulators.StateVector.MatrixLibrary

  @type single_qubit_gate_coefficients :: MatrixLibrary.single_qubit_gate_coefficients()

  @spec observable_matrix(:pauli_x | :pauli_y | :pauli_z, non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def observable_matrix(observable, wire, qubits), do: MatrixLibrary.observable_matrix(observable, wire, qubits)

  @spec pauli_z_signs(non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def pauli_z_signs(wire, qubits), do: MatrixLibrary.pauli_z_signs(wire, qubits)

  @spec gate_matrix(NxQuantum.GateOperation.t(), pos_integer()) :: Nx.Tensor.t()
  def gate_matrix(op, qubits), do: MatrixLibrary.gate_matrix(op, qubits)

  @spec single_qubit_gate_matrix(NxQuantum.GateOperation.t()) :: Nx.Tensor.t()
  def single_qubit_gate_matrix(op), do: MatrixLibrary.single_qubit_gate_matrix(op)

  @spec single_qubit_gate_coefficients(NxQuantum.GateOperation.t()) :: single_qubit_gate_coefficients()
  def single_qubit_gate_coefficients(op), do: MatrixLibrary.single_qubit_gate_coefficients(op)

  @spec compiled_execution_plan([NxQuantum.GateOperation.t()], pos_integer()) :: [struct()]
  def compiled_execution_plan(operations, qubits), do: CompiledPlan.compiled_execution_plan(operations, qubits)

  @spec cnot_permutation(non_neg_integer(), non_neg_integer(), pos_integer()) :: Nx.Tensor.t()
  def cnot_permutation(control, target, qubits), do: MatrixLibrary.cnot_permutation(control, target, qubits)

  @spec single_qubit_layout_plan(non_neg_integer(), pos_integer()) :: map()
  def single_qubit_layout_plan(wire, qubits), do: MatrixLibrary.single_qubit_layout_plan(wire, qubits)
end
