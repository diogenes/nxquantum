defmodule NxQuantum.Estimator.SampledExpval do
  @moduledoc false

  alias NxQuantum.Estimator.SampledExpval.CountsReducer
  alias NxQuantum.Estimator.SampledExpval.MaskLookupCache
  alias NxQuantum.Estimator.ObservableSpecs
  alias NxQuantum.Estimator.SampledExpval.ParsedCounts
  alias NxQuantum.Observables.SparsePauli

  @zero_tolerance 1.0e-12

  @spec from_counts(map(), keyword()) :: {:ok, Nx.Tensor.t()} | {:error, map()}
  def from_counts(counts, opts) when is_map(counts) do
    with {:ok, parsed} <- ParsedCounts.parse(counts, opts),
         {:ok, targets} <- normalize_targets(parsed.qubits, opts) do
      evaluate_targets(parsed, targets, opts)
    end
  end

  def from_counts(invalid, _opts), do: {:error, %{code: :invalid_counts_payload, counts: invalid}}

  defp normalize_targets(qubits, opts) do
    case Keyword.get(opts, :sparse_pauli) do
      %SparsePauli{} = sparse_pauli ->
        if sparse_pauli.qubits == qubits do
          {:ok, {:sparse_pauli, sparse_pauli}}
        else
          {:error, %{code: :sparse_pauli_qubit_mismatch, counts_qubits: qubits, pauli_qubits: sparse_pauli.qubits}}
        end

      nil ->
        case ObservableSpecs.normalize(opts) do
          {:ok, observable_specs} -> {:ok, {:observable_specs, observable_specs}}
          {:error, _} = error -> error
        end

      invalid ->
        {:error, %{code: :invalid_sparse_pauli_option, sparse_pauli: invalid}}
    end
  end

  defp evaluate_targets(parsed, {:observable_specs, observable_specs}, opts) do
    with {:ok, terms} <- observable_terms(observable_specs) do
      with :ok <- ensure_diagonal_terms(terms),
           :ok <- ensure_real_coefficients(terms) do
        values = evaluate_terms(parsed, terms, opts)
        tensor = Nx.tensor(values, type: {:f, 32})

        if length(values) == 1 do
          {:ok, Nx.squeeze(tensor)}
        else
          {:ok, tensor}
        end
      end
    end
  end

  defp evaluate_targets(parsed, {:sparse_pauli, sparse_pauli}, opts) do
    terms = sparse_pauli.terms

    with :ok <- ensure_diagonal_terms(terms),
         :ok <- ensure_real_coefficients(terms) do
      value = evaluate_sparse_sum(parsed, terms, opts)
      {:ok, Nx.tensor(value, type: {:f, 32})}
    end
  end

  defp observable_terms(observable_specs) do
    observable_specs
    |> Enum.reduce_while({:ok, []}, fn %{observable: observable, wire: wire}, {:ok, acc} ->
      case SparsePauli.single_pauli_term(observable, wire, 1.0) do
        {:ok, term} -> {:cont, {:ok, [term | acc]}}
        {:error, metadata} -> {:halt, {:error, metadata}}
      end
    end)
    |> case do
      {:ok, terms} -> {:ok, Enum.reverse(terms)}
      {:error, _} = error -> error
    end
  end

  defp evaluate_terms(parsed, terms, opts) do
    lookup = z_mask_expectation_lookup(parsed, terms, opts)

    Enum.map(terms, fn %{z_mask: z_mask} ->
      Map.fetch!(lookup, z_mask)
    end)
  end

  defp evaluate_sparse_sum(parsed, terms, opts) do
    lookup = z_mask_expectation_lookup(parsed, terms, opts)

    Enum.reduce(terms, 0.0, fn %{z_mask: z_mask, coeff: {real, _imag}}, acc ->
      acc + real * Map.fetch!(lookup, z_mask)
    end)
  end

  defp z_mask_expectation_lookup(parsed, terms, opts) do
    %{unique_masks: unique_masks} = MaskLookupCache.for_terms(terms, opts)
    CountsReducer.lookup(parsed, unique_masks, opts)
  end

  defp ensure_diagonal_terms(terms) do
    case Enum.find(terms, fn %{x_mask: x_mask} -> x_mask != 0 end) do
      nil -> :ok
      term -> {:error, %{code: :unsupported_sampled_non_diagonal_term, term: term}}
    end
  end

  defp ensure_real_coefficients(terms) do
    case Enum.find(terms, fn %{coeff: {_real, imag}} -> abs(imag) > @zero_tolerance end) do
      nil -> :ok
      term -> {:error, %{code: :unsupported_sampled_complex_coefficient, term: term}}
    end
  end
end
