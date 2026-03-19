defmodule NxQuantum.Estimator do
  @moduledoc """
  Execution facade for expectation and probability estimation.

  v0.2 scope:
  - deterministic runtime profile resolution,
  - expectation evaluation through application/service boundaries.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator.Batch
  alias NxQuantum.Estimator.ObservableSpecs
  alias NxQuantum.Estimator.Result
  alias NxQuantum.Estimator.Scalar

  @spec expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()
  def expectation(%Circuit{} = circuit, opts \\ []) do
    case expectation_result(circuit, opts) do
      {:ok, tensor} ->
        tensor

      {:error, metadata} ->
        raise ArgumentError, "runtime profile resolution failed: #{inspect(metadata)}"
    end
  end

  @spec expectation_result(Circuit.t(), keyword()) :: {:ok, Nx.Tensor.t()} | {:error, map()}
  def expectation_result(%Circuit{} = circuit, opts \\ []) do
    Scalar.run(circuit, opts)
  end

  @spec run(Circuit.t(), keyword()) :: {:ok, Result.t()} | {:error, map()}
  def run(%Circuit{} = circuit, opts \\ []) do
    with {:ok, normalized_specs} <- ObservableSpecs.normalize(opts) do
      Batch.run(circuit, normalized_specs, opts)
    end
  end
end
