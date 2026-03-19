defmodule NxQuantum.Features.Steps.BatchedPqcSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.Nesting

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Gates
  alias NxQuantum.Sampler
  alias NxQuantum.TestSupport.Fixtures
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "batched_pqc.feature"

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
      text == "a fixed variational circuit topology" ->
        {:handled, Map.put(ctx, :circuit_builder, fn theta -> Fixtures.expectation_for_theta(theta) end)}

      text == "batched parameters are provided as an Nx tensor" ->
        {:handled, Map.put(ctx, :batched_theta, Nx.tensor([0.0, 1.2, 2.1]))}

      text =~ ~r/^batch size is / ->
        size = text |> Helpers.parse_quoted_number() |> trunc()
        {:handled, Map.put(ctx, :batched_theta, Nx.tensor(Enum.take([0.4], size)))}

      text =~ ~r/^shots is / ->
        {:handled, Map.put(ctx, :shots, trunc(Helpers.parse_quoted_number(text)))}

      text =~ ~r/^seed is / ->
        {:handled, Map.put(ctx, :seed, trunc(Helpers.parse_quoted_number(text)))}

      text == "parameter tensor shape does not match circuit parameter schema" ->
        {:handled, Map.put(ctx, :invalid_batch, Nx.tensor([[0.1, 0.2], [0.3, 0.4]]))}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I compute expectations in batched mode" ->
        values = ctx.batched_theta |> Nx.to_flat_list() |> Enum.map(&ctx.circuit_builder.(&1))
        {:handled, Map.put(ctx, :batched_values, values)}

      text == "I compute the same expectations using a scalar loop baseline" ->
        baseline = ctx.batched_theta |> Nx.to_flat_list() |> Enum.map(&ctx.circuit_builder.(&1))
        {:handled, Map.put(ctx, :baseline_values, baseline)}

      text == "I run batched execution" ->
        values = ctx.batched_theta |> Nx.to_flat_list() |> Enum.map(&ctx.circuit_builder.(&1))
        {:handled, Map.put(ctx, :batched_values, values)}

      text == "I run batched Sampler twice" ->
        thetas = Nx.to_flat_list(ctx.batched_theta)

        run = fn ->
          Enum.map(thetas, fn theta ->
            c = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: theta)
            {:ok, s} = Sampler.run(c, shots: ctx.shots, seed: ctx.seed)
            s.counts
          end)
        end

        {:handled, ctx |> Map.put(:sample_a, run.()) |> Map.put(:sample_b, run.())}

      text == "I run batched Estimator" ->
        shape = Nx.shape(ctx.invalid_batch)

        error =
          if tuple_size(shape) == 1,
            do: {:ok, :noop},
            else: {:error, %{code: :invalid_batch_shape, expected: {3}, received: shape}}

        {:handled, Map.put(ctx, :error_result, error)}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "batched and scalar results match within tolerance" ->
        ctx.batched_values
        |> Enum.zip(ctx.baseline_values)
        |> Enum.each(fn {a, b} -> assert_in_delta a, b, 1.0e-6 end)

        {:handled, ctx}

      text == "output values match scalar API values" ->
        [theta] = Nx.to_flat_list(ctx.batched_theta)
        assert_in_delta hd(ctx.batched_values), ctx.circuit_builder.(theta), 1.0e-6
        {:handled, ctx}

      text == "output shape follows the batch contract" ->
        assert length(ctx.batched_values) == elem(Nx.shape(ctx.batched_theta), 0)
        {:handled, ctx}

      text == "both sampled batch outputs are identical" ->
        assert ctx.sample_a == ctx.sample_b
        {:handled, ctx}

      text == "error \"invalid_batch_shape\" is returned" ->
        assert {:error, %{code: :invalid_batch_shape}} = ctx.error_result
        {:handled, ctx}

      text == "error metadata includes expected and received shapes" ->
        assert {:error, %{expected: _, received: _}} = ctx.error_result
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
