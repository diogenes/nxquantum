Feature: Topology-aware transpilation interface
  As a hardware-oriented quantum engineer
  I want circuit transpilation aware of topology constraints
  So that logical circuits can be prepared for hardware with limited qubit connectivity

  Rule: Routing is deterministic and topology constrained

    Background:
      Given a logical circuit with two-qubit gates
      And a target topology coupling map is declared

    Scenario: Strict mode rejects non-native couplings with typed error
      Given transpiler mode is "strict"
      And the logical circuit requires an unavailable coupling edge
      When I run transpilation
      Then error "topology_violation" is returned
      And error metadata includes offending logical edge
      And error metadata includes target topology identifier

    Scenario: Insert-swaps mode uses deterministic shortest-path routing on a line topology
      Given transpiler mode is "insert_swaps"
      And restore_mapping policy is "false"
      And coupling map edges are "[(0,1), (1,2), (2,3)]"
      And the circuit contains gate "cnot(0,3)"
      When I run transpilation
      Then routing path "[0,1,2,3]" is selected
      And inserted swaps are exactly "[(0,1), (1,2)]"
      And routed interaction edge becomes "(2,3)"
      And transpilation report added_swap_gates is "2"

    Scenario: Equal-length routes are resolved by deterministic tie-break rule
      Given transpiler mode is "insert_swaps"
      And restore_mapping policy is "false"
      And coupling map edges are "[(0,1), (1,3), (0,2), (2,3)]"
      And the circuit contains gate "cnot(0,3)"
      When I run transpilation
      Then both candidate shortest paths have length "2"
      And tie-break strategy "lexicographic_path" is applied
      And routing path "[0,1,3]" is selected deterministically

    Scenario: Routing report exposes deterministic diagnostics
      Given transpiler mode is "insert_swaps"
      And a non-native interaction is routed successfully
      When I inspect the transpilation report
      Then report includes "added_swap_gates"
      And report includes "depth_delta"
      And report includes "logical_to_physical_map"
      And report includes "routed_edges"
      And report includes "topology_id"

    Scenario: Transpiled circuit preserves expectation semantics within tolerance
      Given strict and transpiled variants for a supported topology
      When I evaluate expectation on both circuits in simulation
      Then both expectations match within tolerance "1.0e-5"

    Scenario: All-to-all topology requires no routing overhead
      Given target topology is "all_to_all"
      When I run transpilation on the logical circuit
      Then no SWAP gate is inserted
      And transpilation report added_swap_gates is "0"
      And transpilation report routed_edges is empty
