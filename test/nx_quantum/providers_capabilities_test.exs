defmodule NxQuantum.ProvidersCapabilitiesTest do
  use ExUnit.Case, async: true

  alias NxQuantum.ProviderBridge
  alias NxQuantum.Providers.Capabilities

  defmodule PreflightStubProvider do
    @moduledoc false
    @behaviour NxQuantum.Ports.Provider

    @impl true
    def provider_id, do: :preflight_stub

    @impl true
    def capabilities(_target, _opts) do
      {:ok,
       %{
         supports_estimator: true,
         supports_sampler: true,
         supports_batch: true,
         supports_dynamic: false,
         supports_cancel_in_running: true,
         supports_calibration_payload: true,
         target_class: :gate_model
       }}
    end

    @impl true
    def submit(_payload, opts) do
      if pid = opts[:notify_submit_pid], do: send(pid, {:provider_submit_attempt, provider_id()})
      {:ok, %{id: "stub_job_1", state: :submitted, provider: provider_id(), target: "stub_target"}}
    end

    @impl true
    def poll(job, _opts), do: {:ok, job}

    @impl true
    def cancel(job, _opts), do: {:ok, job}

    @impl true
    def fetch_result(job, _opts),
      do: {:ok, %{job_id: job.id, state: :completed, provider: provider_id(), target: job.target, payload: %{}}}
  end

  test "validate_contract/4 accepts v1 capability envelope" do
    capability = %{
      supports_estimator: true,
      supports_sampler: true,
      supports_batch: true,
      supports_dynamic: false,
      supports_cancel_in_running: true,
      supports_calibration_payload: true,
      target_class: :gate_model
    }

    assert {:ok, ^capability} = Capabilities.validate_contract(capability, :ibm_runtime, :v1, "ibm_backend")
  end

  test "validate_contract/4 rejects malformed capability envelope" do
    malformed = %{
      supports_estimator: true,
      supports_sampler: true,
      supports_batch: true,
      supports_dynamic: :unknown,
      supports_cancel_in_running: true,
      supports_calibration_payload: true,
      target_class: :gate_model
    }

    assert {:error, %{code: :provider_invalid_response}} =
             Capabilities.validate_contract(malformed, :aws_braket, :v1, "sv1")
  end

  test "preflight/4 rejects unsupported dynamic workflows with typed capability mismatch" do
    capability = %{
      supports_estimator: false,
      supports_sampler: true,
      supports_batch: true,
      supports_dynamic: false,
      supports_cancel_in_running: true,
      supports_calibration_payload: false,
      target_class: :gate_model
    }

    request = %{workflow: :sampler, dynamic: true}

    assert {:error, %{code: :provider_capability_mismatch, capability: :supports_dynamic}} =
             Capabilities.preflight(capability, request, :aws_braket, "sv1")
  end

  test "bridge preflight rejects unsupported capability before adapter submit" do
    result =
      ProviderBridge.submit_job(PreflightStubProvider, %{workflow: :sampler, dynamic: true},
        target: "stub_target",
        notify_submit_pid: self(),
        provider_config: %{}
      )

    assert {:error, %{code: :provider_capability_mismatch, capability: :supports_dynamic}} = result
    refute_received {:provider_submit_attempt, :preflight_stub}
  end
end
