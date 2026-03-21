defmodule NxQuantum.Providers.Config do
  @moduledoc """
  Typed configuration validation helpers for provider adapters.
  """

  alias NxQuantum.ProviderBridge.Errors
  alias NxQuantum.Providers.Redaction

  @spec fetch_required(atom() | String.t(), keyword(), [atom()], atom()) :: {:ok, map()} | {:error, map()}
  def fetch_required(provider, opts, keys, operation) when is_list(opts) and is_list(keys) do
    config = Keyword.get(opts, :provider_config, %{})

    missing = Enum.reject(keys, &Map.has_key?(config, &1))

    if missing == [] do
      {:ok, Map.take(config, keys)}
    else
      {:error,
       Errors.auth_error(operation, provider, :missing_provider_config,
         metadata: %{missing_keys: missing, provider_config: Redaction.redact(config)}
       )}
    end
  end
end
