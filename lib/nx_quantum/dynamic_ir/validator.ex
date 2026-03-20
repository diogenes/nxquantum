defmodule NxQuantum.DynamicIR.Validator do
  @moduledoc false

  @type ir_node :: %{required(:type) => atom(), optional(atom()) => term()}
  @type t :: %{nodes: [ir_node()], registers: MapSet.t(String.t())}

  @spec validate(t()) :: {:ok, t()} | {:error, map()}
  def validate(%{nodes: nodes, registers: registers} = ir) when is_list(nodes) do
    with :ok <- validate_registers_type(registers),
         :ok <- validate_nodes(nodes) do
      validate_dependencies(ir)
    end
  end

  def validate(_invalid) do
    {:error, %{code: :invalid_dynamic_ir, reason: :invalid_ir_shape}}
  end

  defp validate_registers_type(registers) do
    if match?(%MapSet{}, registers),
      do: :ok,
      else: {:error, %{code: :invalid_dynamic_ir, reason: :invalid_register_set}}
  end

  defp validate_nodes(nodes) do
    if Enum.all?(nodes, &is_map/1),
      do: :ok,
      else: {:error, %{code: :invalid_dynamic_ir, reason: :invalid_node_shape}}
  end

  defp validate_dependencies(%{nodes: nodes, registers: declared} = ir) do
    validation =
      Enum.reduce_while(nodes, MapSet.new(), fn node, produced ->
        validate_dependency_node(node, produced, declared)
      end)

    case validation do
      {:error, _} = error -> error
      _produced -> {:ok, ir}
    end
  end

  defp validate_dependency_node(%{type: :measure, register: register}, produced, _declared) when is_binary(register) do
    {:cont, MapSet.put(produced, register)}
  end

  defp validate_dependency_node(%{type: :conditional_gate, register: register}, produced, declared)
       when is_binary(register) do
    if MapSet.member?(produced, register) or MapSet.member?(declared, register) do
      {:cont, produced}
    else
      {:halt, {:error, %{code: :invalid_dynamic_ir, register: register}}}
    end
  end

  defp validate_dependency_node(%{type: _other}, produced, _declared), do: {:cont, produced}

  defp validate_dependency_node(_invalid, _produced, _declared) do
    {:halt, {:error, %{code: :invalid_dynamic_ir, reason: :invalid_node_shape}}}
  end
end
