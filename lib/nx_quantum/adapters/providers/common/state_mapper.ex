defmodule NxQuantum.Adapters.Providers.Common.StateMapper do
  @moduledoc false

  alias NxQuantum.ProviderBridge.Errors

  @spec map(atom(), atom() | String.t(), map(), atom() | String.t(), atom() | String.t(), map()) ::
          {:ok, atom(), map()} | {:error, map()}
  def map(operation, provider, mapping, raw_state, target, metadata \\ %{})
      when is_atom(operation) and (is_atom(provider) or is_binary(provider)) and is_map(mapping) do
    case Map.fetch(mapping, raw_state) do
      {:ok, state} -> {:ok, state, Map.merge(metadata, %{raw_state: raw_state, target: target})}
      :error -> {:error, Errors.invalid_response(operation, provider, %{raw_state: raw_state}, metadata: metadata)}
    end
  end
end
