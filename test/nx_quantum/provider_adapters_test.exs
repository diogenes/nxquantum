defmodule NxQuantum.ProviderAdaptersTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Providers.AwsBraket
  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.ProviderBridge

  test "IBM adapter normalizes submit/poll/fetch lifecycle" do
    payload = %{workflow: :estimator, shots: 1024}

    opts = [
      target: "ibm_backend_simulator",
      provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
    ]

    assert {:ok, submitted} = ProviderBridge.submit_job(IBMRuntime, payload, opts)
    assert submitted.state == :submitted
    assert submitted.provider == :ibm_runtime

    assert {:ok, polled} = ProviderBridge.poll_job(IBMRuntime, submitted, opts)
    assert polled.state == :completed

    assert {:ok, result} = ProviderBridge.fetch_result(IBMRuntime, polled, opts)
    assert result.state == :completed
    assert result.provider == :ibm_runtime
  end

  test "AWS adapter normalizes submit/poll/fetch lifecycle" do
    payload = %{workflow: :sampler, shots: 1024}

    opts = [
      target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
      provider_config: %{
        region: "us-east-1",
        credentials_profile: "default",
        device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
      }
    ]

    assert {:ok, submitted} = ProviderBridge.submit_job(AwsBraket, payload, opts)
    assert submitted.state == :submitted
    assert submitted.provider == :aws_braket

    assert {:ok, polled} = ProviderBridge.poll_job(AwsBraket, submitted, opts)
    assert polled.state == :completed

    assert {:ok, result} = ProviderBridge.fetch_result(AwsBraket, polled, opts)
    assert result.state == :completed
    assert result.provider == :aws_braket
  end

  test "provider config errors are typed and deterministically redacted" do
    assert {:error, %{code: :provider_auth_error, metadata: %{provider_config: redacted}}} =
             ProviderBridge.submit_job(IBMRuntime, %{workflow: :sampler},
               target: "ibm_backend_simulator",
               provider_config: %{auth_token: "secret-token", backend: "ibm_backend_simulator"}
             )

    assert redacted.auth_token == "[REDACTED]"
  end

  test "unknown raw status is mapped to provider_invalid_response" do
    assert {:ok, submitted} =
             ProviderBridge.submit_job(IBMRuntime, %{workflow: :estimator},
               target: "ibm_backend_simulator",
               provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
             )

    assert {:error, %{code: :provider_invalid_response, operation: :poll}} =
             ProviderBridge.poll_job(IBMRuntime, submitted,
               raw_states: %{poll: "UNKNOWN_STATUS"},
               provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
             )
  end
end
