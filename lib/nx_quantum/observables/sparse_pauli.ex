defmodule NxQuantum.Observables.SparsePauli do
  @moduledoc false

  import Bitwise

  @zero_tolerance 1.0e-12

  @type coefficient :: {float(), float()}
  @type pauli_term :: %{
          x_mask: non_neg_integer(),
          z_mask: non_neg_integer(),
          coeff: coefficient()
        }
  @type csr :: %{
          indptr: Nx.Tensor.t(),
          indices: Nx.Tensor.t(),
          data: Nx.Tensor.t(),
          shape: {pos_integer(), pos_integer()},
          nnz: non_neg_integer()
        }
  @type t :: %__MODULE__{
          qubits: pos_integer(),
          terms: [pauli_term()]
        }

  @enforce_keys [:qubits, :terms]
  defstruct [:qubits, :terms]

  @spec new(pos_integer(), [map()], keyword()) :: {:ok, t()} | {:error, map()}
  def new(qubits, terms, _opts \\ []) when is_list(terms) do
    with :ok <- validate_qubits(qubits),
         {:ok, normalized_terms} <- normalize_terms(terms),
         {:ok, validated_terms} <- validate_terms_in_qubits(normalized_terms, qubits) do
      {:ok, %__MODULE__{qubits: qubits, terms: compress_terms(validated_terms)}}
    end
  end

  @spec from_observable_specs(pos_integer(), [map()]) :: {:ok, t()} | {:error, map()}
  def from_observable_specs(qubits, observable_specs) when is_list(observable_specs) do
    with :ok <- validate_qubits(qubits),
         {:ok, terms} <- observable_terms(observable_specs),
         {:ok, validated_terms} <- validate_terms_in_qubits(terms, qubits) do
      {:ok, %__MODULE__{qubits: qubits, terms: compress_terms(validated_terms)}}
    end
  end

  @spec single_pauli_term(atom(), non_neg_integer(), number()) :: {:ok, pauli_term()} | {:error, map()}
  def single_pauli_term(observable, wire, coeff \\ 1.0)

  def single_pauli_term(:pauli_x, wire, coeff) when is_integer(wire) and wire >= 0 do
    with {:ok, coefficient} <- normalize_coefficient(coeff) do
      {:ok, %{x_mask: 1 <<< wire, z_mask: 0, coeff: coefficient}}
    end
  end

  def single_pauli_term(:pauli_y, wire, coeff) when is_integer(wire) and wire >= 0 do
    with {:ok, coefficient} <- normalize_coefficient(coeff) do
      {:ok, %{x_mask: 1 <<< wire, z_mask: 1 <<< wire, coeff: multiply_coefficients(coefficient, {0.0, 1.0})}}
    end
  end

  def single_pauli_term(:pauli_z, wire, coeff) when is_integer(wire) and wire >= 0 do
    with {:ok, coefficient} <- normalize_coefficient(coeff) do
      {:ok, %{x_mask: 0, z_mask: 1 <<< wire, coeff: coefficient}}
    end
  end

  def single_pauli_term(observable, wire, _coeff),
    do: {:error, %{code: :unsupported_observable, observable: observable, wire: wire}}

  @spec to_dense(t(), keyword()) :: Nx.Tensor.t()
  def to_dense(%__MODULE__{} = sparse_pauli, opts \\ []) do
    dim = 1 <<< sparse_pauli.qubits
    entries = entry_map(sparse_pauli, opts)

    real_rows =
      for row <- 0..(dim - 1) do
        for col <- 0..(dim - 1) do
          entries
          |> Map.get({row, col}, {0.0, 0.0})
          |> elem(0)
        end
      end

    imag_rows =
      for row <- 0..(dim - 1) do
        for col <- 0..(dim - 1) do
          entries
          |> Map.get({row, col}, {0.0, 0.0})
          |> elem(1)
        end
      end

    Nx.complex(Nx.tensor(real_rows, type: {:f, 64}), Nx.tensor(imag_rows, type: {:f, 64}))
  end

  @spec to_csr(t(), keyword()) :: csr()
  def to_csr(%__MODULE__{} = sparse_pauli, opts \\ []) do
    dim = 1 <<< sparse_pauli.qubits
    entries = entry_map(sparse_pauli, opts)

    row_entries =
      Enum.reduce(entries, %{}, fn {{row, col}, coeff}, acc ->
        Map.update(acc, row, [{col, coeff}], &[{col, coeff} | &1])
      end)

    {indptr, indices, data, nnz} =
      Enum.reduce(0..(dim - 1), {[0], [], [], 0}, fn row, {indptr, indices, data, nnz} ->
        ordered =
          row_entries
          |> Map.get(row, [])
          |> Enum.sort_by(fn {col, _coeff} -> col end)

        row_indices = Enum.map(ordered, fn {col, _coeff} -> col end)
        row_data = Enum.map(ordered, fn {_col, coeff} -> coeff end)
        new_nnz = nnz + length(row_indices)

        {indptr ++ [new_nnz], indices ++ row_indices, data ++ row_data, new_nnz}
      end)

    %{
      indptr: Nx.tensor(indptr, type: {:s, 64}),
      indices: Nx.tensor(indices, type: {:s, 64}),
      data: coefficient_vector(data),
      shape: {dim, dim},
      nnz: nnz
    }
  end

  @spec diagonal_terms(t()) :: [pauli_term()]
  def diagonal_terms(%__MODULE__{} = sparse_pauli) do
    Enum.filter(sparse_pauli.terms, fn %{x_mask: x_mask} -> x_mask == 0 end)
  end

  defp observable_terms(observable_specs) do
    observable_specs
    |> Enum.reduce_while({:ok, []}, fn %{observable: observable, wire: wire}, {:ok, acc} ->
      case single_pauli_term(observable, wire, 1.0) do
        {:ok, term} -> {:cont, {:ok, [term | acc]}}
        {:error, metadata} -> {:halt, {:error, metadata}}
      end
    end)
    |> case do
      {:ok, terms} -> {:ok, Enum.reverse(terms)}
      {:error, _} = error -> error
    end
  end

  defp normalize_terms(terms) do
    terms
    |> Enum.reduce_while({:ok, []}, fn term, {:ok, acc} ->
      case normalize_term(term) do
        {:ok, normalized} -> {:cont, {:ok, [normalized | acc]}}
        {:error, metadata} -> {:halt, {:error, metadata}}
      end
    end)
    |> case do
      {:ok, normalized} -> {:ok, Enum.reverse(normalized)}
      {:error, _} = error -> error
    end
  end

  defp normalize_term(%{x_mask: x_mask, z_mask: z_mask, coeff: coeff})
       when is_integer(x_mask) and x_mask >= 0 and is_integer(z_mask) and z_mask >= 0 do
    with {:ok, coefficient} <- normalize_coefficient(coeff) do
      {:ok, %{x_mask: x_mask, z_mask: z_mask, coeff: coefficient}}
    end
  end

  defp normalize_term(%{observable: observable, wire: wire} = term) do
    coeff = Map.get(term, :coeff, 1.0)
    single_pauli_term(observable, wire, coeff)
  end

  defp normalize_term(invalid), do: {:error, %{code: :invalid_sparse_pauli_term, term: invalid}}

  defp normalize_coefficient(value) when is_number(value), do: {:ok, {value * 1.0, 0.0}}

  defp normalize_coefficient({real, imag}) when is_number(real) and is_number(imag) do
    {:ok, {real * 1.0, imag * 1.0}}
  end

  defp normalize_coefficient(%Nx.Tensor{} = tensor) do
    {:ok, {Nx.to_number(tensor) * 1.0, 0.0}}
  end

  defp normalize_coefficient(invalid), do: {:error, %{code: :invalid_sparse_pauli_coefficient, coefficient: invalid}}

  defp validate_qubits(qubits) when is_integer(qubits) and qubits >= 1, do: :ok
  defp validate_qubits(qubits), do: {:error, %{code: :invalid_qubit_count, qubits: qubits}}

  defp validate_terms_in_qubits(terms, qubits) do
    max_mask = 1 <<< qubits

    invalid =
      Enum.find(terms, fn %{x_mask: x_mask, z_mask: z_mask} ->
        x_mask >= max_mask or z_mask >= max_mask
      end)

    if invalid do
      {:error, %{code: :sparse_pauli_mask_out_of_range, qubits: qubits, term: invalid}}
    else
      {:ok, terms}
    end
  end

  defp compress_terms(terms) do
    terms
    |> Enum.reduce(%{}, fn %{x_mask: x_mask, z_mask: z_mask, coeff: coeff}, acc ->
      key = {x_mask, z_mask}
      Map.update(acc, key, coeff, &add_coefficients(&1, coeff))
    end)
    |> Enum.reduce([], fn {{x_mask, z_mask}, coeff}, acc ->
      if near_zero?(coeff) do
        acc
      else
        [%{x_mask: x_mask, z_mask: z_mask, coeff: coeff} | acc]
      end
    end)
    |> Enum.sort_by(fn %{x_mask: x_mask, z_mask: z_mask} -> {x_mask, z_mask} end)
  end

  defp entry_map(%__MODULE__{terms: terms, qubits: qubits}, opts) do
    terms
    |> term_entries(qubits, opts)
    |> List.flatten()
    |> Enum.reduce(%{}, fn {row, col, coeff}, acc ->
      Map.update(acc, {row, col}, coeff, &add_coefficients(&1, coeff))
    end)
    |> Enum.reject(fn {_key, coeff} -> near_zero?(coeff) end)
    |> Map.new()
  end

  defp term_entries([], _qubits, _opts), do: []

  defp term_entries(terms, qubits, opts) do
    if parallel_enabled?(terms, opts) do
      max_concurrency = max_concurrency(opts)

      terms
      |> Task.async_stream(fn term -> single_term_entries(term, qubits) end,
        max_concurrency: max_concurrency,
        ordered: true,
        timeout: :infinity
      )
      |> Enum.map(&unwrap_parallel_term_entries_result/1)
    else
      Enum.map(terms, &single_term_entries(&1, qubits))
    end
  end

  defp single_term_entries(%{x_mask: x_mask, z_mask: z_mask, coeff: coeff}, qubits) do
    dim = 1 <<< qubits

    for col <- 0..(dim - 1) do
      row = bxor(col, x_mask)
      sign = if odd_parity?(col &&& z_mask), do: -1.0, else: 1.0
      {row, col, scale_coefficient(coeff, sign)}
    end
  end

  defp coefficient_vector(coefficients) do
    {real, imag} = Enum.unzip(coefficients)
    Nx.complex(Nx.tensor(real, type: {:f, 64}), Nx.tensor(imag, type: {:f, 64}))
  end

  defp scale_coefficient({real, imag}, scalar), do: {real * scalar, imag * scalar}

  defp add_coefficients({ar, ai}, {br, bi}), do: {ar + br, ai + bi}

  defp multiply_coefficients({ar, ai}, {br, bi}) do
    {ar * br - ai * bi, ar * bi + ai * br}
  end

  defp near_zero?({real, imag}) do
    abs(real) < @zero_tolerance and abs(imag) < @zero_tolerance
  end

  defp odd_parity?(value), do: rem(popcount(value), 2) == 1

  defp popcount(value), do: popcount(value, 0)
  defp popcount(0, acc), do: acc
  defp popcount(value, acc), do: popcount(value &&& value - 1, acc + 1)

  defp parallel_enabled?(terms, opts) do
    parallel? = Keyword.get(opts, :parallel, true)
    threshold = Keyword.get(opts, :parallel_threshold, 8)
    parallel? and length(terms) >= threshold
  end

  defp max_concurrency(opts) do
    opts
    |> Keyword.get(:max_concurrency, System.schedulers_online())
    |> case do
      value when is_integer(value) and value > 0 -> value
      _ -> System.schedulers_online()
    end
  end

  @doc false
  def unwrap_parallel_term_entries_result({:ok, result}), do: result

  def unwrap_parallel_term_entries_result({:exit, reason}) do
    raise "parallel sparse-pauli generation failed: #{inspect(reason)}"
  end
end
