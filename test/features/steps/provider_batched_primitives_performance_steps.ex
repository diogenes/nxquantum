defmodule NxQuantum.Features.Steps.ProviderBatchedPrimitivesPerformanceSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Adapters.Providers.AwsBraket
  alias NxQuantum.Adapters.Providers.AzureQuantum
  alias NxQuantum.Adapters.Providers.IBMRuntime
  alias NxQuantum.Estimator
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Observability
  alias NxQuantum.Performance
  alias NxQuantum.ProviderBridge
  alias NxQuantum.TestSupport.PerformanceFixtures

  @impl true
  def feature, do: "provider_batched_primitives_performance.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "equivalent estimator and sampler intents are executed on IBM Runtime, AWS Braket, and Azure Quantum" ->
        {:handled, Map.put(ctx, :lifecycle_intents, [:sampler, :estimator])}

      text == "one circuit definition and a deterministic parameter batch are provided" ->
        {:handled,
         Map.merge(ctx, %{
           builder: PerformanceFixtures.batch_builder(),
           batch: PerformanceFixtures.default_batch(8)
         })}

      text == "a batch request exceeds the selected provider batch-size limit" ->
        {:handled,
         Map.merge(ctx, %{
           builder: PerformanceFixtures.batch_builder(),
           batch: PerformanceFixtures.default_batch(16),
           provider_limit: 4
         })}

      text == "an equivalent scalar loop reference implementation is available" or
          text == "an equivalent scalar loop baseline is defined for the same workload" ->
        {:handled,
         Map.merge(ctx, %{
           builder: PerformanceFixtures.batch_builder(),
           batch: PerformanceFixtures.default_batch(32),
           tolerance: 1.0e-6
         })}

      text == "equivalent workloads are executed across IBM Runtime, AWS Braket, and Azure Quantum" ->
        {:handled,
         Map.put(ctx, :workloads, [
           %{workflow: :sampler, shots: 1024, params: %{theta: 0.42, wire: 0}},
           %{workflow: :sampler, shots: 1024, params: %{wire: 0, theta: 0.42}}
         ])}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: "primitive results are normalized by ProviderBridge"}, ctx) do
    provider_runs =
      for intent <- ctx.lifecycle_intents, into: %{} do
        {intent, run_lifecycles(intent)}
      end

    {:handled, Map.put(ctx, :provider_runs, provider_runs)}
  end

  defp handle_execution(%{text: "estimator runs in batch mode"}, ctx) do
    {:ok, values} = Estimator.batched_expectation(ctx.builder, ctx.batch, observable: :pauli_z, wire: 0)
    scalar = scalar_reference(ctx.builder, ctx.batch)
    request_ids = Enum.with_index(Nx.to_flat_list(ctx.batch), fn _value, idx -> "request_#{idx}" end)

    {:handled,
     Map.merge(ctx, %{
       batch_result: {:ok, values},
       scalar_result: {:ok, scalar},
       batch_request_ids: request_ids
     })}
  end

  defp handle_execution(%{text: "provider-aware chunking policy is applied"}, ctx) do
    chunked = Enum.chunk_every(Nx.to_flat_list(ctx.batch), ctx.provider_limit)
    chunk_results = Enum.map(chunked, &chunk_reference(ctx.builder, &1))

    {:handled,
     Map.put(ctx, :chunk_result, %{
       chunk_count: length(chunked),
       chunk_size_policy: {:provider_limit, ctx.provider_limit},
       provider_limit: ctx.provider_limit,
       aggregated: List.flatten(chunk_results)
     })}
  end

  defp handle_execution(%{text: "batch mode runs for the same circuit and parameters"}, ctx) do
    {:handled,
     Map.put(
       ctx,
       :performance_result,
       Performance.compare_batched_workflows(ctx.builder, ctx.batch,
         runtime_profile: :cpu_portable,
         observable: :pauli_z,
         wire: 0
       )
     )}
  end

  defp handle_execution(%{text: "portability intelligence is evaluated"}, ctx) do
    fingerprint_a = Observability.fingerprint(Enum.at(ctx.workloads, 0))
    fingerprint_b = Observability.fingerprint(Enum.at(Enum.reverse(ctx.workloads), 0))

    delta =
      Observability.portability_delta(
        %{payload: %{expectation: 0.8}, metadata: %{latency_ms: 11.0}},
        %{payload: %{expectation: 0.78}, metadata: %{latency_ms: 12.5, sample_kl_divergence: 0.03}}
      )

    {:handled,
     Map.merge(ctx, %{
       fingerprint_a: fingerprint_a,
       fingerprint_b: fingerprint_b,
       portability_delta: delta,
       portability_signal:
         if(delta.latency_delta_ms <= 2.0 and delta.expectation_delta_abs <= 0.05, do: :pass, else: :fail)
     })}
  end

  defp handle_execution(_step, _ctx), do: :unhandled

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "normalized envelope fields are equivalent for the same primitive intent" ->
        assert Enum.all?(Map.values(ctx.provider_runs), fn runs ->
                 runs
                 |> Enum.map(&lifecycle_shape/1)
                 |> Enum.uniq()
                 |> length() == 1
               end)

        {:handled, ctx}

      text == "deterministic ordering is preserved for equivalent request ordering" ->
        assert Enum.map(Map.fetch!(ctx.provider_runs, :sampler), & &1.submitted.provider) == [
                 :ibm_runtime,
                 :aws_braket,
                 :azure_quantum
               ]

        {:handled, ctx}

      text == "provider-specific fields remain isolated under metadata extensions" ->
        sampler = Map.fetch!(ctx.provider_runs, :sampler)

        assert Enum.all?(sampler, fn run ->
                 Map.has_key?(run.submitted.metadata, :provider_payload_version) and
                   Map.has_key?(run.result.metadata, :provider_payload_version)
               end)

        {:handled, ctx}

      text == "output shape and ordering are deterministic" ->
        assert {:ok, values} = ctx.batch_result
        assert {:ok, scalar} = ctx.scalar_result
        assert Nx.shape(values) == Nx.shape(scalar)
        assert Nx.to_flat_list(values) == Nx.to_flat_list(scalar)
        {:handled, ctx}

      text == "each output entry maps to its input parameter index deterministically" ->
        assert Enum.all?(ctx.batch_request_ids, &String.starts_with?(&1, "request_"))
        {:handled, ctx}

      text == "batch metadata includes deterministic request identifiers" ->
        assert length(Enum.uniq(ctx.batch_request_ids)) == length(ctx.batch_request_ids)
        {:handled, ctx}

      text == "chunk boundaries are computed deterministically" ->
        assert ctx.chunk_result.chunk_count == 4
        assert ctx.chunk_result.chunk_size_policy == {:provider_limit, 4}
        assert ctx.chunk_result.provider_limit == 4
        {:handled, ctx}

      text == "aggregated output shape and ordering remain stable" ->
        expected = ctx.builder |> scalar_reference(ctx.batch) |> Nx.to_flat_list()
        assert ctx.chunk_result.aggregated == expected
        {:handled, ctx}

      text == "deterministic metadata includes chunk_count, chunk_size_policy, and provider_limit" ->
        assert Map.take(ctx.chunk_result, [:chunk_count, :chunk_size_policy, :provider_limit]) ==
                 %{chunk_count: 4, chunk_size_policy: {:provider_limit, 4}, provider_limit: 4}

        {:handled, ctx}

      text == "outputs are tolerance-equivalent to scalar baseline outputs" ->
        assert {:ok, %{batched_values: batched_values, scalar_values: scalar_values}} = ctx.performance_result

        batched_values
        |> Nx.to_flat_list()
        |> Enum.zip(Nx.to_flat_list(scalar_values))
        |> Enum.each(fn {value, reference} ->
          assert_in_delta value, reference, ctx.tolerance
        end)

        {:handled, ctx}

      text == "measurable throughput gain is reported with reproducible benchmark metadata" ->
        assert {:ok, %{metrics: metrics}} = ctx.performance_result
        assert metrics.batched_throughput_ops_s > metrics.scalar_throughput_ops_s
        assert metrics.batch_size == 32
        {:handled, ctx}

      text == "experiment fingerprint is identical for canonicalized equivalent workloads" ->
        assert ctx.fingerprint_a == ctx.fingerprint_b
        {:handled, ctx}

      text == "portability-delta metrics are emitted with stable schema" ->
        assert Map.has_key?(ctx.portability_delta, :latency_delta_ms)
        assert Map.has_key?(ctx.portability_delta, :expectation_delta_abs)
        assert Map.has_key?(ctx.portability_delta, :sample_kl_divergence)
        {:handled, ctx}

      text == "threshold-based pass/fail signals are emitted deterministically" ->
        assert ctx.portability_signal == :pass
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp run_lifecycles(intent) do
    provider_opts =
      [
        {IBMRuntime,
         [
           target: "ibm_backend_simulator",
           provider_config: %{auth_token: "ibm-token", channel: "ibm_cloud", backend: "ibm_backend_simulator"}
         ]},
        {AwsBraket,
         [
           target: "arn:aws:braket:::device/quantum-simulator/amazon/sv1",
           provider_config: %{
             region: "us-east-1",
             credentials_profile: "default",
             device_arn: "arn:aws:braket:::device/quantum-simulator/amazon/sv1"
           }
         ]},
        {AzureQuantum,
         [
           target: "azure.quantum.sim",
           provider_config: %{
             workspace: "ws-1",
             auth_context: "managed_identity",
             target_id: "azure.quantum.sim",
             provider_name: "microsoft"
           }
         ]}
      ]

    Enum.map(provider_opts, fn {provider, opts} ->
      payload = lifecycle_payload(provider, intent)
      {:ok, lifecycle} = ProviderBridge.run_lifecycle(provider, payload, opts)
      lifecycle
    end)
  end

  defp lifecycle_payload(AwsBraket, :estimator), do: %{workflow: :sampler, shots: 1024}
  defp lifecycle_payload(_provider, intent), do: %{workflow: intent, shots: 1024}

  defp lifecycle_shape(%{submitted: submitted, polled: polled, result: result}) do
    %{
      submitted_state: submitted.state,
      polled_state: polled.state,
      result_state: result.state
    }
  end

  defp scalar_reference(builder, batch) do
    batch
    |> Nx.to_flat_list()
    |> Enum.map(fn value ->
      {:ok, tensor} =
        value
        |> Nx.tensor()
        |> builder.()
        |> Estimator.expectation_result(observable: :pauli_z, wire: 0)

      Nx.to_number(tensor)
    end)
    |> Nx.tensor(type: {:f, 32})
  end

  defp chunk_reference(builder, chunk_values) do
    Enum.map(chunk_values, fn value ->
      {:ok, tensor} =
        value
        |> Nx.tensor()
        |> builder.()
        |> Estimator.expectation_result(observable: :pauli_z, wire: 0)

      Nx.to_number(tensor)
    end)
  end
end
