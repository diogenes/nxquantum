defmodule NxQuantum.RoadmapStructureTest do
  use ExUnit.Case, async: true

  @roadmap_path Path.expand("../../docs/roadmap.md", __DIR__)
  @required_sections ["Goal:", "Implementation deliverables:", "Review gate:"]
  @required_fields ["- Status:", "- Intent:", "- Seats:", "- Depends on:", "- Target release:"]

  test "roadmap includes scope and template policy sections" do
    roadmap = File.read!(@roadmap_path)

    assert String.contains?(roadmap, "## Roadmap Scope Policy (Near-Term Execution Only)"),
           "missing roadmap scope policy section"

    assert String.contains?(roadmap, "## Milestone Template Policy (Required for All Unfinished Milestones)"),
           "missing milestone template policy section"
  end

  test "unfinished milestones follow the required milestone template" do
    milestones = unfinished_milestones(File.read!(@roadmap_path))

    assert milestones != [], "expected at least one unfinished milestone in docs/roadmap.md"

    Enum.each(milestones, fn {id, block} ->
      Enum.each(@required_fields, fn field ->
        assert String.contains?(block, "\n#{field}"),
               "Milestone #{id} is missing required field #{inspect(field)}"
      end)

      Enum.each(@required_sections, fn section ->
        assert String.contains?(block, "\n#{section}\n"),
               "Milestone #{id} is missing required section #{inspect(section)}"
      end)
    end)
  end

  defp unfinished_milestones(roadmap) do
    ~r/\n### (H\d+\.\d+) - [\s\S]*?(?=\n### |\n## |\n---|\z)/
    |> Regex.scan(roadmap)
    |> Enum.map(fn [block, id] -> {id, block} end)
    |> Enum.reject(fn {_id, block} -> String.contains?(block, "\n- Status: done") end)
  end
end
