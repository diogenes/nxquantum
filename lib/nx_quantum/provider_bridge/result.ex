defmodule NxQuantum.ProviderBridge.Result do
  @moduledoc """
  Normalized provider lifecycle terminal result envelope.
  """

  @enforce_keys [:job_id, :state, :provider, :target, :payload]
  defstruct [
    :job_id,
    :state,
    :provider,
    :target,
    :payload,
    :schema_version,
    :correlation_id,
    :idempotency_key,
    metadata: %{}
  ]

  @type t :: %__MODULE__{
          job_id: String.t(),
          state: NxQuantum.ProviderBridge.Job.state(),
          provider: atom() | String.t() | module(),
          target: String.t(),
          payload: map(),
          schema_version: atom() | nil,
          correlation_id: String.t() | nil,
          idempotency_key: String.t() | nil,
          metadata: map()
        }
end
