# Goldens for examples/livebook/provider_bridge_side_by_side.livemd.
keys = [
  :__struct__,
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

%{
  "normalized_key_sets" => [
    ibm_runtime: keys,
    aws_braket: keys,
    azure_quantum: keys
  ]
}
