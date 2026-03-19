Feature: Dynamic execution and hardware bridge contracts
  As a quantum ML engineer
  I want supported dynamic-circuit execution and typed provider lifecycle contracts
  So that I can run hybrid workflows against hardware-oriented execution boundaries

  Rule: Dynamic execution subset is deterministic and typed
    Background:
      Given dynamic execution mode is enabled for the supported v0.4 subset
      And runtime profile "cpu_portable" is configured

    Scenario: Supported measurement -> conditional branch executes deterministically
      Given a dynamic IR graph with one measurement and one conditional gate branch
      When I execute the dynamic circuit twice with the same seed and inputs
      Then both outputs are identical within tolerance
      And execution metadata includes branch decisions and register trace

    Scenario: Unsupported dynamic node returns typed execution error
      Given a dynamic IR graph containing an unsupported dynamic node type
      When I execute the dynamic circuit
      Then error "unsupported_dynamic_node" is returned
      And error metadata includes the unsupported node type

  Rule: Provider lifecycle contracts are explicit and deterministic
    Scenario: Job lifecycle transitions follow typed states
      Given a provider adapter implementing submit, poll, cancel, and fetch_result
      When I submit a circuit execution job
      Then the initial state is "submitted"
      And polling transitions through typed lifecycle states deterministically
      And final result retrieval returns a typed payload contract

    Scenario: Provider transport failure maps to typed bridge error
      Given a provider adapter experiences a transport timeout during poll
      When I poll job status
      Then error "provider_transport_error" is returned
      And error metadata includes operation "poll" and provider identifier

  Rule: Calibration payload contracts integrate with mitigation hooks
    Scenario: Valid calibration payload is accepted by mitigation bridge hooks
      Given a provider readout calibration payload with valid schema
      When I execute mitigation-aware hardware workflow
      Then calibration payload is accepted
      And mitigation metadata includes calibration version and source

    Scenario: Invalid calibration payload returns typed diagnostics
      Given a provider readout calibration payload with invalid shape
      When I execute mitigation-aware hardware workflow
      Then error "invalid_calibration_payload" is returned
      And error metadata includes expected and received calibration shapes
