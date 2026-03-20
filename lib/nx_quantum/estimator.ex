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

  @spec batched_expectation((Nx.Tensor.t() -> Circuit.t()), Nx.Tensor.t(), keyword()) ::
          {:ok, Nx.Tensor.t()} | {:error, map()}
  def batched_expectation(circuit_builder, %Nx.Tensor{} = params_batch, opts \\ [])
      when is_function(circuit_builder, 1) do
    shape = Nx.shape(params_batch)

    with :ok <- validate_batch_shape(shape),
         results = batch_results(circuit_builder, params_batch, opts),
         nil <- Enum.find(results, &match?({:error, _}, &1)) do
      values =
        results
        |> Enum.map(fn {:ok, tensor} -> Nx.to_number(tensor) end)
        |> Nx.tensor(type: {:f, 32})

      {:ok, values}
    else
      {:error, _} = error -> error
    end
  end

  defp validate_batch_shape(shape) do
    if tuple_size(shape) == 1 do
      :ok
    else
      {:error, %{code: :invalid_batch_shape, expected: {:batch}, received: shape}}
    end
  end

  defp batch_results(circuit_builder, params_batch, opts) do
    params_batch
    |> Nx.to_flat_list()
    |> Enum.map(fn value ->
      value
      |> Nx.tensor()
      |> circuit_builder.()
      |> expectation_result(opts)
    end)
  end
end
