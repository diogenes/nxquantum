defmodule NxQuantum.ProviderAzureAdapterTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Adapters.Providers.AzureQuantum
  alias NxQuantum.ProviderBridge

  test "azure adapter normalizes lifecycle operations" do
    payload = %{workflow: :sampler, shots: 512}

    opts = [
      target: "azure.quantum.sim",
      provider_config: %{
        workspace: "ws-1",
        auth_context: "managed_identity",
        target_id: "azure.quantum.sim",
        provider_name: "microsoft"
      }
    ]

    assert {:ok, submitted} = ProviderBridge.submit_job(AzureQuantum, payload, opts)
    assert submitted.state == :submitted
    assert submitted.metadata.transport.mode == :fixture

    assert {:ok, polled} = ProviderBridge.poll_job(AzureQuantum, submitted, opts)
    assert polled.state == :completed

    assert {:ok, cancelled} = ProviderBridge.cancel_job(AzureQuantum, submitted, opts)
    assert cancelled.state == :cancelled

    assert {:ok, result} = ProviderBridge.fetch_result(AzureQuantum, polled, opts)
    assert result.state == :completed
    assert result.provider == :azure_quantum
    assert result.metadata.transport.mode == :fixture
  end

  test "azure target/provider mismatch maps to capability mismatch" do
    assert {:error, %{code: :provider_capability_mismatch, capability: :target_provider_match}} =
             ProviderBridge.submit_job(AzureQuantum, %{workflow: :sampler},
               target: "azure.quantum.sim",
               provider_target_mismatch: true,
               provider_config: %{
                 workspace: "ws-1",
                 auth_context: "managed_identity",
                 target_id: "azure.quantum.sim",
                 provider_name: "microsoft"
               }
             )
  end
end
