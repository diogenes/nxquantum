defmodule NxQuantum.Features.Steps.RoadmapContractSteps do
  @moduledoc false

  import ExUnit.Assertions

  alias NxQuantum.Features.StepExecutor

  @final_step "all roadmap expectations for this feature are implementation-ready"

  @spec execute(map(), map(), %{given: String.t(), when: String.t(), expectations: [String.t()]}) :: map()
  def execute(step, ctx, %{given: given, when: when_text, expectations: expectations}) do
    handlers = [
      &handle_setup(&1, &2, given),
      &handle_execution(&1, &2, when_text),
      &handle_expectation(&1, &2, expectations),
      &handle_final/2
    ]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} ->
        updated

      :unhandled ->
        raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx, given) when text == given do
    {:handled, Map.put(ctx, :roadmap_given_seen?, true)}
  end

  defp handle_setup(_step, _ctx, _given), do: :unhandled

  defp handle_execution(%{text: text}, ctx, when_text) when text == when_text do
    {:handled, Map.put(ctx, :roadmap_when_seen?, true)}
  end

  defp handle_execution(_step, _ctx, _when_text), do: :unhandled

  defp handle_expectation(%{text: text}, ctx, expectations) do
    if text in expectations do
      seen = Map.get(ctx, :roadmap_expectations_seen, MapSet.new())
      {:handled, Map.put(ctx, :roadmap_expectations_seen, MapSet.put(seen, text))}
    else
      :unhandled
    end
  end

  defp handle_final(%{text: @final_step}, ctx) do
    assert Map.get(ctx, :roadmap_given_seen?, false)
    assert Map.get(ctx, :roadmap_when_seen?, false)

    expectations = Map.get(ctx, :roadmap_expected, [])
    seen = Map.get(ctx, :roadmap_expectations_seen, MapSet.new())

    assert MapSet.new(expectations) == seen

    {:handled, ctx}
  end

  defp handle_final(_step, _ctx), do: :unhandled

  @spec bootstrap(map(), [String.t()]) :: map()
  def bootstrap(ctx, expectations) do
    Map.put(ctx, :roadmap_expected, expectations)
  end

  @spec final_step() :: String.t()
  def final_step, do: @final_step
end
