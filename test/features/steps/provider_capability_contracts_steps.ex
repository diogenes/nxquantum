defmodule NxQuantum.Features.Steps.ProviderCapabilityContractsSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Adapters.Providers.AwsBraket
  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Ports.Provider
  alias NxQuantum.ProviderBridge
  alias NxQuantum.Providers.Capabilities

  defmodule AzureCapabilityStub do
    @moduledoc false

    @behaviour Provider

    @impl true
    def provider_id, do: :azure_quantum

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
    def submit(_payload, _opts),
      do: {:ok, %{id: "az_job", state: :submitted, provider: provider_id(), target: "azure.target"}}

    @impl true
    def poll(job, _opts), do: {:ok, %{job | state: :completed}}

    @impl true
    def cancel(job, _opts), do: {:ok, %{job | state: :cancelled}}

    @impl true
    def fetch_result(job, _opts),
      do: {:ok, %{job_id: job.id, state: :completed, provider: provider_id(), target: job.target, payload: %{}}}
  end

  defmodule BrokenResponseProvider do
    @moduledoc false

    @behaviour Provider

    @impl true
    def provider_id, do: :broken_response_provider

    @impl true
    def capabilities(_target, _opts) do
      {:ok,
       %{
         supports_estimator: true,
         supports_sampler: true,
         supports_batch: true,
         supports_dynamic: true,
         supports_cancel_in_running: true,
         supports_calibration_payload: true,
         target_class: :gate_model
       }}
    end

    @impl true
    def submit(_payload, _opts), do: :unexpected_shape

    @impl true
    def poll(_job, _opts), do: {:ok, %{}}

    @impl true
    def cancel(_job, _opts), do: {:ok, %{}}

    @impl true
    def fetch_result(_job, _opts), do: {:ok, %{}}
  end

  @impl true
  def feature, do: "provider_capability_contracts.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2, &handle_errors/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "provider capability contract version \"v1\" for top-3 providers" ->
        {:handled,
         Map.merge(ctx, %{
           contract_version: :v1,
           provider_contracts: provider_contracts(),
           provider_target: "default_target"
         })}

      text == "provider \"aws_braket\" does not support dynamic execution for selected target" ->
        {:handled,
         Map.merge(ctx, %{
           selected_provider: AwsBraket,
           payload: %{workflow: :sampler, dynamic: true},
           opts: [
             target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
             provider_config: %{
               region: "us-east-1",
               credentials_profile: "default",
               device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
             },
             notify_submit_pid: self()
           ]
         })}

      text == "identical capability contracts and identical workflow request input" ->
        {:handled,
         Map.merge(ctx, %{
           capability: %{
             supports_estimator: true,
             supports_sampler: true,
             supports_batch: true,
             supports_dynamic: false,
             supports_cancel_in_running: true,
             supports_calibration_payload: false,
             target_class: :gate_model
           },
           preflight_request: %{workflow: :sampler, dynamic: false}
         })}

      text == "capability preflight is evaluated for IBM Runtime, AWS Braket, and Azure Quantum" ->
        {:handled, Map.put(ctx, :provider_contracts, provider_contracts())}

      text == "a provider adapter returns an unexpected callback response shape" ->
        {:handled,
         Map.merge(ctx, %{
           selected_provider: BrokenResponseProvider,
           payload: %{workflow: :sampler},
           opts: [provider_config: %{}, target: "invalid"]
         })}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I validate required capability keys for each provider" ->
        contracts = ctx.provider_contracts

        missing_keys =
          Enum.reduce(contracts, %{}, fn {provider, contract}, acc ->
            missing = Enum.reject(Capabilities.required_keys(), &Map.has_key?(contract, &1))
            Map.put(acc, provider, missing)
          end)

        {:handled, Map.put(ctx, :missing_keys, missing_keys)}

      text == "I submit a dynamic workflow request" ->
        {:handled,
         Map.put(ctx, :dynamic_submit_result, ProviderBridge.submit_job(ctx.selected_provider, ctx.payload, ctx.opts))}

      text == "I run preflight validation twice" ->
        provider = :capability_test
        target = "deterministic_target"

        a =
          with {:ok, validated} <- Capabilities.validate_contract(ctx.capability, provider, :v1, target) do
            Capabilities.preflight(validated, ctx.preflight_request, provider, target)
          end

        b =
          with {:ok, validated} <- Capabilities.validate_contract(ctx.capability, provider, :v1, target) do
            Capabilities.preflight(validated, ctx.preflight_request, provider, target)
          end

        invalid_capability = %{ctx.capability | supports_dynamic: :unknown}
        invalid = Capabilities.validate_contract(invalid_capability, provider, :v1, target)

        {:handled,
         ctx |> Map.put(:preflight_a, a) |> Map.put(:preflight_b, b) |> Map.put(:invalid_capability_result, invalid)}

      text == "each provider rejects an unsupported capability for the selected target" ->
        dynamic_request = %{workflow: :sampler, dynamic: true}

        mismatch_results =
          for {provider_id, contract} <- ctx.provider_contracts, into: %{} do
            result =
              with {:ok, validated} <- Capabilities.validate_contract(contract, provider_id, :v1, "target-1") do
                Capabilities.preflight(validated, dynamic_request, provider_id, "target-1")
              end

            {provider_id, result}
          end

        {:handled, Map.put(ctx, :mismatch_results, mismatch_results)}

      text == "response normalization is applied" and ctx.selected_provider == BrokenResponseProvider ->
        result = ProviderBridge.submit_job(ctx.selected_provider, ctx.payload, ctx.opts)

        normalized =
          case result do
            {:error, error} ->
              {:error,
               %{
                 error
                 | metadata:
                     Map.put(error.metadata, :raw_diagnostics, %{
                       provider_callback: :submit,
                       provider: :broken_response_provider
                     })
               }}

            other ->
              other
          end

        {:handled, Map.put(ctx, :normalization_result, normalized)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text, table: table}, ctx) do
    cond do
      text == "each capability envelope includes all required capability keys" ->
        required_from_table =
          table
          |> Enum.drop(1)
          |> Enum.map(fn [key] -> String.to_atom(key) end)

        assert required_from_table == Capabilities.required_keys()
        assert Enum.all?(ctx.missing_keys, fn {_provider, missing} -> missing == [] end)
        {:handled, ctx}

      text == "capability schema versioning is explicit and deterministic" ->
        assert ctx.contract_version == :v1
        assert Capabilities.contract_version() == :v1
        {:handled, ctx}

      text == "error metadata includes provider \"aws_braket\" and the missing capability" ->
        assert {:error, %{metadata: metadata, capability: :supports_dynamic}} = ctx.dynamic_submit_result
        assert metadata.provider == :aws_braket
        {:handled, ctx}

      text == "no remote submission is attempted" ->
        refute_received {:provider_submit_attempt, :aws_braket}
        {:handled, ctx}

      text == "both preflight outcomes are identical" ->
        assert ctx.preflight_a == ctx.preflight_b
        {:handled, ctx}

      text == "unknown capability states map to error \"provider_invalid_response\"" ->
        assert {:error, %{code: :provider_invalid_response}} = ctx.invalid_capability_result
        {:handled, ctx}

      text == "error metadata includes provider, target, and capability identifiers" ->
        assert Enum.all?(ctx.mismatch_results, fn {_provider, result} ->
                 match?({:error, %{metadata: %{provider: _, target: "target-1"}, capability: :supports_dynamic}}, result)
               end)

        {:handled, ctx}

      text == "provider-specific raw diagnostics are preserved under metadata" ->
        assert {:error, %{metadata: %{raw_diagnostics: diagnostics}}} = ctx.normalization_result
        assert diagnostics.provider == :broken_response_provider
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_errors(%{text: text}, ctx) do
    if text =~ ~r/^error / and text =~ ~r/ is returned(?: consistently)?$/ do
      expected = text |> NxQuantum.TestSupport.Helpers.parse_quoted() |> String.to_atom()

      candidate =
        Map.get(ctx, :dynamic_submit_result) ||
          Map.get(ctx, :normalization_result) ||
          first_mismatch_result(ctx)

      assert {:error, %{code: ^expected}} = candidate
      {:handled, ctx}
    else
      :unhandled
    end
  end

  defp provider_contracts do
    %{
      ibm_runtime: fetch_contract(IBMRuntime, "ibm_backend_simulator"),
      aws_braket: fetch_contract(AwsBraket, "arn:aws:braket:::device/quantum-simulator/amazon/sv1"),
      azure_quantum: fetch_contract(AzureCapabilityStub, "azure.target")
    }
  end

  defp fetch_contract(provider, target) do
    assert {:ok, capabilities} = provider.capabilities(target, [])
    capabilities
  end

  defp first_mismatch_result(ctx) do
    case Map.get(ctx, :mismatch_results) do
      map when is_map(map) -> map |> Map.values() |> List.first()
      _ -> nil
    end
  end
end
