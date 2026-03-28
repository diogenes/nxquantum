defmodule NxQuantum.Features.Steps.HybridQuantumAiBenchmarkPackSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  alias NxQuantum.Features.Steps.RoadmapContractSteps

  @scenario_families [
    "reranking quality delta",
    "reranking quality delta turboquant",
    "constrained optimization assistant",
    "fallback latency impact"
  ]

  @scenario_configs %{
    "Benchmark caveats and assumptions are explicit in reports" => %{
      given: "hybrid benchmark reports include operational caveats",
      when: "hybrid benchmark reports are published",
      expectations: [
        "benchmark outputs include caveat labels for noise provider and fallback-path assumptions",
        "caveat sections distinguish measured behavior from unsupported or simulated paths",
        "published guides map benchmark evidence to migration and rollout decision workflows"
      ]
    },
    "Benchmark artifact bundles are decision-usable" => %{
      given: "migration teams rely on benchmark artifacts for go no-go decisions",
      when: "benchmark pack artifacts are finalized",
      expectations: [
        "artifact bundles include scenario metadata baseline metadata and confidence notes",
        "report formats include machine-readable summary and human-readable narrative sections",
        "artifact schemas are versioned for CI ingestion and trend tracking"
      ]
    }
  }

  @impl true
  def feature, do: "hybrid_quantum_ai_benchmark_pack.feature"

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
           ~r/^Hybrid scenario family (.+) is reproducible and baseline-anchored$/,
           scenario,
           capture: :all_but_first
         ) do
      [scenario_family] ->
        if scenario_family in @scenario_families do
          scenario_family_config(scenario_family)
        else
          raise "unsupported hybrid scenario family: #{scenario_family}"
        end

      _ ->
        Map.fetch!(@scenario_configs, scenario)
    end
  end

  defp scenario_family_config(scenario_family) do
    %{
      given: "hybrid benchmark scenario #{scenario_family} is part of the evaluation pack",
      when: "#{scenario_family} benchmark scenario is implemented",
      expectations: [
        "benchmark baseline and report scripts consume the same dataset manifests and pinned seeds for #{scenario_family}",
        "each #{scenario_family} scenario reports classical baseline metrics with version-pinned environment metadata",
        "CI benchmark guards enforce regression thresholds for #{scenario_family} quality latency and fallback behavior"
      ]
    }
  end
end
