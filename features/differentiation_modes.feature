Feature: Differentiation modes for variational circuits
  As an ML researcher
  I want multiple gradient strategies for quantum circuits
  So that I can balance correctness, portability, and performance

  Rule: Gradient mode compatibility and consistency
    Background:
      Given a one-qubit variational circuit with RY(theta)
      And theta is "1.234"
      And numerical tolerance is "1.0e-4"

    Scenario Outline: Gradient modes agree within tolerance
      Given gradient mode "<mode>" is selected
      When I compute the gradient of expectation loss with respect to theta
      Then the gradient should be approximately "<expected_gradient>"

      Examples:
        | mode            | expected_gradient |
        | backprop        | -0.9438182        |
        | parameter_shift | -0.9438182        |
        | adjoint         | -0.9438182        |

    Scenario: Adjoint mode with deterministic 2-parameter circuit matches parameter-shift baseline
      Given gradient mode "adjoint" is selected
      And a two-qubit circuit RX(theta_0) -> CNOT(0,1) -> RY(theta_1) is configured
      And theta vector is "[0.7, -0.3]"
      When I compute gradients with adjoint and parameter_shift
      Then each gradient component should match within "1.0e-4"
      And both modes should return finite scalar loss

    Scenario: Unsupported adjoint gate returns typed error with operation name
      Given gradient mode "adjoint" is selected
      And the circuit includes an unsupported operation for adjoint mode
      When I compute gradients
      Then error "unsupported_gradient_mode" is returned
      And the error includes the unsupported operation name

    Scenario: Adjoint mode without circuit builder returns typed contract error
      Given gradient mode "adjoint" is selected
      And no circuit builder is provided
      When I compute gradients
      Then error "adjoint_requires_circuit_builder" is returned
