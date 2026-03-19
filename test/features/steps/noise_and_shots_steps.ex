defmodule NxQuantum.Features.Steps.NoiseAndShotsSteps do
  @moduledoc false

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Gates
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "noise_and_shots.feature"

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
      text == "a one-qubit circuit with expectation observable Pauli-Z" ->
        circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.2)
        {:handled, Map.put(ctx, :circuit, %{circuit | measurement: %{observable: :pauli_z, wire: 0}})}

      text =~ ~r/^shot count is / ->
        {:handled, Map.put(ctx, :shots, trunc(Helpers.parse_quoted_number(text)))}

      text =~ ~r/^random seed is / ->
        {:handled, Map.put(ctx, :seed, trunc(Helpers.parse_quoted_number(text)))}

      text =~ ~r/^a one-qubit circuit with analytical expectation / ->
        analytical = Helpers.parse_quoted_number(text)
        circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: :math.acos(analytical))

        updated =
          ctx
          |> Map.put(:circuit, %{circuit | measurement: %{observable: :pauli_z, wire: 0}})
          |> Map.put(:ideal, analytical)

        {:handled, updated}

      text =~ ~r/^a one-qubit circuit with ideal expectation / ->
        ideal = Helpers.parse_quoted_number(text)
        circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: :math.acos(ideal))
        {:handled, Map.put(ctx, :circuit, %{circuit | measurement: %{observable: :pauli_z, wire: 0}})}

      text =~ ~r/^depolarizing probability is / ->
        {:handled, Map.put(ctx, :depolarizing, Helpers.parse_quoted_number(text))}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I estimate expectation by shots twice" ->
        {:ok, a} = Estimator.expectation_result(ctx.circuit, shots: ctx.shots, seed: ctx.seed)
        {:ok, b} = Estimator.expectation_result(ctx.circuit, shots: ctx.shots, seed: ctx.seed)
        {:handled, ctx |> Map.put(:a, Nx.to_number(a)) |> Map.put(:b, Nx.to_number(b))}

      text =~ ~r/^I estimate expectation with / ->
        shots = ~r/"([0-9]+)"/ |> Regex.run(text) |> List.last() |> String.to_integer()
        {:ok, est} = Estimator.expectation_result(ctx.circuit, shots: shots, seed: 9)
        key = if shots < 1000, do: :low, else: :high
        {:handled, Map.put(ctx, key, Nx.to_number(est))}

      text == "I evaluate expectation with depolarizing noise" ->
        {:ok, noisy} =
          Estimator.expectation_result(ctx.circuit, noise: [depolarizing: ctx.depolarizing])

        {:handled, Map.put(ctx, :noisy, Nx.to_number(noisy))}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text == "both estimates are exactly equal" ->
        assert ctx.a == ctx.b
        {:handled, ctx}

      text =~ ~r/^the \"8192\"-shot estimate is closer to / ->
        ideal = ctx.ideal
        assert abs(ctx.high - ideal) <= abs(ctx.low - ideal)
        {:handled, ctx}

      text =~ ~r/^noisy expectation absolute value is less than / ->
        assert abs(ctx.noisy) < Helpers.parse_quoted_number(text)
        {:handled, ctx}

      true ->
        :unhandled
    end
  end
end
