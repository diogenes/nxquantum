defmodule NxQuantum.TestSupport.Fixtures do
  @moduledoc false

  def expectation_for_theta(theta), do: :math.cos(theta)

  def expectation_tensor_for_theta(theta_tensor) do
    Nx.cos(theta_tensor)
  end

  def seeded_step(seed) do
    :rand.seed(:exsplus, {seed + 1, seed + 2, seed + 3})
    init = :rand.uniform()
    grad = :rand.uniform()
    %{init: init, grad: grad, updated: init - 0.1 * grad}
  end

  def symmetric?(matrix, tolerance) do
    {rows, cols} = Nx.shape(matrix)

    Enum.all?(0..(rows - 1), fn i ->
      Enum.all?(0..(cols - 1), fn j ->
        abs(entry(matrix, i, j) - entry(matrix, j, i)) <= tolerance
      end)
    end)
  end

  def psd_by_quadratic_form?(matrix, tolerance) do
    {size, _} = Nx.shape(matrix)

    basis_vectors =
      Enum.map(0..(min(size, 3) - 1), fn i -> standard_basis_vector(i, size) end)

    dense_vectors =
      [
        List.duplicate(1.0, size),
        alternating_sign_vector(size)
      ]

    vectors = basis_vectors ++ dense_vectors

    Enum.all?(vectors, fn v ->
      vt = Nx.tensor(v)
      value = Nx.to_number(Nx.dot(vt, Nx.dot(matrix, vt)))
      value >= -tolerance
    end)
  end

  def validate_dynamic_ir(%{nodes: nodes, registers: registers} = ir) do
    missing =
      Enum.find_value(nodes, fn
        %{type: :conditional_gate, register: reg} -> if MapSet.member?(registers, reg), do: nil, else: reg
        _ -> nil
      end)

    if missing do
      {:error, %{code: :invalid_dynamic_ir, register: missing}}
    else
      {:ok, ir}
    end
  end

  defp entry(matrix, i, j) do
    matrix
    |> Nx.slice([i, j], [1, 1])
    |> Nx.reshape({})
    |> Nx.to_number()
  end

  defp alternating_sign_vector(size) do
    Enum.map(0..(size - 1), fn i ->
      if rem(i, 2) == 0, do: 1.0, else: -1.0
    end)
  end

  defp standard_basis_vector(i, size) do
    Enum.map(0..(size - 1), fn j ->
      if i == j, do: 1.0, else: 0.0
    end)
  end
end
