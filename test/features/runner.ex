defmodule NxQuantum.Features.Runner do
  @moduledoc false

  alias NxQuantum.Features.Parser
  alias NxQuantum.Features.Steps

  @spec run_feature(String.t()) :: :ok | no_return()
  def run_feature(path) do
    scenarios = Parser.parse_file(path)

    Enum.each(scenarios, fn scenario ->
      run_scenario(scenario)
    end)

    :ok
  end

  defp run_scenario(scenario) do
    base_ctx = %{
      feature: Path.basename(scenario.feature),
      scenario: scenario.name
    }

    Enum.reduce_while(Enum.with_index(scenario.steps, 1), base_ctx, fn {step, idx}, ctx ->
      case Steps.execute(step, ctx) do
        {:ok, updated} ->
          {:cont, updated}

        {:error, reason} ->
          raise """
          Feature step failed
          feature: #{scenario.feature}
          scenario: #{scenario.name}
          step ##{idx}: #{step.keyword} #{step.text}
          reason:
          #{reason}
          """
      end
    end)
  end
end
