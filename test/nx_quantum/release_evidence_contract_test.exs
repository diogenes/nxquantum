defmodule NxQuantum.ReleaseEvidenceContractTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Observability.OpenTelemetry
  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.Observability
  alias NxQuantum.Observability.Schema
  alias NxQuantum.ProviderBridge
  alias NxQuantum.ProviderBridge.Serialization

  test "release evidence validates envelope serialization and observability schema compatibility" do
    opts = [
      target: "ibm_backend_simulator",
      provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"},
      observability: [enabled: true, adapter: OpenTelemetry, profile: :high_level]
    ]

    Observability.reset(adapter: OpenTelemetry)

    assert {:ok, %{result: result}} =
             ProviderBridge.run_lifecycle(IBMRuntime, %{workflow: :sampler, shots: 128}, opts)

    assert :ok = Schema.validate_snapshot(Observability.snapshot(adapter: OpenTelemetry), :high_level)

    external = Serialization.to_external_map(result)
    assert external["schema_version"] == "v1"
    assert is_binary(external["correlation_id"])
    assert is_binary(external["idempotency_key"])

    assert {:ok, first} = Serialization.serialize(result)
    assert {:ok, second} = Serialization.serialize(result)
    assert first == second
  end
end
