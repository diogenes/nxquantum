defmodule NxQuantum.ProviderContractSerializationTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.ProviderBridge
  alias NxQuantum.ProviderBridge.Serialization

  test "to_external_map/1 emits versioned machine-readable job and result envelopes" do
    opts = [
      target: "ibm_backend_simulator",
      provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
    ]

    assert {:ok, submitted} = ProviderBridge.submit_job(IBMRuntime, %{workflow: :sampler, shots: 128}, opts)
    assert {:ok, polled} = ProviderBridge.poll_job(IBMRuntime, submitted, opts)
    assert {:ok, result} = ProviderBridge.fetch_result(IBMRuntime, polled, opts)

    job_map = Serialization.to_external_map(submitted)
    result_map = Serialization.to_external_map(result)

    assert job_map["schema_version"] == "v1"
    assert job_map["type"] == "job"
    assert is_binary(job_map["correlation_id"])
    assert is_binary(job_map["idempotency_key"])

    assert result_map["schema_version"] == "v1"
    assert result_map["type"] == "result"
    assert is_map(result_map["payload"])
  end

  test "serialize/1 is deterministic for equivalent envelope input" do
    opts = [
      target: "ibm_backend_simulator",
      provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
    ]

    assert {:ok, submitted_a} = ProviderBridge.submit_job(IBMRuntime, %{workflow: :estimator, shots: 256}, opts)
    assert {:ok, submitted_b} = ProviderBridge.submit_job(IBMRuntime, %{workflow: :estimator, shots: 256}, opts)

    assert submitted_a == submitted_b

    assert {:ok, serialized_a} = Serialization.serialize(submitted_a)
    assert {:ok, serialized_b} = Serialization.serialize(submitted_b)

    assert serialized_a == serialized_b
  end

  test "error serialization keeps typed code and version context" do
    error =
      ProviderBridge.submit_job(IBMRuntime, %{workflow: :sampler},
        target: "ibm_backend_simulator",
        provider_config: %{auth_token: "token", backend: "ibm_backend_simulator"}
      )

    assert {:error, provider_error} = error
    serialized = Serialization.to_external_map(provider_error)

    assert serialized["schema_version"] == "v1"
    assert serialized["type"] == "error"
    assert serialized["code"] == "provider_auth_error"
  end
end
