Feature: Dynamic circuit IR foundation
  As a quantum compiler developer
  I want dynamic-circuit IR nodes for classical control flow
  So that NxQuantum can evolve toward mid-circuit measurement and feed-forward execution

  Rule: Dynamic IR structures are validated before execution
    Background:
      Given experimental dynamic-circuit IR mode is enabled

    Scenario: Mid-circuit measurement can write to a classical register node
      Given a measurement node targeting classical register "c0"
      When I validate dynamic IR
      Then validation succeeds
      And IR graph includes typed node metadata for register write

    Scenario: Conditional gate node can reference prior classical measurement
      Given a conditional gate node controlled by classical register "c0"
      And the register is produced earlier in the IR graph
      When I validate dynamic IR
      Then validation succeeds
      And conditional dependency is recorded in IR metadata

    Scenario: Invalid classical reference returns typed validation error
      Given a conditional gate references missing register "c_missing"
      When I validate dynamic IR
      Then error "invalid_dynamic_ir" is returned
      And error metadata includes missing register identifier

    Scenario: v0.3 execution boundary is explicit
      Given a dynamic IR circuit containing classical branches
      When I request runtime execution
      Then error "dynamic_execution_not_supported" is returned
      And message indicates dynamic execution is planned for a future release
