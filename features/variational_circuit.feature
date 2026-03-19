Feature: Variational circuit expectation
  As a QML researcher
  I want to build a variational quantum circuit with pipeline-friendly APIs
  So that I can compute expectation values in Elixir

  Scenario: Two-qubit variational layer returns expectation value
    Given a circuit with 2 qubits
    When I apply H on wire 0
    And I apply RX on wire 0 with theta "0.3"
    And I apply CNOT from wire 0 to wire 1
    And I apply RY on wire 1 with theta "0.1"
    And I measure expectation of Pauli-Z on wire 1
    Then I receive a scalar tensor expectation value

