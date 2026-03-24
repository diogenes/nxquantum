defmodule NxQuantum.Observability.MetadataPolicy do
  @moduledoc false

  @allowed_key_regex ~r/^[a-z0-9_.-]+$/
  @blocked_prefixes ["secret", "token", "authorization", "credential", "password"]
  @max_keys 12

  @spec validate_and_redact(map()) :: {:ok, map()} | {:error, map()}
  def validate_and_redact(metadata) when is_map(metadata) do
    keys = Map.keys(metadata)

    cond do
      length(keys) > @max_keys ->
        {:error, %{code: :observability_cardinality_violation, reason: :too_many_custom_attributes}}

      Enum.any?(keys, &(not valid_key?(&1))) ->
        {:error, %{code: :observability_invalid_custom_metadata_key}}

      true ->
        {:ok, redact(metadata)}
    end
  end

  def validate_and_redact(_other), do: {:error, %{code: :observability_invalid_custom_metadata, reason: :not_a_map}}

  defp redact(map) do
    Map.new(map, fn {key, value} ->
      key_string = to_string(key)

      if blocked_key?(key_string) do
        {key_string, "[REDACTED]"}
      else
        {key_string, redact_value(value)}
      end
    end)
  end

  defp redact_value(%{} = nested), do: redact(nested)
  defp redact_value(list) when is_list(list), do: Enum.map(list, &redact_value/1)
  defp redact_value(value), do: value

  defp valid_key?(key) do
    key_string = to_string(key)
    String.match?(key_string, @allowed_key_regex)
  end

  defp blocked_key?(key) do
    lowered = String.downcase(key)
    Enum.any?(@blocked_prefixes, &String.contains?(lowered, &1))
  end
end
