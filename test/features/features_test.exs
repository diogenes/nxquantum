defmodule NxQuantum.FeaturesTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Features.Runner

  for feature <- Path.wildcard("features/*.feature") do
    test "executes #{Path.basename(feature)} with step implementations" do
      assert :ok = Runner.run_feature(unquote(feature))
    end
  end
end
