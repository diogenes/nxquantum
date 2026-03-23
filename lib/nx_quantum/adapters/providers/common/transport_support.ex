defmodule NxQuantum.Adapters.Providers.Common.TransportSupport do
  @moduledoc false

  @live_smoke_env "NXQ_PROVIDER_LIVE_SMOKE"

  @spec readiness(atom() | String.t(), keyword(), [atom()], atom()) :: map()
  def readiness(provider, opts, required_config_keys, operation) when is_list(opts) and is_list(required_config_keys) do
    provider_config = Keyword.get(opts, :provider_config, %{})
    requested_mode = requested_mode(opts, provider_config)
    env_enabled = env_enabled?(provider)
    missing_config_keys = Enum.reject(required_config_keys, &Map.has_key?(provider_config, &1))
    live_smoke_ready? = requested_mode == :live_smoke and env_enabled and missing_config_keys == []

    %{
      provider: provider,
      operation: operation,
      requested_mode: requested_mode,
      mode: if(live_smoke_ready?, do: :live_smoke, else: :fixture),
      fixture_first?: not live_smoke_ready?,
      live_smoke: %{
        requested?: requested_mode == :live_smoke,
        env_enabled?: env_enabled,
        ready?: live_smoke_ready?,
        env_key: env_key(provider),
        missing_config_keys: missing_config_keys,
        required_config_keys: required_config_keys
      }
    }
  end

  @spec requested_mode(keyword(), map()) :: :fixture | :live_smoke
  def requested_mode(opts, provider_config) when is_list(opts) and is_map(provider_config) do
    cond do
      Keyword.get(opts, :transport_mode) == :live_smoke -> :live_smoke
      Keyword.get(opts, :live_smoke, false) -> :live_smoke
      Map.get(provider_config, :transport_mode) == :live_smoke -> :live_smoke
      Map.get(provider_config, :live_smoke, false) -> :live_smoke
      true -> :fixture
    end
  end

  @spec env_enabled?(atom() | String.t()) :: boolean()
  def env_enabled?(provider) do
    env_key = env_key(provider)

    case {parse_env(System.get_env(@live_smoke_env)), parse_env(System.get_env(env_key))} do
      {true, _} -> true
      {_, true} -> true
      _ -> false
    end
  end

  @spec env_key(atom() | String.t()) :: String.t()
  def env_key(provider), do: "#{@live_smoke_env}_#{provider_name(provider)}"

  defp provider_name(provider) when is_atom(provider), do: provider |> Atom.to_string() |> String.upcase()
  defp provider_name(provider) when is_binary(provider), do: String.upcase(provider)

  defp parse_env(nil), do: false
  defp parse_env("1"), do: true
  defp parse_env("true"), do: true
  defp parse_env("0"), do: false
  defp parse_env("false"), do: false
  defp parse_env(_other), do: false
end
