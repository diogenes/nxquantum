# Goldens for examples/livebook/provider_bridge_side_by_side.livemd (fixture lane only).
# Job ids are derived from the payload (%{workflow: :sampler, shots: 1024}) and the provider; they are exact.
keys = [
  :correlation_id,
  :idempotency_key,
  :job_id,
  :metadata,
  :payload,
  :provider,
  :request_id,
  :schema_version,
  :state,
  :target
]

round_trip = fn provider ->
  %{type: "result", schema_version: "v1", state: "completed", provider: provider, round_trip_equal: true}
end

%{
  "normalized_key_sets" => [ibm_runtime: keys, aws_braket: keys, azure_quantum: keys],
  "deterministic_shape" => %{
    same_keys_for_all_providers: true,
    states: [ibm_runtime: :completed, aws_braket: :completed, azure_quantum: :completed]
  },
  "transport_modes" => [
    ibm_runtime: %{mode: :fixture, fixture?: true, job_id: "ibm_job_ff6ecf9c987e"},
    aws_braket: %{mode: :fixture, fixture?: true, job_id: "braket_task_c1ee9ad1c551"},
    azure_quantum: %{mode: :fixture, fixture?: true, job_id: "azure_job_36df013d01a1"}
  ],
  "envelope_round_trip" => [
    ibm_runtime: round_trip.("ibm_runtime"),
    aws_braket: round_trip.("aws_braket"),
    azure_quantum: round_trip.("azure_quantum")
  ],
  "missing_config_errors" => [
    ibm_runtime: %{
      code: :provider_auth_error,
      reason: :missing_provider_config,
      missing_keys: [:auth_token, :channel, :backend]
    },
    aws_braket: %{
      code: :provider_auth_error,
      reason: :missing_provider_config,
      missing_keys: [:region, :credentials_profile, :device_arn]
    },
    azure_quantum: %{
      code: :provider_auth_error,
      reason: :missing_provider_config,
      missing_keys: [:workspace, :auth_context, :target_id, :provider_name]
    }
  ],
  "live_keys_from_results" => [
    ibm_runtime: %{env_key: "NXQ_PROVIDER_LIVE_IBM_RUNTIME", enabled: false},
    aws_braket: %{env_key: "NXQ_PROVIDER_LIVE_AWS_BRAKET", enabled: false},
    azure_quantum: %{env_key: "NXQ_PROVIDER_LIVE_AZURE_QUANTUM", enabled: false}
  ]
}
