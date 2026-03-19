Feature: Hybrid classical-quantum training
  As an ML engineer
  I want to embed quantum expectations in an Axon training step
  So that I can optimize hybrid models end-to-end using native autodiff and batching

  Rule: Differentiable nodes within Nx.defn
    Background:
      # Deterministic reference model:
      # - One-qubit ansatz: |0> -> RY(theta) -> expectation(Z)
      # - Analytical expectation: E(theta) = cos(theta)
      # - Loss: L(theta) = (E(theta) - y)^2
      # - Gradient: dL/dtheta = -2 * (cos(theta) - y) * sin(theta)
      Given deterministic execution mode is enabled
      And runtime profile "cpu_portable" is configured
      And numerical tolerance is "1.0e-4"

    Scenario Outline: Forward pass matches analytical expectation for fixed theta values
      Given a one-qubit variational circuit with RY(theta)
      And theta is a tensor with value "<theta>"
      When I evaluate expectation of Pauli-Z on wire 0 within defn
      Then the expectation tensor should have value approximately "<expected_expectation>"

      Examples:
        | theta              | expected_expectation |
        | 0.0                | 1.0                  |
        | 1.5707963267948966 | 0.0                  |
        | 3.141592653589793  | -1.0                 |

    Scenario: Gradients are computed automatically by Nx.grad
      Given a one-qubit variational circuit with RY(theta)
      And theta is a tensor with value "1.5707963267948966"
      And a loss function computing squared error to target "1.0"
      When I request the gradient of the loss with respect to theta using Nx.grad
      Then gradient for theta should be approximately "2.0"
      And no custom gradient rules are required

    Scenario: One explicit SGD step updates theta deterministically
      Given a one-qubit variational circuit with RY(theta)
      And theta is a tensor with value "1.5707963267948966"
      And target y is "1.0"
      And learning rate is "0.1"
      And loss is mean squared error over a single sample
      When I run exactly one SGD step
      Then gradient for theta should be approximately "2.0"
      And updated theta should be approximately "1.3707963267948966"
      And updated prediction should be approximately "0.1986693307950612"
      And updated loss should be approximately "0.6426439152043817"

  Rule: Reproducibility by random seed
    Scenario: Same seed produces identical initialization, gradients, and updates
      Given a hybrid model with one classical dense layer and one quantum expectation head
      And random seed is "42"
      And shuffled batch order seed is "42"
      And identical training data and optimizer configuration
      When I run one training step twice from a clean state
      Then initial parameters from both runs are exactly equal
      And computed gradients from both runs are exactly equal
      And updated parameters from both runs are exactly equal

    Scenario: Different seeds produce different initialization while staying deterministic per run
      Given a hybrid model with one classical dense layer and one quantum expectation head
      And first run seed is "7"
      And second run seed is "99"
      And identical training data and optimizer configuration
      When I run one training step for each seed from a clean state
      Then initial parameters between runs are not equal
      And each run is reproducible when repeated with its own seed

  Rule: Batched execution for ML pipelines
    Scenario: Batched evaluation with explicit encoding and expected values
      Given a one-qubit circuit where input x is encoded as theta = x
      And a batch input tensor x with shape "{3,1}" and values "[0.0, 1.5707963267948966, 3.141592653589793]"
      When I evaluate expectation of Pauli-Z within defn
      Then output expectation tensor should have shape "{3}"
      And output expectation values should be approximately "[1.0, 0.0, -1.0]"

  Rule: Axon integration
    Scenario: End-to-end deterministic train_step with classical preprocessor and quantum head
      Given a hybrid Axon model with a classical dense preprocessor and a quantum_layer
      And dense preprocessor parameters are frozen and deterministic
      And the quantum_layer wraps a variational circuit with trainable theta offset
      And optimizer is deterministic SGD with learning rate "0.1"
      When I run one Axon.train_step on identical seeded setup
      Then the quantum parameters are updated deterministically
      And the training loss after the step is lower than before the step
