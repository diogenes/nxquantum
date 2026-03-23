Feature: Provider live execution contracts

  Rule: Live execution keeps the same public contract shape as deterministic fixture execution
    Scenario Outline: Provider <provider> live lifecycle contract is executable
      Given <provider> live execution is planned behind provider bridge contracts
      When <provider> live adapter delivery is completed
      Then <provider> live path executes submit poll cancel and fetch_result through authenticated transport calls
      And <provider> lifecycle status mapping covers queued running completed cancelled and failed states
      And <provider> live results preserve schema_version request_id correlation_id idempotency_key and provider_job_id fields
      And all roadmap expectations for this feature are implementation-ready

      Examples:
        | provider      |
        | IBM Runtime   |
        | AWS Braket    |
        | Azure Quantum |

    Scenario: Transport modes stay contract-compatible across fixture and live lanes
      Given provider execution supports fixture live_smoke and live transport modes
      When transport mode contracts are finalized
      Then fixture live_smoke and live modes expose identical schema_version request_id correlation_id and idempotency_key envelope fields
      And unsupported live mode requests fail fast with typed provider capability diagnostics
      And transport mode selection remains explicit and never silently falls back between providers
      And all roadmap expectations for this feature are implementation-ready

    Scenario: Live diagnostics and replay fixture capture are standardized
      Given live provider diagnostics are required for troubleshooting and deterministic replay
      When live diagnostics contracts are implemented
      Then provider metadata includes queue phase terminal diagnostics provider_job_id and provider_error_code fields
      And provider-specific transport failures map to stable typed NxQuantum error codes with retryability metadata
      And live runs can be captured into replay fixtures with provenance metadata for deterministic CI lanes
      And all roadmap expectations for this feature are implementation-ready

    Scenario: CI policy keeps fixture determinism while enabling optional live verification
      Given CI policy includes deterministic fixture gates and optional credentialed live lanes
      When provider execution quality gates are defined
      Then fixture lanes are mandatory and deterministic for submit poll cancel and fetch_result contract tests
      And live-smoke lanes are optional and require explicit credentials and target allowlists
      And release evidence reports fixture parity and live lane outcomes without changing public contract shape
      And all roadmap expectations for this feature are implementation-ready
