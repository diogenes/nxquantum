defmodule NxQuantum.Mitigation.CalibrationPayloadTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Mitigation.CalibrationPayload
  alias NxQuantum.Providers.Redaction

  test "validate/1 accepts 2x2 tensor with metadata" do
    payload = %{
      matrix: Nx.tensor([[0.95, 0.05], [0.04, 0.96]], type: {:f, 32}),
      version: "v1",
      source: "provider"
    }

    assert {:ok, validated} = CalibrationPayload.validate(payload)
    assert validated.version == "v1"
    assert validated.source == "provider"
  end

  test "validate/1 returns typed shape diagnostics for invalid matrix" do
    payload = %{matrix: Nx.tensor([1.0, 0.0], type: {:f, 32}), version: "v1", source: "provider"}

    assert {:error, %{code: :invalid_calibration_payload, expected_shape: {2, 2}, received_shape: {2}}} =
             CalibrationPayload.validate(payload)
  end

  test "metadata/1 exposes calibration_version and calibration_source" do
    payload = %{version: "v2", source: "provider-x"}

    assert %{calibration_version: "v2", calibration_source: "provider-x"} =
             CalibrationPayload.metadata(payload)
  end

  test "redaction preserves diagnostics while masking sensitive calibration fields" do
    payload = %{
      matrix: Nx.tensor([1.0, 0.0], type: {:f, 32}),
      version: "v1",
      source: "provider",
      auth_token: "secret-token",
      nested: %{secret_key: "nested-secret", label: "keep-me"}
    }

    assert {:error, %{code: :invalid_calibration_payload, expected_shape: {2, 2}, received_shape: {2}}} =
             CalibrationPayload.validate(payload)

    redacted = Redaction.redact(payload)
    assert redacted.auth_token == "[REDACTED]"
    assert redacted.nested.secret_key == "[REDACTED]"
    assert redacted.nested.label == "keep-me"
  end
end
