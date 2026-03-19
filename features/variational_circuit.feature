Feature: Variational circuit expectation
  As a QML researcher
  I want to build a variational quantum circuit with pipeline-friendly APIs
  So that I can compute expectation values in Elixir

  Rule: Deterministic one-qubit Pauli expectations
    Scenario Outline: One-qubit analytical references for Pauli observables
      Given a circuit with 1 qubit
      And I apply RY on wire 0 with theta "<theta>"
      When I measure expectation of <observable> on wire 0
      Then I receive a scalar tensor expectation value
      And the scalar value is approximately "<expected>" with tolerance "1.0e-5"

      Examples:
        | theta              | observable | expected |
        | 1.5707963267948966 | Pauli-Z    | 0.0      |
        | 1.5707963267948966 | Pauli-X    | 1.0      |
        | 1.5707963267948966 | Pauli-Y    | 0.0      |

  Rule: Deterministic two-qubit evolution
    Scenario: Bell-state expectation is deterministic
      Given a circuit with 2 qubits
      When I apply H on wire 0
      And I apply CNOT from wire 0 to wire 1
      And I measure expectation of Pauli-Z on wire 1
      Then I receive a scalar tensor expectation value
      And the scalar value is approximately "0.0" with tolerance "1.0e-6"
