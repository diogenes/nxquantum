defmodule NxQuantum.Providers.Redaction do
  @moduledoc """
  Deterministic secret redaction utilities for provider diagnostics.
  """

  @redacted "[REDACTED]"

  @sensitive_keys MapSet.new([
                    :token,
                    :auth_token,
                    :api_key,
                    :password,
                    :secret,
                    :secret_key,
                    :secret_access_key,
                    :access_key,
                    :access_key_id,
                    :authorization,
                    :client_secret,
                    :credentials
                  ])

  @spec redact(term()) :: term()
  def redact(value)

  def redact(%Nx.Tensor{} = tensor), do: tensor

  def redact(%{} = map) do
    Map.new(map, fn {key, val} -> {key, redact_pair(key, val)} end)
  end

  def redact(list) when is_list(list), do: Enum.map(list, &redact/1)
  def redact(value), do: value

  defp redact_pair(key, value) when is_atom(key) do
    if sensitive_key?(Atom.to_string(key)), do: @redacted, else: redact(value)
  end

  defp redact_pair(key, value) when is_binary(key) do
    if sensitive_key?(key), do: @redacted, else: redact(value)
  end

  defp redact_pair(_key, value), do: redact(value)

  defp sensitive_key?(key) when is_binary(key) do
    downcased = String.downcase(key)

    Enum.any?(@sensitive_keys, &(Atom.to_string(&1) == downcased)) or
      String.contains?(downcased, "token") or
      String.contains?(downcased, "secret") or
      String.contains?(downcased, "credential")
  end
end
