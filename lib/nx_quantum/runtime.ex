defmodule NxQuantum.Runtime do
  @moduledoc """
  Runtime profile catalog and deterministic fallback policy.

  This module defines explicit execution profiles while delegating tensor execution
  to native Nx backends/compilers.
  """

  alias NxQuantum.Runtime.Catalog
  alias NxQuantum.Runtime.Detection
  alias NxQuantum.Runtime.Fallback
  alias NxQuantum.Runtime.Scale

  @type profile_id ::
          :cpu_portable | :cpu_compiled | :nvidia_gpu_compiled | :torch_interop_runtime
  @type support_tier :: :p0 | :p1
  @type fallback_policy :: :strict | :allow_cpu_compiled
  @type scale_strategy :: :auto | :dense_only | :large_scale_preferred
  # `:tensor_network_fallback` is a routing label only: no tensor-network engine
  # executes it yet. Selecting it reports the decision; execution stays dense.
  # See docs/backend-support.md ("Simulation Paths").
  @type simulation_path :: :dense_state_vector | :tensor_network_fallback
  @type simulation_decision :: %{selected_path: simulation_path(), report: map()}

  @type profile :: %{
          id: profile_id(),
          compiler: nil | module(),
          backend: module(),
          hardware: String.t(),
          support_tier: support_tier()
        }

  @spec supported_profiles() :: [profile()]
  def supported_profiles do
    Catalog.supported_profiles()
  end

  @spec profile!(profile_id()) :: profile()
  def profile!(profile_id) when is_atom(profile_id), do: Catalog.profile!(profile_id)

  @spec capabilities(keyword()) :: [map()]
  def capabilities(opts \\ []) do
    detector = Keyword.get(opts, :detector, &Detection.default_profile_available?/1)

    Enum.map(supported_profiles(), fn profile ->
      Map.put(profile, :available, detector.(profile.id))
    end)
  end

  @spec available_profile_ids(keyword()) :: [profile_id()]
  def available_profile_ids(opts \\ []) do
    opts
    |> capabilities()
    |> Enum.filter(& &1.available)
    |> Enum.map(& &1.id)
  end

  @spec resolve(profile_id() | profile(), keyword()) :: {:ok, profile()} | {:error, map()}
  def resolve(profile_id_or_profile, opts \\ [])

  def resolve(%{id: profile_id}, opts) when is_atom(profile_id), do: resolve(profile_id, opts)

  def resolve(profile_id, opts) do
    fallback_policy = Keyword.get(opts, :fallback_policy, :strict)
    runtime_available? = Detection.runtime_available?(profile_id, opts)

    case Catalog.fetch(profile_id) do
      :error ->
        {:error,
         %{
           code: :unsupported_runtime_profile,
           profile_id: profile_id,
           supported_profiles: Catalog.supported_profile_ids()
         }}

      {:ok, profile} ->
        Fallback.resolve(profile, runtime_available?, fallback_policy)
    end
  end

  @spec select_simulation_strategy(scale_strategy(), non_neg_integer(), keyword()) ::
          {:ok, simulation_decision()} | {:error, map()}
  def select_simulation_strategy(strategy, qubit_count, opts \\ []) do
    Scale.select(strategy, qubit_count, opts)
  end
end
