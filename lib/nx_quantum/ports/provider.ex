defmodule NxQuantum.Ports.Provider do
  @moduledoc """
  Provider bridge contract for hardware-facing job lifecycle behavior.
  """

  @type provider_id :: atom() | String.t()
  @type job_state :: :submitted | :queued | :running | :completed | :cancelled | :failed
  @type payload :: map()
  @type job :: %{
          required(:id) => String.t(),
          required(:state) => job_state(),
          required(:provider) => provider_id(),
          required(:target) => String.t(),
          optional(:submitted_at) => String.t() | nil,
          optional(:metadata) => map(),
          optional(atom()) => term()
        }
  @type result_payload :: %{
          required(:job_id) => String.t(),
          required(:state) => job_state(),
          required(:provider) => provider_id(),
          required(:target) => String.t(),
          required(:payload) => payload(),
          optional(:metadata) => map()
        }
  @type capabilities :: %{
          required(:supports_estimator) => boolean(),
          required(:supports_sampler) => boolean(),
          required(:supports_batch) => boolean(),
          required(:supports_dynamic) => boolean(),
          required(:supports_cancel_in_running) => boolean(),
          required(:supports_calibration_payload) => boolean(),
          required(:target_class) => :gate_model | :analog | :simulator
        }

  @callback provider_id() :: provider_id()
  @callback capabilities(String.t() | nil, keyword()) :: {:ok, capabilities()} | {:error, term()}
  @callback submit(payload(), keyword()) :: {:ok, job()} | {:error, term()}
  @callback poll(job(), keyword()) :: {:ok, job()} | {:error, term()}
  @callback cancel(job(), keyword()) :: {:ok, job()} | {:error, term()}
  @callback fetch_result(job(), keyword()) :: {:ok, result_payload()} | {:error, term()}

  @optional_callbacks capabilities: 2
end
