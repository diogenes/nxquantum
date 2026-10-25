defmodule NxQuantum.Compiler.Theta do
  @moduledoc false

  alias NxQuantum.GateOperation

  @spec value(GateOperation.t()) :: number() | Nx.Tensor.t()
  def value(%GateOperation{params: params}), do: Map.get(params, :theta, 0.0)

  @doc false
  # A tensor angle is negligible only when every element is, so a batched
  # rotation with one non-zero angle is never removed.
  @spec negligible?(number() | Nx.Tensor.t(), number()) :: boolean()
  def negligible?(%Nx.Tensor{} = theta, epsilon) do
    theta |> Nx.abs() |> Nx.reduce_max() |> Nx.to_number() |> Kernel.<(epsilon)
  end

  def negligible?(theta, epsilon) when is_number(theta), do: abs(theta) < epsilon

  @spec put(GateOperation.t(), number() | Nx.Tensor.t()) :: GateOperation.t()
  def put(%GateOperation{} = op, theta) do
    %{op | params: Map.put(op.params, :theta, theta)}
  end

  @spec add(number() | Nx.Tensor.t(), number() | Nx.Tensor.t()) :: number() | Nx.Tensor.t()
  def add(%Nx.Tensor{} = a, %Nx.Tensor{} = b), do: Nx.add(a, b)
  def add(%Nx.Tensor{} = a, b) when is_number(b), do: Nx.add(a, Nx.tensor(b))
  def add(a, %Nx.Tensor{} = b) when is_number(a), do: Nx.add(Nx.tensor(a), b)
  def add(a, b), do: a + b
end
