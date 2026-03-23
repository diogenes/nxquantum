defmodule NxQuantum.ProviderTransportReadinessTest do
  use ExUnit.Case, async: false

  alias NxQuantum.Adapters.Providers.AwsBraket
  alias NxQuantum.Adapters.Providers.AzureQuantum
  alias NxQuantum.Adapters.Providers.Common.TransportSupport
  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.ProviderBridge

  setup do
    keys = [
      "NXQ_PROVIDER_LIVE_SMOKE",
      "NXQ_PROVIDER_LIVE_SMOKE_IBM_RUNTIME",
      "NXQ_PROVIDER_LIVE_SMOKE_AWS_BRAKET",
      "NXQ_PROVIDER_LIVE_SMOKE_AZURE_QUANTUM"
    ]

    snapshot = Map.new(keys, fn key -> {key, System.get_env(key)} end)

    on_exit(fn ->
      Enum.each(snapshot, fn {key, value} ->
        case value do
          nil -> System.delete_env(key)
          value -> System.put_env(key, value)
        end
      end)
    end)

    :ok
  end

  test "fixture-first defaults stay deterministic without live-smoke toggles" do
    readiness =
      TransportSupport.readiness(
        :ibm_runtime,
        [provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}],
        [:auth_token, :channel, :backend],
        :submit
      )

    assert readiness.mode == :fixture
    assert readiness.requested_mode == :fixture
    assert readiness.fixture_first? == true
    refute readiness.live_smoke.requested?
    refute readiness.live_smoke.ready?
    refute readiness.live_smoke.env_enabled?
  end

  test "live-smoke requests stay in fixture mode until an env gate is present" do
    readiness =
      TransportSupport.readiness(
        :aws_braket,
        [
          transport_mode: :live_smoke,
          provider_config: %{
            region: "us-east-1",
            credentials_profile: "default",
            device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
          }
        ],
        [:region, :credentials_profile, :device_arn],
        :submit
      )

    assert readiness.requested_mode == :live_smoke
    assert readiness.mode == :fixture
    refute readiness.live_smoke.ready?
    refute readiness.live_smoke.env_enabled?
    assert readiness.live_smoke.missing_config_keys == []
  end

  test "env-gated live-smoke readiness is reflected in provider metadata without changing fixture payloads" do
    System.put_env("NXQ_PROVIDER_LIVE_SMOKE", "true")

    payload = %{workflow: :sampler, shots: 64}

    for {provider, opts} <- [
          {IBMRuntime,
           [
             transport_mode: :live_smoke,
             target: "ibm_backend_simulator",
             provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
           ]},
          {AwsBraket,
           [
             transport_mode: :live_smoke,
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             provider_config: %{
               region: "us-east-1",
               credentials_profile: "default",
               device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
             }
           ]},
          {AzureQuantum,
           [
             transport_mode: :live_smoke,
             target: "azure.quantum.sim",
             provider_config: %{
               workspace: "ws-1",
               auth_context: "managed_identity",
               target_id: "azure.quantum.sim",
               provider_name: "microsoft"
             }
           ]}
        ] do
      assert {:ok, readiness} = provider.transport_readiness(opts)
      assert readiness.mode == :live_smoke
      assert readiness.live_smoke.ready?

      assert {:ok, submitted} = ProviderBridge.submit_job(provider, payload, opts)
      assert submitted.metadata.transport.mode == :live_smoke
      assert submitted.metadata.transport.live_smoke.ready?

      assert {:ok, polled} = ProviderBridge.poll_job(provider, submitted, opts)
      assert polled.state == :completed
      assert polled.metadata.transport.mode == :live_smoke

      assert {:ok, result} = ProviderBridge.fetch_result(provider, polled, opts)
      assert result.payload.workflow == "sampler"
      assert result.metadata.transport.mode == :live_smoke
      assert result.metadata.transport.live_smoke.ready?
    end
  end

  test "typed invalid-response handling remains stable while transport metadata is present" do
    assert {:ok, submitted} =
             ProviderBridge.submit_job(IBMRuntime, %{workflow: :estimator},
               target: "ibm_backend_simulator",
               provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
             )

    assert {:error, %{code: :provider_invalid_response, operation: :poll, provider: :ibm_runtime}} =
             ProviderBridge.poll_job(IBMRuntime, submitted,
               raw_states: %{poll: "UNKNOWN_STATUS"},
               provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
             )

    assert submitted.metadata.transport.mode == :fixture
  end
end
