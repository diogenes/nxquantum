defmodule NxQuantum.TestSupport.Helpers do
  @moduledoc false

  def parse_quoted(text) do
    case Regex.run(~r/"([^"]+)"/, text) do
      [_, value] -> value
      _ -> raise ArgumentError, "expected quoted value in #{inspect(text)}"
    end
  end

  def parse_all_quoted(text) do
    ~r/"([^"]+)"/
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
  end

  def parse_quoted_number(text) do
    value = parse_quoted(text)

    case Float.parse(value) do
      {number, ""} ->
        number

      _ ->
        case Integer.parse(value) do
          {number, ""} -> number * 1.0
          _ -> raise ArgumentError, "could not parse number from #{inspect(value)}"
        end
    end
  end

  def parse_list_of_numbers(text) do
    text
    |> Code.eval_string()
    |> elem(0)
    |> Enum.map(&(&1 * 1.0))
  end

  def parse_list_of_ints(text) do
    text
    |> Code.eval_string()
    |> elem(0)
  end

  def parse_edge(text) do
    [_, a, b] = Regex.run(~r/^\(\s*([0-9]+)\s*,\s*([0-9]+)\s*\)$/, String.trim(text))
    {String.to_integer(a), String.to_integer(b)}
  end

  def parse_edge_list(text) do
    ~r/\(\s*([0-9]+)\s*,\s*([0-9]+)\s*\)/
    |> Regex.scan(text, capture: :all_but_first)
    |> Enum.map(fn [a, b] -> {String.to_integer(a), String.to_integer(b)} end)
  end

  def parse_cnot(text) do
    [_, a, b] = Regex.run(~r/cnot\(([0-9]+),([0-9]+)\)/, text)
    {String.to_integer(a), String.to_integer(b)}
  end

  def parse_shape(shape_text) do
    shape_text
    |> String.trim_leading("{")
    |> String.trim_trailing("}")
    |> String.split(",")
    |> Enum.map(&String.trim/1)
    |> Enum.map(&String.to_integer/1)
    |> List.to_tuple()
  end

  def module_name(module), do: module |> Module.split() |> Enum.join(".")
end
