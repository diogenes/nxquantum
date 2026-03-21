defmodule NxQuantum.Estimator.Scalar do
  @moduledoc false

  alias NxQuantum.Application.ExecuteCircuit
  alias NxQuantum.Circuit
  alias NxQuantum.Estimator.Measurement
  alias NxQuantum.Estimator.Stochastic
  alias NxQuantum.Runtime

  @spec run(Circuit.t(), keyword()) :: {:ok, Nx.Tensor.t()} | {:error, map()}
  def run(%Circuit{} = circuit, opts) do
    runtime_profile = Keyword.get(opts, :runtime_profile, :cpu_portable)
    fallback_policy = Keyword.get(opts, :fallback_policy, :strict)
    runtime_available? = Keyword.get(opts, :runtime_available?, true)

    with {:ok, measured_circuit} <- Measurement.apply(circuit, opts),
         {:ok, profile} <- resolve_runtime_profile(runtime_profile, fallback_policy, runtime_available?) do
      tensor = ExecuteCircuit.expectation(measured_circuit, [runtime_profile: profile] ++ opts)

      if stochastic_required?(opts) do
        estimated =
          tensor
          |> Nx.to_number()
          |> Stochastic.apply_noise(opts)
          |> Stochastic.maybe_sample(opts)

        {:ok, Nx.tensor(estimated, type: {:f, 32})}
      else
        {:ok, Nx.as_type(tensor, {:f, 32})}
      end
    end
  end

  defp resolve_runtime_profile(:cpu_portable, _fallback_policy, true) do
    {:ok, Runtime.profile!(:cpu_portable)}
  end

  defp resolve_runtime_profile(runtime_profile, fallback_policy, runtime_available?) do
    Runtime.resolve(
      runtime_profile,
      fallback_policy: fallback_policy,
      runtime_available?: runtime_available?
    )
  end

  defp stochastic_required?(opts) do
    sampling_enabled?(opts) or non_zero_noise?(opts)
  end

  defp sampling_enabled?(opts) do
    case Keyword.get(opts, :shots) do
      shots when is_integer(shots) and shots > 0 -> true
      _ -> false
    end
  end

  defp non_zero_noise?(opts) do
    noise = Keyword.get(opts, :noise, [])
    depolarizing = Keyword.get(noise, :depolarizing, 0.0)
    amplitude_damping = Keyword.get(noise, :amplitude_damping, 0.0)
    depolarizing != 0.0 or amplitude_damping != 0.0
  end
end
