Feature: Circuit optimization pipeline
  As a performance-focused engineer
  I want deterministic circuit optimization passes
  So that I can reduce execution cost without changing semantics

  Rule: Optimization preserves expectation semantics
    Scenario: Optimized and original circuits match numerically
      Given a circuit with redundant and cancelable gate sequences
      And numerical tolerance is "1.0e-5"
      When I optimize the circuit with passes "simplify,fuse,cancel"
      And I evaluate expectation before and after optimization
      Then the optimized expectation matches the original within tolerance

  Rule: Optimization reports measurable simplification
    Scenario: Gate count reduction is exposed in optimization report
      Given a circuit with repeated adjacent single-qubit rotations
      When I optimize the circuit with passes "fuse,cancel"
      Then optimization report includes "gate_count_before"
      And optimization report includes "gate_count_after"
      And "gate_count_after" is less than "gate_count_before"

