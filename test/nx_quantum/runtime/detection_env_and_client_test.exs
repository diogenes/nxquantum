defmodule NxQuantum.Runtime.DetectionEnvAndClientTest do
  @moduledoc """
  Covers the environment-override and EXLA client-probe branches of `NxQuantum.Runtime.Detection`
  without EXLA installed (CI runs with `NXQ_ENABLE_EXLA=0`).
  """

  use ExUnit.Case, async: false

  alias NxQuantum.Runtime.Detection

  defmodule Client do
    @moduledoc false
    defstruct [:platform]
    def fetch!(platform), do: %__MODULE__{platform: platform}
    def get_supported_platforms, do: %{host: 1, cuda: 1}
  end

  defmodule OkTupleClient do
    @moduledoc false
    def fetch!(:host), do: {:ok, :host}
    def get_supported_platforms, do: %{host: 1}
  end

  defmodule AtomClient do
    @moduledoc false
    def fetch!(_platform), do: :ok
  end

  defmodule UnexpectedClient do
    @moduledoc false
    def fetch!(_platform), do: :unexpected
  end

  defmodule RaisingClient do
    @moduledoc false
    def fetch!(_platform), do: raise("boom")
  end

  defmodule ExitingClient do
    @moduledoc false
    def fetch!(_platform), do: exit(:boom)
  end

  defmodule BrokenPlatformsClient do
    @moduledoc false
    def fetch!(_platform), do: %Client{platform: :host}
    def get_supported_platforms, do: raise("no platforms")
  end

  setup do
    previous = Application.get_env(:nx_quantum, Detection, [])

    on_exit(fn ->
      Application.put_env(:nx_quantum, Detection, previous)
      System.delete_env("NXQ_PROFILE_CPU_COMPILED_AVAILABLE")
      System.delete_env("NXQ_PROFILE_CPU_PORTABLE_AVAILABLE")
    end)

    :ok
  end

  defp use_client(module) do
    Application.put_env(:nx_quantum, Detection, exla_backend_module: Kernel, exla_client_module: module)
  end

  test "environment overrides accept 1/true and 0/false, and ignore other values" do
    key = "NXQ_PROFILE_CPU_PORTABLE_AVAILABLE"

    for {value, expected} <- [{"1", true}, {"true", true}, {"0", false}, {"false", false}] do
      System.put_env(key, value)
      assert Detection.default_profile_available?(:cpu_portable) == expected
    end

    System.put_env(key, "maybe")
    assert Detection.default_profile_available?(:cpu_portable) == true
  end

  test "an EXLA client that fetches to a struct makes cpu_compiled available" do
    use_client(Client)
    assert Detection.default_profile_available?(:cpu_compiled) == true
  end

  test "fetch results: ok tuple and :ok atom count as available; unrecognised results do not" do
    use_client(OkTupleClient)
    assert Detection.default_profile_available?(:cpu_compiled) == true

    use_client(AtomClient)
    assert Detection.default_profile_available?(:cpu_compiled) == true

    use_client(UnexpectedClient)
    assert Detection.default_profile_available?(:cpu_compiled) == false
  end

  test "a probe that raises or exits is treated as unavailable" do
    use_client(RaisingClient)
    assert Detection.default_profile_available?(:cpu_compiled) == false

    use_client(ExitingClient)
    assert Detection.default_profile_available?(:cpu_compiled) == false
  end

  test "a platform probe that raises is treated as unavailable" do
    use_client(BrokenPlatformsClient)
    assert Detection.default_profile_available?(:cpu_compiled) == false
  end

  test "explicit capability overrides take precedence over detection" do
    assert Detection.runtime_available?(:cpu_compiled, capabilities: %{cpu_compiled: true}) == true
    assert Detection.runtime_available?(:cpu_compiled, runtime_available?: false) == false
  end

  test "unknown profile ids are unavailable" do
    assert Detection.default_profile_available?(:not_a_profile) == false
  end
end
