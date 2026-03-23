defmodule NxQuantum.Features.Steps.ProviderLiveExecutionContractsSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  alias NxQuantum.Features.Steps.RoadmapContractSteps

  @providers ["IBM Runtime", "AWS Braket", "Azure Quantum"]

  @scenario_configs %{
    "Transport modes stay contract-compatible across fixture and live lanes" => %{
      given: "provider execution supports fixture live_smoke and live transport modes",
      when: "transport mode contracts are finalized",
      expectations: [
        "fixture live_smoke and live modes expose identical schema_version request_id correlation_id and idempotency_key envelope fields",
        "unsupported live mode requests fail fast with typed provider capability diagnostics",
        "transport mode selection remains explicit and never silently falls back between providers"
      ]
    },
    "Live diagnostics and replay fixture capture are standardized" => %{
      given: "live provider diagnostics are required for troubleshooting and deterministic replay",
      when: "live diagnostics contracts are implemented",
      expectations: [
        "provider metadata includes queue phase terminal diagnostics provider_job_id and provider_error_code fields",
        "provider-specific transport failures map to stable typed NxQuantum error codes with retryability metadata",
        "live runs can be captured into replay fixtures with provenance metadata for deterministic CI lanes"
      ]
    },
    "CI policy keeps fixture determinism while enabling optional live verification" => %{
      given: "CI policy includes deterministic fixture gates and optional credentialed live lanes",
      when: "provider execution quality gates are defined",
      expectations: [
        "fixture lanes are mandatory and deterministic for submit poll cancel and fetch_result contract tests",
        "live-smoke lanes are optional and require explicit credentials and target allowlists",
        "release evidence reports fixture parity and live lane outcomes without changing public contract shape"
      ]
    }
  }

  @impl true
  def feature, do: "provider_live_execution_contracts.feature"

  @impl true
  def execute(step, ctx) do
    config = scenario_config(ctx)
    expectations = Map.fetch!(config, :expectations)

    ctx
    |> RoadmapContractSteps.bootstrap(expectations)
    |> then(&RoadmapContractSteps.execute(step, &1, config))
  end

  defp scenario_config(%{scenario: scenario}) do
    case Regex.run(~r/^Provider (.+) live lifecycle contract is executable$/, scenario, capture: :all_but_first) do
      [provider] ->
        if provider in @providers do
          provider_config(provider)
        else
          raise "unsupported provider in scenario: #{provider}"
        end

      _ ->
        Map.fetch!(@scenario_configs, scenario)
    end
  end

  defp provider_config(provider) do
    %{
      given: "#{provider} live execution is planned behind provider bridge contracts",
      when: "#{provider} live adapter delivery is completed",
      expectations: [
        "#{provider} live path executes submit poll cancel and fetch_result through authenticated transport calls",
        "#{provider} lifecycle status mapping covers queued running completed cancelled and failed states",
        "#{provider} live results preserve schema_version request_id correlation_id idempotency_key and provider_job_id fields"
      ]
    }
  end
end
