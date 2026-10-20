defmodule NxQuantum.Runtime.Detection do
  @moduledoc false

  @spec runtime_available?(atom(), keyword()) :: boolean()
  def runtime_available?(profile_id, opts) do
    capabilities_override = Keyword.get(opts, :capabilities)

    case Keyword.fetch(opts, :runtime_available?) do
      {:ok, value} ->
        value

      :error ->
        capabilities_lookup(capabilities_override, profile_id)
    end
  end

  @spec default_profile_available?(atom()) :: boolean()
  def default_profile_available?(profile_id) do
    case env_override(profile_id) do
      nil -> detect_profile_available(profile_id)
      explicit -> explicit
    end
  end

  defp capabilities_lookup(capabilities_override, profile_id) when is_map(capabilities_override) do
    case Map.fetch(capabilities_override, profile_id) do
      {:ok, value} -> value
      :error -> default_profile_available?(profile_id)
    end
  end

  defp capabilities_lookup(_capabilities_override, profile_id), do: default_profile_available?(profile_id)

  defp env_override(profile_id) do
    env_key =
      "NXQ_PROFILE_" <>
        (profile_id |> Atom.to_string() |> String.upcase()) <> "_AVAILABLE"

    case System.get_env(env_key) do
      "1" -> true
      "true" -> true
      "0" -> false
      "false" -> false
      _ -> nil
    end
  end

  defp detect_profile_available(:cpu_portable), do: true

  defp detect_profile_available(:cpu_compiled) do
    module_loaded?(exla_backend_module()) and exla_client_available?(:host)
  end

  defp detect_profile_available(:nvidia_gpu_compiled) do
    module_loaded?(exla_backend_module()) and exla_client_available?(:cuda)
  end

  defp detect_profile_available(:torch_interop_runtime), do: module_loaded?(torchx_backend_module())
  defp detect_profile_available(_unknown), do: false

  defp module_loaded?(module), do: Code.ensure_loaded?(module)

  defp exla_client_available?(client) do
    exla_client_module = exla_client_module()

    if module_loaded?(exla_client_module) and function_exported?(exla_client_module, :fetch!, 1) and
         exla_platform_supported?(client) do
      client
      |> safe_fetch_exla_client()
      |> successful_fetch_result?()
    else
      false
    end
  end

  defp successful_fetch_result?({:ok, _client}), do: true
  defp successful_fetch_result?(:ok), do: true
  defp successful_fetch_result?(%_{}), do: true
  defp successful_fetch_result?(_), do: false

  defp exla_platform_supported?(platform) do
    exla_client_module = exla_client_module()

    if function_exported?(exla_client_module, :get_supported_platforms, 0) do
      case safe_supported_platforms() do
        platforms when is_map(platforms) -> Map.has_key?(platforms, platform)
        _ -> false
      end
    else
      true
    end
  end

  defp safe_supported_platforms do
    :erlang.apply(exla_client_module(), :get_supported_platforms, [])
  rescue
    _ -> :error
  catch
    :exit, _reason -> :error
    _kind, _reason -> :error
  end

  defp safe_fetch_exla_client(client) do
    :erlang.apply(exla_client_module(), :fetch!, [client])
  rescue
    _ -> :error
  catch
    :exit, _reason -> :error
    _kind, _reason -> :error
  end

  defp exla_backend_module, do: configured_module(:exla_backend_module, :"Elixir.EXLA.Backend")
  defp exla_client_module, do: configured_module(:exla_client_module, :"Elixir.EXLA.Client")
  defp torchx_backend_module, do: configured_module(:torchx_backend_module, :"Elixir.Torchx.Backend")

  defp configured_module(key, default) do
    :nx_quantum
    |> Application.get_env(__MODULE__, [])
    |> Keyword.get(key, default)
  end
end
