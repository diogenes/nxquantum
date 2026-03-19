defmodule NxQuantum.Features.Steps.QuantumKernelMethodsSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Kernels
  alias NxQuantum.TestSupport.Fixtures
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "quantum_kernel_methods.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: "a deterministic feature-map circuit"}, ctx), do: {:handled, ctx}

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text =~ ~r/^dataset X with shape / ->
        shape = Helpers.parse_quoted(text)

        x =
          case shape do
            "{16,4}" -> {16, 4} |> Nx.iota() |> Nx.divide(16.0)
            "{8,2}" -> {8, 2} |> Nx.iota() |> Nx.divide(8.0)
          end

        {:handled, Map.put(ctx, :x, x)}

      text =~ ~r/^random seed is / ->
        {:handled, Map.put(ctx, :seed, trunc(Helpers.parse_quoted_number(text)))}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: "I generate the kernel matrix K for X"}, ctx) do
    k = Kernels.matrix(ctx.x, gamma: 0.7, seed: Map.get(ctx, :seed, 0))
    {:handled, Map.put(ctx, :k, k)}
  end

  defp handle_execution(_step, _ctx), do: :unhandled

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text =~ ~r/^K has shape / ->
        assert Nx.shape(ctx.k) == Helpers.parse_shape(Helpers.parse_quoted(text))
        {:handled, ctx}

      text =~ ~r/^K is symmetric within tolerance / ->
        tol = Helpers.parse_quoted_number(text)
        assert Fixtures.symmetric?(ctx.k, tol)
        {:handled, ctx}

      text == "repeating generation with the same seed yields identical K" ->
        k2 = Kernels.matrix(ctx.x, gamma: 0.7, seed: ctx.seed)
        assert Nx.to_flat_list(ctx.k) == Nx.to_flat_list(k2)
        {:handled, ctx}

      text =~ ~r/^minimum eigenvalue of K is greater than or equal to / ->
        threshold = Helpers.parse_quoted_number(text)
        assert Fixtures.psd_by_quadratic_form?(ctx.k, abs(threshold))
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
