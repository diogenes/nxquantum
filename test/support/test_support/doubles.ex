defmodule NxQuantum.TestSupport.Doubles do
  @moduledoc false

  def deterministic_detector(overrides \\ %{}) do
    fn profile ->
      Map.get(overrides, profile, profile == :cpu_portable)
    end
  end
end
