defmodule NxQuantum.Features.Steps.ObservabilityTroubleshootingContractsSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  alias NxQuantum.Features.Steps.RoadmapContractSteps

  @operations ["submit", "poll", "cancel", "fetch_result"]

  @scenario_configs %{
    "Custom metadata policy is safe and deterministic" => %{
      given: "custom observability metadata support is planned for provider and hybrid execution paths",
      when: "custom metadata policies are delivered",
      expectations: [
        "custom span and log attributes are allowlisted and policy-rejected when unsafe",
        "custom attribute cardinality and key naming constraints are enforced deterministically",
        "sensitive custom metadata is redacted deterministically across traces logs and metrics"
      ]
    },
    "Troubleshooting bundle contracts are machine-consumable" => %{
      given: "troubleshooting bundle exports are required for incident triage workflows",
      when: "troubleshooting bundle contracts are finalized",
      expectations: [
        "troubleshooting bundles export correlated trace log and metric evidence with schema versioning",
        "bundle metadata includes schema_version profile correlation_id and redaction_policy_version",
        "observability adapter substitution preserves bundle contract shape"
      ]
    }
  }

  @impl true
  def feature, do: "observability_troubleshooting_contracts.feature"

  @impl true
  def execute(step, ctx) do
    config = scenario_config(ctx)
    expectations = Map.fetch!(config, :expectations)

    ctx
    |> RoadmapContractSteps.bootstrap(expectations)
    |> then(&RoadmapContractSteps.execute(step, &1, config))
  end

  defp scenario_config(%{scenario: scenario}) do
    case Regex.run(
           ~r/^Lifecycle troubleshooting coverage exists for (.+) operations$/,
           scenario,
           capture: :all_but_first
         ) do
      [operation] ->
        if operation in @operations do
          operation_config(operation)
        else
          raise "unsupported operation in scenario: #{operation}"
        end

      _ ->
        Map.fetch!(@scenario_configs, scenario)
    end
  end

  defp operation_config(operation) do
    %{
      given: "lifecycle troubleshooting telemetry is required for #{operation} operations",
      when: "troubleshooting telemetry for #{operation} is implemented",
      expectations: [
        "lifecycle telemetry includes #{operation} phase timing retry metadata and terminal attribution fields",
        "user correlation metadata propagates through #{operation} observability events",
        "troubleshooting bundles include #{operation}-scoped trace log and metric evidence"
      ]
    }
  end
end
