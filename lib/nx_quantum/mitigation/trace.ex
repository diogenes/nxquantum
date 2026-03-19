defmodule NxQuantum.Mitigation.Trace do
  @moduledoc false

  @spec append(map(), map()) :: map()
  def append(metadata, trace) do
    existing = Map.get(metadata, :mitigation_trace, [])
    Map.put(metadata, :mitigation_trace, existing ++ [trace])
  end
end
