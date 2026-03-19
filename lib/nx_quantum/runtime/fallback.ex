defmodule NxQuantum.Runtime.Fallback do
  @moduledoc false

  alias NxQuantum.Runtime.Catalog

  @spec resolve(map(), boolean(), atom()) :: {:ok, map()} | {:error, map()}
  def resolve(profile, true, _fallback_policy), do: {:ok, profile}

  def resolve(%{id: :nvidia_gpu_compiled}, false, :allow_cpu_compiled) do
    {:ok, Catalog.profile!(:cpu_compiled)}
  end

  def resolve(_profile, false, :allow_cpu_compiled) do
    {:ok, Catalog.profile!(:cpu_portable)}
  end

  def resolve(profile, false, :strict) do
    {:error,
     %{
       code: :backend_unavailable,
       requested_profile: profile.id,
       available_fallback: :cpu_compiled
     }}
  end

  def resolve(profile, false, fallback_policy) do
    {:error,
     %{
       code: :unsupported_fallback_policy,
       requested_profile: profile.id,
       fallback_policy: fallback_policy
     }}
  end
end
