defmodule NxQuantum.Features.Steps.QuantumAiToolContractsSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  alias NxQuantum.Features.Steps.RoadmapContractSteps

  @tool_handlers ["quantum-kernel reranking", "quantum_kernel_rerank.v1", "constrained optimization helper"]
  @transport_models ["sync request-response", "async event delivery"]

  @scenario_configs %{
    "Envelope schemas are versioned and machine-consumable" => %{
      given: "quantum AI tool envelope contracts are required for production integrations",
      when: "AI envelope schemas are delivered",
      expectations: [
        "request result error and trace metadata envelopes are versioned and machine-readable",
        "envelope schemas include schema_version tool_name correlation_id and idempotency_key fields",
        "contract tests validate envelope parsing schema compliance and typed error mapping"
      ]
    }
  }

  @impl true
  def feature, do: "quantum_ai_tool_contracts.feature"

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
           ~r/^Tool handler (.+) contract is deterministic$/,
           scenario,
           capture: :all_but_first
         ) do
      [tool_handler] ->
        if tool_handler in @tool_handlers do
          tool_handler_config(tool_handler)
        else
          raise "unsupported tool handler in scenario: #{tool_handler}"
        end

      _ ->
        transport_or_static_config(scenario)
    end
  end

  defp transport_or_static_config(scenario) do
    case Regex.run(
           ~r/^Transport model (.+) remains adapter-driven behind stable ports$/,
           scenario,
           capture: :all_but_first
         ) do
      [transport_model] ->
        if transport_model in @transport_models do
          transport_model_config(transport_model)
        else
          raise "unsupported transport model in scenario: #{transport_model}"
        end

      _ ->
        Map.fetch!(@scenario_configs, scenario)
    end
  end

  defp tool_handler_config(tool_handler) do
    %{
      given: "AI tool handler #{tool_handler} is part of the public NxQuantum AI surface",
      when: "#{tool_handler} handler implementation is delivered",
      expectations: [
        "tool handler #{tool_handler} returns typed result envelopes with deterministic fallback outcomes",
        "handler #{tool_handler} emits capability diagnostics when required provider features are unavailable",
        "handler #{tool_handler} documents input output and failure contracts in public docs"
      ]
    }
  end

  defp transport_model_config(transport_model) do
    %{
      given: "AI tool transport model #{transport_model} is required for integration",
      when: "AI tool transport adapters for #{transport_model} are implemented",
      expectations: [
        "AI tool transport ports define #{transport_model} contract semantics behind adapters",
        "reference adapters include MCP JSON-RPC sync transport and CloudEvents async transport",
        "transport adapter substitution preserves typed envelope compatibility"
      ]
    }
  end
end
