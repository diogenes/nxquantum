defmodule NxQuantum.Features.Steps.PrimitivesApiSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Sampler
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "primitives_api.feature"

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
      text == "a parameterized quantum circuit with declared observables" ->
        {:handled, Map.put(ctx, :circuit, Circuit.new(qubits: 1))}

      text =~ ~r/^runtime profile / ->
        {:handled, Map.put(ctx, :runtime_profile, String.to_atom(Helpers.parse_quoted(text)))}

      text =~ ~r/^an observable list / ->
        list = text |> Helpers.parse_quoted() |> Code.eval_string() |> elem(0)
        {:handled, Map.put(ctx, :observable_list, list)}

      text == "an unsupported observable identifier" ->
        {:handled, Map.put(ctx, :unsupported_observable, :unsupported)}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I run the Estimator primitive twice with the same parameters and seed" ->
        opts = [
          runtime_profile: ctx.runtime_profile,
          observables: [:pauli_z],
          wire: 0,
          shots: 512,
          seed: 7
        ]

        {:ok, a} = Estimator.run(ctx.circuit, opts)
        {:ok, b} = Estimator.run(ctx.circuit, opts)
        {:handled, ctx |> Map.put(:est_a, a) |> Map.put(:est_b, b)}

      text == "I run the Sampler primitive twice with the same shots and seed" ->
        {:ok, a} = Sampler.run(ctx.circuit, runtime_profile: ctx.runtime_profile, shots: 256, seed: 7)
        {:ok, b} = Sampler.run(ctx.circuit, runtime_profile: ctx.runtime_profile, shots: 256, seed: 7)
        {:handled, ctx |> Map.put(:sam_a, a) |> Map.put(:sam_b, b)}

      text == "I run a single Estimator request with that observable list" ->
        {:ok, result} = Estimator.run(ctx.circuit, observables: ctx.observable_list, wire: 0)
        {:handled, Map.put(ctx, :est_batch, result)}

      text == "I run the Estimator primitive" ->
        error = Estimator.run(ctx.circuit, observables: [ctx.unsupported_observable], wire: 0)
        {:handled, Map.put(ctx, :error_result, error)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "both expectation outputs are identical within numeric tolerance" ->
        [a] = Nx.to_flat_list(ctx.est_a.values)
        [b] = Nx.to_flat_list(ctx.est_b.values)
        assert_in_delta a, b, 1.0e-6
        {:handled, ctx}

      text == "the result includes metadata for runtime profile and execution mode" ->
        assert ctx.est_a.metadata.runtime_profile == :cpu_portable
        assert ctx.est_a.metadata.mode == :estimator
        {:handled, ctx}

      text == "both sampled distributions are identical" ->
        assert ctx.sam_a.counts == ctx.sam_b.counts
        {:handled, ctx}

      text == "the total sample count equals the configured shots" ->
        assert Enum.sum(Map.values(ctx.sam_a.counts)) == 256
        {:handled, ctx}

      text == "the output tensor preserves the input observable order" ->
        assert Enum.map(ctx.est_batch.metadata.observables, & &1.observable) == ctx.observable_list
        {:handled, ctx}

      text == "output shape matches the declared observable count" ->
        assert Nx.shape(ctx.est_batch.values) == {length(ctx.observable_list)}
        {:handled, ctx}

      text == "error \"unsupported_observable\" is returned" ->
        assert {:error, %{code: :unsupported_observable}} = ctx.error_result
        {:handled, ctx}

      text == "error metadata includes the invalid observable identifier" ->
        assert {:error, %{observable: :unsupported}} = ctx.error_result
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
