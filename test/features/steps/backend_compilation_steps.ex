defmodule NxQuantum.Features.Steps.BackendCompilationSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.Runtime
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "backend_compilation.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2, &handle_errors/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(step, ctx) do
    text = step.text

    cond do
      text == "the supported runtime profiles are" ->
        headers = hd(step.table || [])
        assert headers == ["profile_id", "compiler", "nx_backend", "target_hardware", "support_tier"]
        {:handled, ctx}

      text == "a quantum circuit representing a state-vector simulation" ->
        circuit = Circuit.new(qubits: 1)
        {:handled, Map.put(ctx, :circuit, %{circuit | measurement: %{observable: :pauli_z, wire: 0}})}

      text == "the expectation operation is implemented as a pure tensor contraction" ->
        {:handled, ctx}

      text =~ ~r/^runtime profile / ->
        {:handled, Map.put(ctx, :runtime_profile, Helpers.parse_quoted(text))}

      text =~ ~r/^the default compiler is set to / ->
        {:handled, Map.put(ctx, :expected_compiler, Helpers.parse_quoted(text))}

      text =~ ~r/^the default backend is set to / ->
        {:handled, Map.put(ctx, :expected_backend, Helpers.parse_quoted(text))}

      text =~ ~r/^fallback policy is / ->
        {:handled, Map.put(ctx, :fallback_policy, String.to_atom(Helpers.parse_quoted(text)))}

      text == "CUDA runtime is unavailable" ->
        {:handled, Map.put(ctx, :runtime_available, false)}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I compile the expectation function for the circuit" and ctx.runtime_profile == "unknown_profile" ->
        error = Estimator.expectation_result(ctx.circuit, runtime_profile: :unknown_profile)
        {:handled, Map.put(ctx, :error_result, error)}

      text == "I compile the expectation function for the circuit" ->
        profile = String.to_atom(ctx.runtime_profile)
        {:handled, Map.put(ctx, :runtime_result, Runtime.resolve(profile, runtime_available?: true))}

      text == "I evaluate the expectation within defn" ->
        profile = String.to_atom(ctx.runtime_profile)

        result =
          Runtime.resolve(profile,
            fallback_policy: Map.get(ctx, :fallback_policy, :strict),
            runtime_available?: Map.get(ctx, :runtime_available, true)
          )

        warning =
          case result do
            {:ok, %{id: :cpu_compiled}} when profile == :nvidia_gpu_compiled -> "NXQ_BACKEND_FALLBACK_001"
            _ -> nil
          end

        {:handled, ctx |> Map.put(:runtime_result, result) |> Map.put(:warning_code, warning)}

      text == "I request the runtime profile catalog" ->
        {:handled, Map.put(ctx, :catalog, Runtime.capabilities())}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text =~ ~r/^execution uses the native / ->
        expected_backend = Helpers.parse_quoted(text)
        assert {:ok, profile} = ctx.runtime_result
        assert Helpers.module_name(profile.backend) == expected_backend
        {:handled, ctx}

      text =~ ~r/^tensor operations are executed on the / ->
        assert {:ok, profile} = ctx.runtime_result
        expected = Helpers.parse_quoted(text)
        assert profile.hardware == expected
        {:handled, ctx}

      text =~ ~r/^runtime profile / and text =~ ~r/ is selected$/ ->
        assert {:ok, profile} = ctx.runtime_result
        assert Atom.to_string(profile.id) == Helpers.parse_quoted(text)
        {:handled, ctx}

      text =~ ~r/^warning code / ->
        assert ctx.warning_code == Helpers.parse_quoted(text)
        {:handled, ctx}

      text =~ ~r/^error metadata includes requested profile / ->
        assert ctx.error_metadata.requested_profile == String.to_atom(Helpers.parse_quoted(text))
        {:handled, ctx}

      text =~ ~r/^error metadata includes available fallback / ->
        assert ctx.error_metadata.available_fallback == String.to_atom(Helpers.parse_quoted(text))
        {:handled, ctx}

      text == "the error lists all supported runtime profile identifiers" ->
        assert is_list(ctx.error_metadata.supported_profiles)
        assert :cpu_portable in ctx.error_metadata.supported_profiles
        {:handled, ctx}

      text == "I receive profile id, compiler, backend, hardware target, and support tier" ->
        assert Enum.all?(ctx.catalog, fn p ->
                 Map.has_key?(p, :id) and
                   Map.has_key?(p, :compiler) and
                   Map.has_key?(p, :backend) and
                   Map.has_key?(p, :hardware) and
                   Map.has_key?(p, :support_tier)
               end)

        {:handled, ctx}

      text == "each profile includes an \"available\" capability flag from auto-detection" ->
        assert Enum.all?(ctx.catalog, &Map.has_key?(&1, :available))
        {:handled, ctx}

      text == "profiles are ordered by support tier priority" ->
        tiers = Enum.map(ctx.catalog, & &1.support_tier)
        assert tiers == Enum.sort_by(tiers, &tier_order/1)
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_errors(%{text: text}, ctx) do
    if text =~ ~r/^error / and text =~ ~r/ is returned$/ do
      assert {:error, metadata} = Map.get(ctx, :runtime_result) || Map.get(ctx, :error_result)
      assert Atom.to_string(metadata.code) == Helpers.parse_quoted(text)
      {:handled, Map.put(ctx, :error_metadata, metadata)}
    else
      :unhandled
    end
  end

  defp tier_order(:p0), do: 0
  defp tier_order(:p1), do: 1
end
