defmodule NxQuantum.Contracts.EnvelopeDecodeTest do
  @moduledoc """
  Decode contract for stored provider envelopes (H1.2).

  Consumers such as FluxQ persist envelopes as JSON and must be able to resume a job after a restart.
  These tests check the round trip `to_external_map(from_external_map(map)) == map` on the golden snapshots,
  and that a rehydrated job can be polled through the provider bridge in the fixture lane.
  """

  use ExUnit.Case, async: true

  alias NxQuantum.ProviderBridge
  alias NxQuantum.ProviderBridge.Job
  alias NxQuantum.ProviderBridge.ProviderError
  alias NxQuantum.ProviderBridge.Result
  alias NxQuantum.ProviderBridge.Serialization
  alias NxQuantum.TestSupport.ProviderMatrix

  @snapshot_dir Path.expand("../../fixtures/contracts/envelopes", __DIR__)

  for entry <- ProviderMatrix.entries(), kind <- ~w(job result error) do
    @entry entry
    @kind kind

    test "#{entry.id} #{kind} snapshot decodes and re-encodes to the same external map" do
      map = read_snapshot(@entry.id, @kind)

      assert {:ok, decoded} = Serialization.from_external_map(map)
      assert Serialization.to_external_map(decoded) == map
      assert struct_for(@kind) == decoded.__struct__
    end
  end

  for entry <- ProviderMatrix.entries() do
    @entry entry

    test "#{entry.id}: a stored job decodes and polls through the bridge" do
      entry = @entry
      map = read_snapshot(entry.id, "job")
      assert {:ok, %Job{} = job} = Serialization.from_external_map(map)

      opts = [target: entry.target, provider_config: entry.provider_config]
      assert {:ok, %Job{} = polled} = ProviderBridge.poll_job(entry.adapter, job, opts)
      assert polled.id == job.id
      assert polled.state in [:submitted, :queued, :running, :completed]
    end
  end

  test "unsupported schema versions return a typed error" do
    map = read_snapshot(:ibm_runtime, "job")

    assert {:error, %{code: :unsupported_envelope_schema_version, schema_version: "v2", supported: ["v1"]}} =
             Serialization.from_external_map(%{map | "schema_version" => "v2"})
  end

  test "unknown envelope types and malformed input return typed errors" do
    assert {:error, %{code: :unsupported_envelope_type, type: "receipt"}} =
             Serialization.from_external_map(%{"schema_version" => "v1", "type" => "receipt"})

    assert {:error, %{code: :invalid_envelope_shape}} = Serialization.from_external_map(%{"nope" => true})
  end

  test "states, error codes, and operations are whitelisted; no atoms are created from input" do
    map = read_snapshot(:ibm_runtime, "job")

    assert {:error, %{code: :invalid_envelope_state, value: "exploded"}} =
             Serialization.from_external_map(%{map | "state" => "exploded"})

    error_map = read_snapshot(:ibm_runtime, "error")

    assert {:error, %{code: :invalid_envelope_code}} =
             Serialization.from_external_map(%{error_map | "code" => "made_up_code"})

    assert {:error, %{code: :invalid_envelope_operation}} =
             Serialization.from_external_map(%{error_map | "operation" => "delete_everything"})
  end

  defp read_snapshot(provider_id, kind) do
    @snapshot_dir
    |> Path.join("#{provider_id}.#{kind}.json")
    |> File.read!()
    |> Jason.decode!()
  end

  defp struct_for("job"), do: Job
  defp struct_for("result"), do: Result
  defp struct_for("error"), do: ProviderError
end
