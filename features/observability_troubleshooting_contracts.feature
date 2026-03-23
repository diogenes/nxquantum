Feature: Observability and troubleshooting contracts

  Rule: Troubleshooting depth is explicit and safe under custom metadata
    Scenario: Custom metadata policy is safe and deterministic
      Given custom observability metadata support is planned for provider and hybrid execution paths
      When custom metadata policies are delivered
      Then custom span and log attributes are allowlisted and policy-rejected when unsafe
      And custom attribute cardinality and key naming constraints are enforced deterministically
      And sensitive custom metadata is redacted deterministically across traces logs and metrics
      And all roadmap expectations for this feature are implementation-ready

    Scenario Outline: Lifecycle troubleshooting coverage exists for <operation> operations
      Given lifecycle troubleshooting telemetry is required for <operation> operations
      When troubleshooting telemetry for <operation> is implemented
      Then lifecycle telemetry includes <operation> phase timing retry metadata and terminal attribution fields
      And user correlation metadata propagates through <operation> observability events
      And troubleshooting bundles include <operation>-scoped trace log and metric evidence
      And all roadmap expectations for this feature are implementation-ready

      Examples:
        | operation    |
        | submit       |
        | poll         |
        | cancel       |
        | fetch_result |

    Scenario: Troubleshooting bundle contracts are machine-consumable
      Given troubleshooting bundle exports are required for incident triage workflows
      When troubleshooting bundle contracts are finalized
      Then troubleshooting bundles export correlated trace log and metric evidence with schema versioning
      And bundle metadata includes schema_version profile correlation_id and redaction_policy_version
      And observability adapter substitution preserves bundle contract shape
      And all roadmap expectations for this feature are implementation-ready
