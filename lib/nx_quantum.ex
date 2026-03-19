defmodule NxQuantum do
  @moduledoc """
  Public facade for building and executing quantum circuits with Nx-backed simulation.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Runtime
  alias NxQuantum.Sampler

  @spec new_circuit(keyword()) :: Circuit.t()
  defdelegate new_circuit(opts \\ []), to: Circuit, as: :new

  @spec runtime_profiles() :: [Runtime.profile()]
  defdelegate runtime_profiles(), to: Runtime, as: :supported_profiles

  @spec runtime_capabilities(keyword()) :: [map()]
  defdelegate runtime_capabilities(opts \\ []), to: Runtime, as: :capabilities

  @spec estimate(Circuit.t(), keyword()) :: {:ok, Estimator.Result.t()} | {:error, map()}
  defdelegate estimate(circuit, opts \\ []), to: Estimator, as: :run

  @spec sample(Circuit.t(), keyword()) :: {:ok, Sampler.Result.t()} | {:error, map()}
  defdelegate sample(circuit, opts \\ []), to: Sampler, as: :run
end
