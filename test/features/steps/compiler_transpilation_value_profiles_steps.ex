defmodule NxQuantum.Features.Steps.CompilerTranspilationValueProfilesSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  alias NxQuantum.Features.Steps.RoadmapContractSteps

  @profiles ["depth_sensitive", "latency_sensitive", "calibration_aware"]

  @scenario_configs %{
    "Provider-aware transpilation remains behind stable capability ports" => %{
      given: "provider-aware transpilation policies are required for production execution",
      when: "provider policy adapters are implemented",
      expectations: [
        "provider-aware transpilation policies remain behind explicit ports and capability checks",
        "unsupported provider policy requests fail fast with typed diagnostics",
        "provider policy metadata is machine-readable and deterministic across adapters"
      ]
    },
    "Semantic safety is preserved across strategy variants" => %{
      given: "strategy variants include layout routing and cost-model alternatives",
      when: "equivalent circuits are compiled under each supported profile",
      expectations: [
        "semantic equivalence is acceptance-tested and property-tested across supported profiles",
        "equivalence assertions include observable tolerance budgets and normalization invariants",
        "regression suites guard against optimization-induced behavioral drift"
      ]
    }
  }

  @impl true
  def feature, do: "compiler_transpilation_value_profiles.feature"

  @impl true
  def execute(step, ctx) do
    config = scenario_config(ctx)
    expectations = Map.fetch!(config, :expectations)

    ctx
    |> RoadmapContractSteps.bootstrap(expectations)
    |> then(&RoadmapContractSteps.execute(step, &1, config))
  end

  defp scenario_config(%{scenario: scenario}) do
    case Regex.run(~r/^Compilation profile (.+) is selectable and diagnosed$/, scenario, capture: :all_but_first) do
      [profile] ->
        if profile in @profiles do
          profile_config(profile)
        else
          raise "unsupported profile in scenario: #{profile}"
        end

      _ ->
        Map.fetch!(@scenario_configs, scenario)
    end
  end

  defp profile_config(profile) do
    %{
      given: "compilation profile #{profile} is part of public compiler contracts",
      when: "compilation profile #{profile} is requested for a topology-constrained circuit",
      expectations: [
        "profile selection is configurable through stable public compiler or transpiler options",
        "compilation diagnostics include selected profile cost model and rejected alternatives",
        "profile execution emits topology pressure indicators and routing summary fields"
      ]
    }
  end
end
