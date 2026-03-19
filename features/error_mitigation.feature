Feature: Pluggable error mitigation pipeline
  As a quantum ML researcher
  I want composable mitigation passes on primitive outputs
  So that noisy results are more useful for model training and evaluation

  Rule: Mitigation pipeline is deterministic and composable
    Background:
      Given primitive output tensors from Sampler or Estimator
      And mitigation pipeline API is enabled

    Scenario: Readout mitigation pass transforms sampled probabilities deterministically
      Given a calibration matrix for readout mitigation
      When I apply readout mitigation twice to the same input
      Then both mitigated outputs are identical
      And output probability mass remains normalized within tolerance

    Scenario: ZNE linear extrapolation produces deterministic expectation correction
      Given noise scaling factors "[1.0, 2.0, 3.0]"
      When I apply ZNE linear extrapolation
      Then corrected expectation is deterministic for fixed seed and inputs
      And extrapolation metadata includes scale factors and fit diagnostics

    Scenario: Pipeline composition order is explicit and preserved
      Given mitigation pipeline "[readout, zne_linear]"
      When I execute the pipeline
      Then pass execution order matches the declared pipeline order
      And output includes per-pass trace metadata

    Scenario: Invalid calibration matrix returns typed mitigation error
      Given a non-invertible or shape-mismatched calibration matrix
      When I apply readout mitigation
      Then error "invalid_mitigation_input" is returned
      And error metadata includes matrix shape diagnostics
