Feature: Finite-shot estimation and noise modeling
  As an ML engineer
  I want shot-based and noisy circuit execution
  So that I can model realistic training and inference conditions

  Rule: Seeded shot sampling reproducibility
    Scenario: Same seed and shot count produce identical estimates
      Given a one-qubit circuit with expectation observable Pauli-Z
      And shot count is "1024"
      And random seed is "2026"
      When I estimate expectation by shots twice
      Then both estimates are exactly equal

    Scenario: More shots improve approximation quality
      Given a one-qubit circuit with analytical expectation "0.5"
      When I estimate expectation with "128" shots
      And I estimate expectation with "8192" shots
      Then the "8192"-shot estimate is closer to "0.5" than the "128"-shot estimate

  Rule: Noise channels modify expectation in expected direction
    Scenario: Depolarizing noise shrinks absolute expectation magnitude
      Given a one-qubit circuit with ideal expectation "1.0"
      And depolarizing probability is "0.1"
      When I evaluate expectation with depolarizing noise
      Then noisy expectation absolute value is less than "1.0"

    Scenario: Amplitude damping drives expectation toward ground-state bias
      Given a one-qubit circuit with ideal expectation "-1.0"
      And amplitude damping probability is "0.2"
      When I evaluate expectation with amplitude damping noise
      Then noisy expectation value is greater than "-1.0"
