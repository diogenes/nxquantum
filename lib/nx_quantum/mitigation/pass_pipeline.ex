defmodule NxQuantum.Mitigation.PassPipeline do
  @moduledoc false

  alias NxQuantum.Mitigation.Passes.Readout
  alias NxQuantum.Mitigation.Passes.ZneLinear

  @spec run(term(), list()) :: {:ok, term()} | {:error, map()}
  def run(result, passes) when is_list(passes) do
    Enum.reduce_while(passes, {:ok, result}, fn pass, {:ok, acc} ->
      case apply_pass(acc, pass) do
        {:ok, updated} -> {:cont, {:ok, updated}}
        {:error, metadata} -> {:halt, {:error, metadata}}
      end
    end)
  end

  defp apply_pass(result, {:readout, opts}), do: Readout.apply(result, opts)
  defp apply_pass(result, {:zne_linear, opts}), do: ZneLinear.apply(result, opts)
  defp apply_pass(_result, {unknown, _opts}), do: {:error, %{code: :unsupported_mitigation_pass, pass: unknown}}
  defp apply_pass(_result, invalid), do: {:error, %{code: :unsupported_mitigation_pass, pass: invalid}}
end
