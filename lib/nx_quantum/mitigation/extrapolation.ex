defmodule NxQuantum.Mitigation.Extrapolation do
  @moduledoc false

  # Shared zero-noise extrapolation math for the Richardson and polynomial
  # least-squares passes. Both estimate f(0) as a fixed linear combination of
  # the measured values, w . y, and propagate per-point standard errors through
  # the same weights: sigma = sqrt(sum_i w_i^2 sigma_i^2), assuming independent
  # per-point errors and an unweighted fit.

  alias NxQuantum.Estimator.Result, as: EstimatorResult
  alias NxQuantum.Mitigation.Trace
  alias NxQuantum.Sampler.Result, as: SamplerResult

  @default_scales [1.0, 2.0, 3.0]
  @default_degree 1
  @minimum_points 2

  @spec apply(term(), keyword(), atom(), :richardson | :poly_ls) :: {:ok, term()} | {:error, map()}
  def apply(result, opts, pass, method) when is_struct(result, EstimatorResult) or is_struct(result, SamplerResult) do
    with {:ok, scales} <- validate_scales(opts),
         {:ok, values} <- validate_values(opts, scales),
         {:ok, std_errors} <- validate_std_errors(opts, scales),
         {:ok, degree} <- validate_degree(method, opts, scales) do
      weights = weights(method, scales, degree)
      value = dot(weights, values)
      std_error = standard_error(weights, std_errors)

      entry = put_degree(%{pass: pass, scales: scales, extrapolated_value: value, std_error: std_error}, method, degree)

      {:ok, %{result | metadata: Trace.append(result.metadata, entry)}}
    end
  end

  def apply(_result, _opts, _pass, _method) do
    {:error, error(reason: :unsupported_result)}
  end

  defp validate_scales(opts) do
    scales = Keyword.get(opts, :scales, @default_scales)

    cond do
      not (is_list(scales) and Enum.all?(scales, &is_number/1)) ->
        {:error, error(reason: :invalid_scales, scales: scales)}

      length(scales) < @minimum_points ->
        {:error, error(reason: :too_few_points, scales: scales, minimum: @minimum_points)}

      length(Enum.uniq(floats(scales))) != length(scales) ->
        {:error, error(reason: :duplicate_scales, scales: scales)}

      true ->
        {:ok, scales}
    end
  end

  defp validate_values(opts, scales) do
    case Keyword.get(opts, :values) do
      nil -> {:error, error(reason: :missing_values)}
      values -> validate_numbers(values, scales, :invalid_values)
    end
  end

  defp validate_std_errors(opts, scales) do
    case Keyword.get(opts, :std_errors) do
      nil ->
        {:ok, nil}

      std_errors ->
        if numbers_of_length?(std_errors, length(scales)) and Enum.all?(std_errors, &(&1 >= 0)) do
          {:ok, std_errors}
        else
          {:error, error(reason: :invalid_std_errors, expected_length: length(scales))}
        end
    end
  end

  defp validate_numbers(values, scales, reason) do
    if numbers_of_length?(values, length(scales)) do
      {:ok, values}
    else
      {:error, error(reason: reason, expected_length: length(scales))}
    end
  end

  defp numbers_of_length?(list, expected) when is_list(list) do
    length(list) == expected and Enum.all?(list, &is_number/1)
  end

  defp numbers_of_length?(_value, _expected), do: false

  defp validate_degree(:richardson, _opts, _scales), do: {:ok, nil}

  defp validate_degree(:poly_ls, opts, scales) do
    degree = Keyword.get(opts, :degree, @default_degree)
    points = length(scales)

    cond do
      not (is_integer(degree) and degree >= 0) ->
        {:error, error(reason: :invalid_degree, degree: degree)}

      degree >= points ->
        {:error, error(reason: :degree_too_large, degree: degree, points: points)}

      true ->
        {:ok, degree}
    end
  end

  defp weights(:richardson, scales, _degree), do: richardson_weights(floats(scales))
  defp weights(:poly_ls, scales, degree), do: poly_ls_weights(floats(scales), degree)

  # Lagrange basis polynomials evaluated at 0: w_i = prod_{j != i} x_j / (x_j - x_i).
  defp richardson_weights(xs) do
    indexed = Enum.with_index(xs)

    for {xi, i} <- indexed do
      Enum.reduce(indexed, 1.0, fn
        {_xj, ^i}, acc -> acc
        {xj, _j}, acc -> acc * xj / (xj - xi)
      end)
    end
  end

  # Unweighted least-squares fit y ~ V c with V the Vandermonde matrix of degree
  # `degree`. The intercept c_0 = e_0' (V'V)^-1 V' y, so the weights are
  # w_i = sum_k z_k x_i^k where z solves (V'V) z = e_0.
  defp poly_ls_weights(xs, degree) do
    vandermonde = Nx.tensor(Enum.map(xs, fn x -> Enum.map(0..degree, &:math.pow(x, &1)) end), type: {:f, 64})
    gram = Nx.dot(Nx.transpose(vandermonde), vandermonde)
    e0 = Nx.tensor([1.0 | List.duplicate(0.0, degree)], type: {:f, 64})

    vandermonde
    |> Nx.dot(Nx.LinAlg.solve(gram, e0))
    |> Nx.to_flat_list()
  end

  defp standard_error(_weights, nil), do: nil

  defp standard_error(weights, std_errors) do
    variance = dot(Enum.map(weights, &(&1 * &1)), Enum.map(std_errors, &(&1 * &1)))
    :math.sqrt(variance)
  end

  defp put_degree(entry, :poly_ls, degree), do: Map.put(entry, :degree, degree)
  defp put_degree(entry, :richardson, _degree), do: entry

  defp dot(a, b) do
    a |> Enum.zip(b) |> Enum.reduce(0.0, fn {x, y}, acc -> acc + x * y end)
  end

  defp floats(values), do: Enum.map(values, &(&1 * 1.0))

  defp error(attrs) do
    attrs
    |> Map.new()
    |> Map.put(:code, :invalid_mitigation_input)
  end
end
