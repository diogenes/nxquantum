Feature: Quantum kernel methods
  As an ML researcher
  I want to generate quantum kernel matrices
  So that I can train classical kernel models with quantum feature maps

  Rule: Kernel matrix validity and reproducibility
    Scenario: Kernel matrix is symmetric with deterministic generation
      Given a deterministic feature-map circuit
      And dataset X with shape "{16,4}"
      And random seed is "1234"
      When I generate the kernel matrix K for X
      Then K has shape "{16,16}"
      And K is symmetric within tolerance "1.0e-6"
      And repeating generation with the same seed yields identical K

    Scenario: Kernel matrix is positive semidefinite within tolerance
      Given a deterministic feature-map circuit
      And dataset X with shape "{8,2}"
      When I generate the kernel matrix K for X
      Then minimum eigenvalue of K is greater than or equal to "-1.0e-6"

