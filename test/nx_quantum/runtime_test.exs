defmodule NxQuantum.RuntimeTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Runtime

  describe "supported_profiles/0" do
    test "returns profiles ordered by support tier priority" do
      profiles = Runtime.supported_profiles()

      assert length(profiles) >= 4
      assert Enum.at(profiles, 0).support_tier == :p0
      assert List.last(profiles).support_tier in [:p0, :p1]
    end
  end

  describe "capabilities/1" do
    test "returns availability metadata per profile" do
      capabilities =
        Runtime.capabilities(
          detector: fn
            :cpu_portable -> true
            :cpu_compiled -> true
            :nvidia_gpu_compiled -> false
            :torch_interop_runtime -> false
          end
        )

      assert Enum.all?(capabilities, &Map.has_key?(&1, :available))
      assert Enum.find(capabilities, &(&1.id == :cpu_portable)).available == true
      assert Enum.find(capabilities, &(&1.id == :nvidia_gpu_compiled)).available == false
    end

    test "available_profile_ids/1 returns only detected profiles" do
      ids =
        Runtime.available_profile_ids(
          detector: fn
            :cpu_portable -> true
            :cpu_compiled -> true
            :nvidia_gpu_compiled -> false
            :torch_interop_runtime -> false
          end
        )

      assert :cpu_portable in ids
      assert :cpu_compiled in ids
      refute :nvidia_gpu_compiled in ids
      refute :torch_interop_runtime in ids
    end
  end

  describe "resolve/2" do
    test "returns typed unsupported profile error" do
      assert {:error, %{code: :unsupported_runtime_profile}} =
               Runtime.resolve(:unknown_profile)
    end

    test "returns strict unavailable backend error" do
      assert {:error, %{code: :backend_unavailable, requested_profile: :nvidia_gpu_compiled}} =
               Runtime.resolve(:nvidia_gpu_compiled,
                 fallback_policy: :strict,
                 runtime_available?: false
               )
    end

    test "deterministically falls back when policy allows" do
      assert {:ok, %{id: :cpu_compiled}} =
               Runtime.resolve(:nvidia_gpu_compiled,
                 fallback_policy: :allow_cpu_compiled,
                 runtime_available?: false
               )
    end

    test "accepts profile map input" do
      profile = Runtime.profile!(:cpu_compiled)

      assert {:ok, %{id: :cpu_compiled}} = Runtime.resolve(profile, runtime_available?: true)
    end

    test "returns typed error for unsupported fallback policy" do
      assert {:error, %{code: :unsupported_fallback_policy}} =
               Runtime.resolve(:nvidia_gpu_compiled,
                 fallback_policy: :custom_policy,
                 runtime_available?: false
               )
    end

    test "uses capabilities override when runtime_available? is not provided" do
      assert {:error, %{code: :backend_unavailable, requested_profile: :nvidia_gpu_compiled}} =
               Runtime.resolve(:nvidia_gpu_compiled,
                 fallback_policy: :strict,
                 capabilities: %{nvidia_gpu_compiled: false}
               )
    end

    test "runtime_available? option takes precedence over capabilities override" do
      assert {:ok, %{id: :nvidia_gpu_compiled}} =
               Runtime.resolve(:nvidia_gpu_compiled,
                 fallback_policy: :strict,
                 runtime_available?: true,
                 capabilities: %{nvidia_gpu_compiled: false}
               )
    end
  end
end
