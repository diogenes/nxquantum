defmodule NxQuantum.Grad.Numeric do
  @moduledoc false

  @spec finite_difference((Nx.Tensor.t() -> Nx.Tensor.t()), Nx.Tensor.t(), number()) ::
          {Nx.Tensor.t(), Nx.Tensor.t()}
  def finite_difference(fun, %Nx.Tensor{} = params, epsilon) do
    value = fun.(params)
    shape = Nx.shape(params)
    base = Nx.to_flat_list(params)

    grads =
      base
      |> Enum.with_index()
      |> Enum.map(fn {_value, index} ->
        plus = update_flat(base, index, &(&1 + epsilon))
        minus = update_flat(base, index, &(&1 - epsilon))

        numerator =
          scalar(fun.(to_tensor(plus, shape))) - scalar(fun.(to_tensor(minus, shape)))

        numerator / (2.0 * epsilon)
      end)

    {value, to_tensor(grads, shape)}
  end

  @spec parameter_shift((Nx.Tensor.t() -> Nx.Tensor.t()), Nx.Tensor.t(), number()) ::
          {Nx.Tensor.t(), Nx.Tensor.t()}
  def parameter_shift(fun, %Nx.Tensor{} = params, shift) do
    value = fun.(params)
    shape = Nx.shape(params)
    base = Nx.to_flat_list(params)

    grads =
      base
      |> Enum.with_index()
      |> Enum.map(fn {_value, index} ->
        plus = update_flat(base, index, &(&1 + shift))
        minus = update_flat(base, index, &(&1 - shift))
        0.5 * (scalar(fun.(to_tensor(plus, shape))) - scalar(fun.(to_tensor(minus, shape))))
      end)

    {value, to_tensor(grads, shape)}
  end

  defp to_tensor(values, shape) do
    values
    |> Nx.tensor(type: {:f, 64})
    |> Nx.reshape(shape)
  end

  defp scalar(%Nx.Tensor{} = tensor), do: Nx.to_number(tensor)

  defp update_flat(list, index, fun) do
    List.update_at(list, index, fn value -> fun.(value * 1.0) end)
  end
end
