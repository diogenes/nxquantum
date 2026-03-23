defmodule NxQuantum.RoadmapStructureTest do
  use ExUnit.Case, async: true

  @roadmap_path Path.expand("../../docs/roadmap.md", __DIR__)
  @unfinished_phases 14..21
  @required_sections ["Goal:", "Implementation deliverables:"]

  test "roadmap includes scope and template policy sections" do
    roadmap = File.read!(@roadmap_path)

    assert String.contains?(roadmap, "## Roadmap Scope Policy (Near-Term Execution Only)"),
           "missing roadmap scope policy section"

    assert String.contains?(roadmap, "## Milestone Template Policy (Required for All Unfinished Phases)"),
           "missing milestone template policy section"
  end

  test "unfinished phases follow the required milestone template" do
    roadmap = File.read!(@roadmap_path)

    Enum.each(@unfinished_phases, fn phase ->
      block = phase_block!(roadmap, phase)

      Enum.each(@required_sections, fn section ->
        assert String.contains?(block, "\n#{section}\n"),
               "Phase #{phase} is missing required section #{inspect(section)}"
      end)

      assert Regex.match?(~r/\nMilestone [A-Z]/, block),
             "Phase #{phase} is missing a milestone review gate"
    end)
  end

  defp phase_block!(roadmap, phase) do
    pattern = ~r/## Phase #{phase} -[\s\S]*?(?=\n## Phase \d+ -|\n## Proposed Backlog|\z)/

    case Regex.run(pattern, roadmap) do
      [block] ->
        block

      _ ->
        flunk("could not find Phase #{phase} section in docs/roadmap.md")
    end
  end
end

