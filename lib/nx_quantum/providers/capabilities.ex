defmodule NxQuantum.Providers.Capabilities do
  @moduledoc """
  Provider capability contract v1 validation and deterministic preflight checks.
  """

  alias NxQuantum.ProviderBridge.Errors

  @contract_version :v1

  @required_keys [
    :supports_estimator,
    :supports_sampler,
    :supports_batch,
    :supports_dynamic,
    :supports_cancel_in_running,
    :supports_calibration_payload,
    :target_class
  ]

  @target_classes [:gate_model, :analog, :simulator]

  @type contract_version :: :v1

  @type contract :: %{
          required(:supports_estimator) => boolean(),
          required(:supports_sampler) => boolean(),
          required(:supports_batch) => boolean(),
          required(:supports_dynamic) => boolean(),
          required(:supports_cancel_in_running) => boolean(),
          required(:supports_calibration_payload) => boolean(),
          required(:target_class) => :gate_model | :analog | :simulator
        }

  @type request :: %{
          optional(:workflow) => atom(),
          optional(:dynamic) => boolean(),
          optional(:batch) => boolean(),
          optional(:calibration_payload) => map() | nil
        }

  @spec contract_version() :: contract_version()
  def contract_version, do: @contract_version

  @spec required_keys() :: [atom()]
  def required_keys, do: @required_keys

  @spec validate_contract(map(), atom() | String.t(), atom() | String.t(), String.t() | nil) ::
          {:ok, contract()} | {:error, map()}
  def validate_contract(capabilities, provider, contract_version, target)
      when is_map(capabilities) and contract_version in [:v1, "v1"] do
    cond do
      not Enum.all?(@required_keys, &Map.has_key?(capabilities, &1)) ->
        {:error,
         Errors.invalid_response(:capabilities, provider, capabilities,
           metadata: metadata(provider, target, :missing_required_keys)
         )}

      not booleans?(capabilities) ->
        {:error,
         Errors.invalid_response(:capabilities, provider, capabilities,
           metadata: metadata(provider, target, :invalid_boolean_values)
         )}

      capabilities.target_class not in @target_classes ->
        {:error,
         Errors.invalid_response(:capabilities, provider, capabilities,
           metadata: metadata(provider, target, :invalid_target_class)
         )}

      true ->
        {:ok, Map.take(capabilities, @required_keys)}
    end
  end

  def validate_contract(capabilities, provider, contract_version, target) do
    {:error,
     Errors.invalid_response(:capabilities, provider, capabilities,
       metadata: metadata(provider, target, {:unsupported_contract_version, contract_version})
     )}
  end

  @spec preflight(contract(), request(), atom() | String.t(), String.t() | nil) :: :ok | {:error, map()}
  def preflight(capabilities, request, provider, target) when is_map(capabilities) and is_map(request) do
    with :ok <- check_workflow_capability(capabilities, request, provider, target),
         :ok <- check_dynamic_capability(capabilities, request, provider, target),
         :ok <- check_batch_capability(capabilities, request, provider, target) do
      check_calibration_capability(capabilities, request, provider, target)
    end
  end

  defp check_workflow_capability(capabilities, %{workflow: :estimator}, provider, target),
    do: require_capability(capabilities, :supports_estimator, provider, target)

  defp check_workflow_capability(capabilities, %{workflow: :sampler}, provider, target),
    do: require_capability(capabilities, :supports_sampler, provider, target)

  defp check_workflow_capability(_capabilities, _request, _provider, _target), do: :ok

  defp check_dynamic_capability(capabilities, %{dynamic: true}, provider, target),
    do: require_capability(capabilities, :supports_dynamic, provider, target)

  defp check_dynamic_capability(_capabilities, _request, _provider, _target), do: :ok

  defp check_batch_capability(capabilities, %{batch: true}, provider, target),
    do: require_capability(capabilities, :supports_batch, provider, target)

  defp check_batch_capability(_capabilities, _request, _provider, _target), do: :ok

  defp check_calibration_capability(capabilities, %{calibration_payload: payload}, provider, target)
       when not is_nil(payload) do
    require_capability(capabilities, :supports_calibration_payload, provider, target)
  end

  defp check_calibration_capability(_capabilities, _request, _provider, _target), do: :ok

  defp require_capability(capabilities, key, provider, target) do
    if Map.get(capabilities, key, false) do
      :ok
    else
      {:error,
       Errors.capability_mismatch(:submit, provider, key, metadata: metadata(provider, target, :unsupported_capability))}
    end
  end

  defp booleans?(capabilities) do
    Enum.all?(
      [
        :supports_estimator,
        :supports_sampler,
        :supports_batch,
        :supports_dynamic,
        :supports_cancel_in_running,
        :supports_calibration_payload
      ],
      &(Map.get(capabilities, &1) in [true, false])
    )
  end

  defp metadata(provider, target, reason) do
    %{provider: provider, target: target, reason: reason, capability_contract_version: @contract_version}
  end
end
