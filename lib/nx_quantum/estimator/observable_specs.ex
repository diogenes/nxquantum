defmodule NxQuantum.Estimator.ObservableSpecs do
  @moduledoc false

  alias NxQuantum.Observables
  alias NxQuantum.Observables.Schema

  @type observable_spec :: %{observable: Observables.observable(), wire: non_neg_integer()}

  @spec normalize(keyword()) :: {:ok, [observable_spec()]} | {:error, map()}
  def normalize(opts) do
    case Keyword.get(opts, :observables) do
      nil ->
        with {:ok, observable} <- Schema.normalize_observable(Keyword.get(opts, :observable, :pauli_z)),
             {:ok, wire} <- Schema.normalize_wire(Keyword.get(opts, :wire, 0)) do
          {:ok, [%{observable: observable, wire: wire}]}
        end

      observables when is_list(observables) ->
        normalize_observable_list(observables, opts)

      invalid ->
        {:error, %{code: :invalid_observables_option, observables: invalid}}
    end
  end

  defp normalize_observable_list(observables, opts) do
    observables
    |> Enum.reduce_while({:ok, []}, fn item, {:ok, acc} ->
      case normalize_observable_spec(item, opts) do
        {:ok, spec} -> {:cont, {:ok, [spec | acc]}}
        {:error, metadata} -> {:halt, {:error, metadata}}
      end
    end)
    |> case do
      {:ok, specs} -> {:ok, Enum.reverse(specs)}
      error -> error
    end
  end

  defp normalize_observable_spec(%{observable: observable, wire: wire}, _opts) do
    with {:ok, normalized} <- Schema.normalize_observable(observable),
         {:ok, normalized_wire} <- Schema.normalize_wire(wire) do
      {:ok, %{observable: normalized, wire: normalized_wire}}
    end
  end

  defp normalize_observable_spec(observable, opts) when is_atom(observable) do
    with {:ok, normalized} <- Schema.normalize_observable(observable),
         {:ok, wire} <- Schema.normalize_wire(Keyword.get(opts, :wire, 0)) do
      {:ok, %{observable: normalized, wire: wire}}
    end
  end

  defp normalize_observable_spec(invalid, _opts), do: {:error, %{code: :unsupported_observable, observable: invalid}}
end
