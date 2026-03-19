Feature: Primitives API (Estimator and Sampler)
  As an ML engineer
  I want high-level estimator and sampler primitives
  So that I can build hardware-agnostic QML pipelines without handling low-level raw simulator internals

  Rule: Deterministic primitive contracts
    Background:
      Given a parameterized quantum circuit with declared observables
      And runtime profile "cpu_portable" is configured

    Scenario: Estimator returns deterministic expectation values for the same seed and inputs
      When I run the Estimator primitive twice with the same parameters and seed
      Then both expectation outputs are identical within numeric tolerance
      And the result includes metadata for runtime profile and execution mode

    Scenario: Sampler returns deterministic shot outputs for the same seed and inputs
      When I run the Sampler primitive twice with the same shots and seed
      Then both sampled distributions are identical
      And the total sample count equals the configured shots

    Scenario: Multi-observable Estimator execution preserves output ordering
      Given an observable list "[:pauli_x, :pauli_y, :pauli_z]"
      When I run a single Estimator request with that observable list
      Then the output tensor preserves the input observable order
      And output shape matches the declared observable count

    Scenario: Invalid observable returns typed primitive error
      Given an unsupported observable identifier
      When I run the Estimator primitive
      Then error "unsupported_observable" is returned
      And error metadata includes the invalid observable identifier
