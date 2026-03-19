Feature: Scale and performance maturity
  As an ML engineer
  I want deterministic scale paths and reproducible performance evidence
  So that I can trust NxQuantum in larger production-style workloads

  Rule: Large-scale simulator fallback strategy
    Scenario: Large qubit workload falls back to configured large-scale simulator path
      Given simulation strategy is "auto"
      And qubit count exceeds the dense state-vector threshold
      When I execute the circuit
      Then large-scale fallback path is selected deterministically
      And execution report includes selected fallback strategy

    Scenario: Strict dense-only strategy fails with typed scaling error
      Given simulation strategy is "dense_only"
      And qubit count exceeds the dense state-vector threshold
      When I execute the circuit
      Then error "scaling_limit_exceeded" is returned
      And error metadata includes qubit count and configured strategy

  Rule: Batched execution performance contracts
    Scenario: Batch output remains equivalent while throughput improves for batch >= 32
      Given batch size is "32"
      And a scalar-loop reference implementation is available
      When I execute batched and scalar workflows on the same profile
      Then outputs match within tolerance
      And batched throughput is greater than scalar-loop throughput

    Scenario: Batch performance report includes latency throughput and memory metrics
      Given benchmark matrix generation is enabled
      When I run benchmark suite for batch sizes "1,8,32,128"
      Then report includes latency metrics per batch size
      And report includes throughput metrics per batch size
      And report includes memory metrics per batch size

  Rule: Performance regression thresholds in CI
    Scenario: CI marks regression when throughput drops beyond allowed threshold
      Given baseline benchmark thresholds are versioned
      And current benchmark run exceeds allowed regression threshold
      When CI evaluates performance gates
      Then performance gate status is "failed"
      And CI output includes the regressed metric and delta
