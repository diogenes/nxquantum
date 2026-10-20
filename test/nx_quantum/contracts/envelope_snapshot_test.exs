defmodule NxQuantum.Contracts.EnvelopeSnapshotTest do
  @moduledoc """
  Golden snapshots of the external provider envelopes (H1.2).

  Every core provider's job, result, and typed error is serialized in the fixture lane and compared
  byte-for-byte with `test/fixtures/contracts/envelopes/`. Any shape change fails here, before it reaches
  FluxQ's G2 gate. Regenerate deliberately with:

      NXQ_UPDATE_SNAPSHOTS=1 mix test test/nx_quantum/contracts/envelope_snapshot_test.exs

  Regenerating is a contract change: bump `schema_version` and document it in `docs/api-stability.md`.
  """

  use ExUnit.Case, async: true

  alias Jason.OrderedObject
  alias NxQuantum.ProviderBridge
  alias NxQuantum.ProviderBridge.ProviderError
  alias NxQuantum.ProviderBridge.Serialization
  alias NxQuantum.TestSupport.ProviderMatrix

  @snapshot_dir Path.expand("../../fixtures/contracts/envelopes", __DIR__)
  for entry <- ProviderMatrix.entries() do
    @entry entry

    test "#{entry.id}: job, result, and error envelopes match golden snapshots" do
      entry = @entry
      opts = [target: entry.target, provider_config: entry.provider_config]

      assert {:ok, submitted} = ProviderBridge.submit_job(entry.adapter, %{workflow: :sampler, shots: 128}, opts)
      assert {:ok, polled} = ProviderBridge.poll_job(entry.adapter, submitted, opts)
      assert {:ok, result} = ProviderBridge.fetch_result(entry.adapter, polled, opts)

      envelopes = %{
        "job" => Serialization.to_external_map(submitted),
        "result" => Serialization.to_external_map(result),
        "error" => Serialization.to_external_map(fixed_error(entry.id))
      }

      Enum.each(envelopes, fn {kind, map} ->
        assert_snapshot("#{entry.id}.#{kind}", map)
      end)
    end
  end

  test "snapshot directory covers every core provider and envelope kind" do
    expected =
      for entry <- ProviderMatrix.entries(), kind <- ~w(job result error) do
        "#{entry.id}.#{kind}.json"
      end

    present = @snapshot_dir |> File.ls!() |> Enum.sort()

    if update_snapshots?() do
      assert true
    else
      assert Enum.sort(expected) == present
    end
  end

  defp fixed_error(provider_id) do
    %ProviderError{
      code: :provider_rate_limited,
      operation: :poll,
      provider: Atom.to_string(provider_id),
      reason: "rate limit exceeded",
      request_id: "req-fixture-error",
      correlation_id: "corr-fixture-error",
      idempotency_key: "idem-fixture-error",
      schema_version: :v1,
      metadata: %{retry_after_ms: 500}
    }
  end

  defp assert_snapshot(name, map) do
    path = Path.join(@snapshot_dir, name <> ".json")
    canonical = canonical_json(map)

    cond do
      update_snapshots?() ->
        File.mkdir_p!(@snapshot_dir)
        File.write!(path, canonical)

      File.exists?(path) ->
        assert File.read!(path) == canonical, "snapshot #{name} changed; see module doc to regenerate"

      true ->
        flunk("missing snapshot #{path}; generate with NXQ_UPDATE_SNAPSHOTS=1")
    end
  end

  defp update_snapshots?, do: System.get_env("NXQ_UPDATE_SNAPSHOTS") == "1"

  @doc false
  def canonical_json(map) do
    map
    |> sort_keys()
    |> Jason.encode!(pretty: true)
    |> Kernel.<>("\n")
  end

  defp sort_keys(%{} = map) do
    map
    |> Enum.sort_by(fn {key, _} -> to_string(key) end)
    |> Enum.map(fn {key, value} -> {to_string(key), sort_keys(value)} end)
    |> OrderedObject.new()
  end

  defp sort_keys(list) when is_list(list), do: Enum.map(list, &sort_keys/1)
  defp sort_keys(value), do: value
end
