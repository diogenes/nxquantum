defmodule NxQuantum.Compiler.Theta do
  @moduledoc false

  alias NxQuantum.GateOperation

  @spec value(GateOperation.t()) :: number() | Nx.Tensor.t()
  def value(%GateOperation{params: params}), do: Map.get(params, :theta, 0.0)

  @spec to_number(number() | Nx.Tensor.t()) :: number()
  def to_number(%Nx.Tensor{} = theta), do: Nx.to_number(theta)
  def to_number(theta) when is_number(theta), do: theta

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
