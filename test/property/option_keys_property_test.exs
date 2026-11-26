defmodule NxQuantum.Property.OptionKeysPropertyTest do
  use ExUnit.Case, async: false
  use ExUnitProperties

  import ExUnit.CaptureLog

  alias NxQuantum.Circuit
  alias NxQuantum.Estimator
  alias NxQuantum.Gates
  alias NxQuantum.OptionKeys
  alias NxQuantum.Sampler

  @letters ~w(a b c d e f g h i j k l m n o p q r s t u v w x y z)
  @reproducibility_keys [:seed, :shots, :observable]

  setup do
    %{circuit: [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.1)}
  end

  property "Sampler.run/2 reports a misspelled seed, shots or observable and keeps the default result", %{
    circuit: circuit
  } do
    check all(
            base <- member_of(@reproducibility_keys),
            misspelled <- misspelling(base),
            initial_seed: 0
          ) do
      {:ok, default} = Sampler.run(circuit)

      {result, log} = with_log(fn -> Sampler.run(circuit, [{misspelled, non_default_value(base)}]) end)

      assert {:ok, actual} = result
      assert actual.counts == default.counts
      assert Nx.to_flat_list(actual.probabilities) == Nx.to_flat_list(default.probabilities)
      assert actual.metadata.unknown_options == [misspelled]
      assert log =~ "[#{inspect(misspelled)}]"
    end
  end

  property "Estimator.run/2 reports a misspelled seed, shots or observable and keeps the default result", %{
    circuit: circuit
  } do
    check all(
            base <- member_of(@reproducibility_keys),
            misspelled <- misspelling(base),
            initial_seed: 0
          ) do
      valid_opts = valid_context(base)
      {:ok, default} = Estimator.run(circuit, valid_opts)

      {result, log} =
        with_log(fn -> Estimator.run(circuit, [{misspelled, non_default_value(base)} | valid_opts]) end)

      assert {:ok, actual} = result
      assert Nx.to_flat_list(actual.values) == Nx.to_flat_list(default.values)
      assert actual.metadata.unknown_options == [misspelled]
      assert log =~ "[#{inspect(misspelled)}]"
    end
  end

  # The valid options that keep the misspelled key's effect visible: a seed only matters
  # on a sampled path, so the seed case runs with shots.
  defp valid_context(:seed), do: [shots: 64]
  defp valid_context(_base), do: []

  defp non_default_value(:seed), do: 7
  defp non_default_value(:shots), do: 512
  defp non_default_value(:observable), do: :pauli_x

  # Generated typos of a reproducibility key: one deletion, insertion or replacement
  # of a letter. Anything that is a real option key, or the key itself, is filtered out.
  defp misspelling(base) do
    name = Atom.to_string(base)

    gen =
      gen all(
            index <- integer(0..(byte_size(name) - 1)),
            letter <- member_of(@letters),
            edit <- member_of([:delete, :insert, :replace])
          ) do
        name
        |> edit_name(index, letter, edit)
        |> String.to_atom()
      end

    StreamData.filter(gen, fn key ->
      key != base and key not in OptionKeys.estimator_keys()
    end)
  end

  defp edit_name(name, index, _letter, :delete) do
    name |> String.graphemes() |> List.delete_at(index) |> Enum.join()
  end

  defp edit_name(name, index, letter, :insert) do
    name |> String.graphemes() |> List.insert_at(index, letter) |> Enum.join()
  end

  defp edit_name(name, index, letter, :replace) do
    name |> String.graphemes() |> List.replace_at(index, letter) |> Enum.join()
  end
end
