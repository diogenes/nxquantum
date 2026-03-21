defmodule NxQuantum.Adapters.Simulators.StateVector.KeyEncoder do
  @moduledoc false

  @spec theta_key(term()) :: term()
  def theta_key(%Nx.Tensor{} = theta) do
    if Nx.shape(theta) == {} do
      Nx.to_number(theta)
    else
      :erlang.phash2(Nx.to_flat_list(theta))
    end
  end

  def theta_key(theta) when is_number(theta), do: theta
  def theta_key(theta), do: :erlang.phash2(theta)

  @spec execution_plan_key([NxQuantum.GateOperation.t()]) :: list()
  def execution_plan_key(operations) do
    Enum.map(operations, &operation_key/1)
  end

  defp operation_key(%NxQuantum.GateOperation{name: name, wires: wires, params: params}) do
    {name, wires, params_key(params)}
  end

  defp params_key(params) when map_size(params) == 0, do: []

  defp params_key(params) do
    params
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map(fn {key, value} -> {key, param_value_key(value)} end)
  end

  defp param_value_key(%Nx.Tensor{} = tensor) do
    if Nx.shape(tensor) == {} do
      Nx.to_number(tensor)
    else
      :erlang.phash2(Nx.to_flat_list(tensor))
    end
  end

  defp param_value_key(value), do: value
end
