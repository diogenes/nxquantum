defmodule NxQuantum.Observability.Fingerprint do
  @moduledoc false

  @spec generate(map(), keyword()) :: String.t()
  def generate(input, opts \\ []) when is_map(input) do
    version = Keyword.get(opts, :version, "v1")

    canonical =
      input
      |> canonicalize()
      |> :erlang.term_to_binary([:deterministic])

    hash = :sha256 |> :crypto.hash(canonical) |> Base.encode16(case: :lower)
    "#{version}:#{hash}"
  end

  defp canonicalize(value) when is_map(value) do
    value
    |> Enum.map(fn {k, v} -> {canonicalize(k), canonicalize(v)} end)
    |> Enum.sort()
  end

  defp canonicalize(value) when is_list(value), do: Enum.map(value, &canonicalize/1)
  defp canonicalize(value), do: value
end
