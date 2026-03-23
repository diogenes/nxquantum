defmodule NxQuantum.Adapters.Simulators.StateVector.PauliExpval.ExpectationPlan do
  @moduledoc false

  import Bitwise

  alias NxQuantum.Adapters.Simulators.StateVector.Cache
  alias NxQuantum.Adapters.Simulators.StateVector.Matrices

  @type coefficient :: {number(), number()}
  @type pauli_term :: %{
          x_mask: non_neg_integer(),
          z_mask: non_neg_integer(),
          coeff: coefficient()
        }
  @type prepared_term :: map()
  @type strategy :: %{
          mode: :scalar | :parallel,
          max_concurrency: pos_integer(),
          chunk_size: pos_integer()
        }
  @type t :: %__MODULE__{
          qubits: pos_integer(),
          terms: [prepared_term()],
          strategy: strategy(),
          vectorized_bundle: map() | nil
        }

  @enforce_keys [:qubits, :terms, :strategy, :vectorized_bundle]
  defstruct [:qubits, :terms, :strategy, :vectorized_bundle]

  @spec new([pauli_term()], pos_integer(), strategy()) :: t()
  def new(terms, qubits, strategy) when is_list(terms) do
    Cache.fetch(
      {:pauli_expval, :plan, qubits, terms_key(terms), strategy.mode, strategy.chunk_size, strategy.max_concurrency},
      fn ->
        prepared_terms = Enum.map(terms, &prepare_term(&1, qubits))

        %__MODULE__{
          qubits: qubits,
          terms: prepared_terms,
          strategy: strategy,
          vectorized_bundle: nil
        }
      end
    )
  end

  @spec single_term(pauli_term(), pos_integer()) :: t()
  def single_term(term, qubits) do
    prepared = prepare_term(term, qubits)

    %__MODULE__{
      qubits: qubits,
      terms: [prepared],
      strategy: %{mode: :scalar, max_concurrency: 1, chunk_size: 1},
      vectorized_bundle: nil
    }
  end

  defp prepare_term(%{x_mask: x_mask, z_mask: z_mask, coeff: coeff}, qubits) do
    Cache.fetch({:pauli_expval, :term_plan, qubits, x_mask, z_mask, coeff_key(coeff)}, fn ->
      case fast_term_kind(x_mask, z_mask, coeff) do
        {:pauli_x, wire, scale} ->
          %{
            kind: :pauli_x,
            wire: wire,
            scale: scale,
            term_key: {:pauli_x, wire, scale},
            x_mask: x_mask,
            z_mask: z_mask,
            coeff: coeff,
            permutation: Matrices.bit_flip_permutation(x_mask, qubits),
            signs: signs_for_mask(z_mask, qubits)
          }

        {:pauli_y, wire, scale} ->
          %{
            kind: :pauli_y,
            wire: wire,
            scale: scale,
            term_key: {:pauli_y, wire, scale},
            x_mask: x_mask,
            z_mask: z_mask,
            coeff: coeff,
            permutation: Matrices.bit_flip_permutation(x_mask, qubits),
            signs: signs_for_mask(z_mask, qubits)
          }

        {:pauli_z, wire, scale} ->
          %{
            kind: :pauli_z,
            wire: wire,
            scale: scale,
            term_key: {:pauli_z, wire, scale},
            x_mask: x_mask,
            z_mask: z_mask,
            coeff: coeff,
            permutation: Matrices.bit_flip_permutation(x_mask, qubits),
            signs: signs_for_mask(z_mask, qubits)
          }

        :generic ->
          permutation = Matrices.bit_flip_permutation(x_mask, qubits)
          signs = signs_for_mask(z_mask, qubits)
          coeff_tensor = coeff_tensor(coeff)

          %{
            kind: :generic,
            permutation: permutation,
            signs: signs,
            coeff_tensor: coeff_tensor,
            term_key: {:generic, x_mask, z_mask, coeff_key(coeff)},
            x_mask: x_mask,
            z_mask: z_mask,
            coeff: coeff
          }
      end
    end)
  end

  defp fast_term_kind(x_mask, z_mask, {real, imag}) do
    cond do
      pauli_z_term?(x_mask, z_mask, imag) ->
        {:pauli_z, wire_from_single_mask(z_mask), real}

      pauli_x_term?(x_mask, z_mask, imag) ->
        {:pauli_x, wire_from_single_mask(x_mask), real}

      pauli_y_term?(x_mask, z_mask, real) ->
        {:pauli_y, wire_from_single_mask(x_mask), imag}

      true ->
        :generic
    end
  end

  defp pauli_z_term?(x_mask, z_mask, imag), do: x_mask == 0 and single_wire_mask?(z_mask) and near_zero?(imag)

  defp pauli_x_term?(x_mask, z_mask, imag), do: z_mask == 0 and single_wire_mask?(x_mask) and near_zero?(imag)

  defp pauli_y_term?(x_mask, z_mask, real), do: x_mask == z_mask and single_wire_mask?(x_mask) and near_zero?(real)

  defp coeff_tensor({real, imag}) when abs(real - 1.0) < 1.0e-12 and abs(imag) < 1.0e-12, do: nil

  defp coeff_tensor({real, imag}) do
    Nx.complex(Nx.tensor(real, type: {:f, 64}), Nx.tensor(imag, type: {:f, 64}))
  end

  defp coeff_key({real, imag}) when is_float(real) and is_float(imag), do: {real, imag}
  defp coeff_key({real, imag}) when is_integer(real) and is_integer(imag), do: {real * 1.0, imag * 1.0}
  defp coeff_key({real, imag}) when is_number(real) and is_number(imag), do: {real * 1.0, imag * 1.0}

  defp signs_for_mask(0, _qubits), do: nil
  defp signs_for_mask(mask, qubits), do: Matrices.parity_signs(mask, qubits)

  defp terms_key(terms) do
    encoded =
      Enum.map(terms, fn %{x_mask: x_mask, z_mask: z_mask, coeff: coeff} ->
        {x_mask, z_mask, coeff_key(coeff)}
      end)

    :erlang.phash2(encoded)
  end

  defp single_wire_mask?(mask) when is_integer(mask) and mask > 0, do: (mask &&& mask - 1) == 0
  defp single_wire_mask?(_mask), do: false

  defp wire_from_single_mask(mask), do: mask |> :math.log2() |> round()

  defp near_zero?(value), do: abs(value) < 1.0e-12
end
