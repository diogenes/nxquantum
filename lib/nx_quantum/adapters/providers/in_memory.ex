defmodule NxQuantum.Adapters.Providers.InMemory do
  @moduledoc false

  @behaviour NxQuantum.Ports.Provider

  @impl true
  def provider_id, do: :in_memory_provider

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
       target_class: :simulator
     }}
  end

  @impl true
  def submit(payload, opts \\ []) when is_map(payload) do
    job = %{
      id: "job_" <> Integer.to_string(:erlang.phash2(payload)),
      state: :submitted,
      provider: provider_id(),
      target: Keyword.get(opts, :target, "in_memory"),
      payload: payload,
      simulate_timeout: Keyword.get(opts, :simulate_timeout, false)
    }

    {:ok, job}
  end

  @impl true
  def poll(%{simulate_timeout: true}, _opts), do: {:error, :timeout}
  def poll(%{state: :cancelled} = job, _opts), do: {:ok, job}

  def poll(%{} = job, _opts) do
    {:ok, %{job | state: :completed}}
  end

  @impl true
  def cancel(%{} = job, _opts) do
    {:ok, %{job | state: :cancelled}}
  end

  @impl true
  def fetch_result(%{id: id, state: :completed, payload: payload, target: target}, _opts) do
    {:ok, %{job_id: id, state: :completed, provider: provider_id(), target: target, payload: payload}}
  end

  def fetch_result(%{state: state}, _opts) do
    {:error, {:invalid_state, state}}
  end
end
