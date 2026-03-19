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
         {:ok, profile} <-
           Runtime.resolve(
             runtime_profile,
             fallback_policy: fallback_policy,
             runtime_available?: runtime_available?
           ) do
      tensor = ExecuteCircuit.expectation(measured_circuit, [runtime_profile: profile] ++ opts)

      estimated =
        tensor
        |> Nx.to_number()
        |> Stochastic.apply_noise(opts)
        |> Stochastic.maybe_sample(opts)

      {:ok, Nx.tensor(estimated, type: {:f, 32})}
    end
  end
end
