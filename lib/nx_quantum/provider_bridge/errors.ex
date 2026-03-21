defmodule NxQuantum.ProviderBridge.Errors do
  @moduledoc false

  @spec transport_error(atom(), atom() | String.t(), term(), keyword()) :: map()
  def transport_error(operation, provider, reason, opts \\ []) do
    base(
      %{
        code: :provider_transport_error,
        operation: operation,
        provider: provider,
        reason: reason
      },
      opts
    )
  end

  @spec auth_error(atom(), atom() | String.t(), term(), keyword()) :: map()
  def auth_error(operation, provider, reason, opts \\ []) do
    base(%{code: :provider_auth_error, operation: operation, provider: provider, reason: reason}, opts)
  end

  @spec invalid_state(atom(), atom() | String.t(), atom(), keyword()) :: map()
  def invalid_state(operation, provider, state, opts \\ []) do
    base(
      %{
        code: :provider_invalid_state,
        operation: operation,
        provider: provider,
        state: state
      },
      opts
    )
  end

  @spec invalid_response(atom(), atom() | String.t(), term(), keyword()) :: map()
  def invalid_response(operation, provider, response, opts \\ []) do
    base(
      %{
        code: :provider_invalid_response,
        operation: operation,
        provider: provider,
        response: response
      },
      opts
    )
  end

  @spec capability_mismatch(atom(), atom() | String.t(), atom(), keyword()) :: map()
  def capability_mismatch(operation, provider, capability, opts \\ []) do
    base(
      %{
        code: :provider_capability_mismatch,
        operation: operation,
        provider: provider,
        capability: capability
      },
      opts
    )
  end

  @spec execution_error(atom(), atom() | String.t(), term(), keyword()) :: map()
  def execution_error(operation, provider, reason, opts \\ []) do
    base(
      %{
        code: :provider_execution_error,
        operation: operation,
        provider: provider,
        reason: reason
      },
      opts
    )
  end

  @spec rate_limited(atom(), atom() | String.t(), term(), keyword()) :: map()
  def rate_limited(operation, provider, reason, opts \\ []) do
    base(
      %{
        code: :provider_rate_limited,
        operation: operation,
        provider: provider,
        reason: reason
      },
      opts
    )
  end

  defp base(map, opts) do
    metadata = Keyword.get(opts, :metadata, %{})
    Map.put(map, :metadata, metadata)
  end
end
