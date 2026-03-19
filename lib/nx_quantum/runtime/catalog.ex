defmodule NxQuantum.Runtime.Catalog do
  @moduledoc false

  @profiles %{
    cpu_portable: %{
      id: :cpu_portable,
      compiler: nil,
      backend: Nx.BinaryBackend,
      hardware: "Any CPU (zero native setup)",
      support_tier: :p0
    },
    cpu_compiled: %{
      id: :cpu_compiled,
      compiler: EXLA,
      backend: EXLA.Backend,
      hardware: "Production CPU",
      support_tier: :p0
    },
    nvidia_gpu_compiled: %{
      id: :nvidia_gpu_compiled,
      compiler: EXLA,
      backend: EXLA.Backend,
      hardware: "NVIDIA GPU via CUDA",
      support_tier: :p0
    },
    torch_interop_runtime: %{
      id: :torch_interop_runtime,
      compiler: nil,
      backend: Torchx.Backend,
      hardware: "CPU/GPU with LibTorch runtime",
      support_tier: :p1
    }
  }

  @spec fetch(atom()) :: {:ok, map()} | :error
  def fetch(profile_id), do: Map.fetch(@profiles, profile_id)

  @spec profile!(atom()) :: map()
  def profile!(profile_id), do: Map.fetch!(@profiles, profile_id)

  @spec supported_profiles() :: [map()]
  def supported_profiles do
    @profiles
    |> Map.values()
    |> Enum.sort_by(&tier_rank/1)
  end

  @spec supported_profile_ids() :: [atom()]
  def supported_profile_ids, do: Map.keys(@profiles)

  defp tier_rank(%{support_tier: :p0}), do: 0
  defp tier_rank(%{support_tier: :p1}), do: 1
end
