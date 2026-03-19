Feature: Batched parameterized quantum circuits
  As an ML practitioner
  I want batched parameter execution for one circuit structure
  So that hybrid training loops can run efficiently on accelerated tensor backends

  Rule: Batch is a first-class execution dimension
    Background:
      Given a fixed variational circuit topology
      And batched parameters are provided as an Nx tensor

    Scenario: Batched Estimator output matches scalar-loop reference
      When I compute expectations in batched mode
      And I compute the same expectations using a scalar loop baseline
      Then batched and scalar results match within tolerance

    Scenario: Batch size one is equivalent to scalar mode
      Given batch size is "1"
      When I run batched execution
      Then output values match scalar API values
      And output shape follows the batch contract

    Scenario: Batched Sampler is deterministic for fixed seed
      Given shots is "2048"
      And seed is "77"
      When I run batched Sampler twice
      Then both sampled batch outputs are identical

    Scenario: Invalid batch shape returns typed error
      Given parameter tensor shape does not match circuit parameter schema
      When I run batched Estimator
      Then error "invalid_batch_shape" is returned
      And error metadata includes expected and received shapes
