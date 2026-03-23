defmodule NxQuantum.ObservabilityTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Observability.OpenTelemetry
  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.Observability
  alias NxQuantum.Observability.Schema
  alias NxQuantum.ProviderBridge

  test "fingerprint is deterministic for equivalent canonicalized inputs" do
    input = %{workflow: :sampler, shots: 1024, circuit: ["h", "cnot"], seed: 7}

    assert Observability.fingerprint(input) == Observability.fingerprint(input)
  end

  test "portability delta exposes stable schema" do
    delta =
      Observability.portability_delta(
        %{payload: %{expectation: 0.9}, metadata: %{latency_ms: 10.0}},
        %{payload: %{expectation: 0.85}, metadata: %{latency_ms: 12.0, sample_kl_divergence: 0.02}}
      )

    assert Map.has_key?(delta, :latency_delta_ms)
    assert Map.has_key?(delta, :expectation_delta_abs)
    assert Map.has_key?(delta, :sample_kl_divergence)
  end

  test "open telemetry adapter stores spans, metrics, and logs" do
    Observability.reset(adapter: OpenTelemetry)

    assert {:ok, _} =
             ProviderBridge.run_lifecycle(
               IBMRuntime,
               %{workflow: :sampler, shots: 128},
               target: "ibm_backend",
               provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend"},
               observability: [enabled: true, adapter: OpenTelemetry, profile: :high_level]
             )

    snapshot = Observability.snapshot(adapter: OpenTelemetry)

    assert match?([_, _ | _], snapshot.spans)
    assert match?([_, _ | _], snapshot.metrics)
    assert match?([_ | _], snapshot.logs)
    assert :ok = Schema.validate_snapshot(snapshot, :high_level)
  end

  test "schema governance validates high_level, granular, and forensics profiles" do
    snapshots =
      Map.new([:high_level, :granular, :forensics], fn profile ->
        Observability.reset(adapter: OpenTelemetry)

        assert {:ok, _} =
                 ProviderBridge.run_lifecycle(
                   IBMRuntime,
                   %{workflow: :sampler, shots: 128},
                   target: "ibm_backend",
                   provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend"},
                   observability: [enabled: true, adapter: OpenTelemetry, profile: profile]
                 )

        {profile, Observability.snapshot(adapter: OpenTelemetry)}
      end)

    assert :ok = Schema.validate_snapshot(snapshots.high_level, :high_level)
    assert :ok = Schema.validate_snapshot(snapshots.granular, :granular)
    assert :ok = Schema.validate_snapshot(snapshots.forensics, :forensics)
  end

  test "adapter substitution does not change lifecycle result contract shape" do
    payload = %{workflow: :sampler, shots: 256}

    common_opts = [
      target: "ibm_backend",
      provider_config: %{auth_token: "token", channel: "ibm_cloud", backend: "ibm_backend"}
    ]

    assert {:ok, with_noop} =
             ProviderBridge.run_lifecycle(
               IBMRuntime,
               payload,
               Keyword.put(common_opts, :observability, enabled: false)
             )

    assert {:ok, with_otlp} =
             ProviderBridge.run_lifecycle(
               IBMRuntime,
               payload,
               Keyword.put(common_opts, :observability, enabled: true, adapter: OpenTelemetry, profile: :high_level)
             )

    assert Map.keys(with_noop) == Map.keys(with_otlp)
    assert Map.keys(with_noop.result) == Map.keys(with_otlp.result)
  end
end
