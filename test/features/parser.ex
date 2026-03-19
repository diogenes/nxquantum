defmodule NxQuantum.Features.Parser do
  @moduledoc false

  defmodule Step do
    @moduledoc false
    @type t :: %__MODULE__{
            keyword: String.t(),
            text: String.t(),
            table: [[String.t()]]
          }
    defstruct [:keyword, :text, table: []]
  end

  defmodule Scenario do
    @moduledoc false
    @type t :: %__MODULE__{
            feature: String.t() | nil,
            rule: String.t() | nil,
            name: String.t(),
            steps: [Step.t()]
          }
    defstruct [:feature, :rule, :name, :steps]
  end

  @spec parse_file(String.t()) :: [Scenario.t()]
  def parse_file(path) do
    lines =
      path
      |> File.read!()
      |> String.split("\n")
      |> Enum.map(&String.trim_trailing/1)

    state = %{
      feature: nil,
      current_rule: nil,
      backgrounds: %{nil => []},
      mode: :idle,
      current: nil,
      scenarios: []
    }

    lines
    |> Enum.with_index(1)
    |> Enum.reduce(state, &consume_line/2)
    |> finalize_current()
    |> Map.fetch!(:scenarios)
    |> Enum.reverse()
    |> Enum.map(fn scenario ->
      %{scenario | feature: path}
    end)
  end

  defp consume_line({raw, _line_no}, state) do
    line = String.trim(raw)
    consume_trimmed_line(line, state)
  end

  defp consume_trimmed_line("", state), do: maybe_finalize_examples(state, "")
  defp consume_trimmed_line("#" <> _comment, state), do: maybe_finalize_examples(state, "")

  defp consume_trimmed_line("Feature:" <> rest, state) do
    %{state | feature: String.trim(rest)}
  end

  defp consume_trimmed_line("Rule:" <> rest, state) do
    maybe_finalize_examples(%{state | current_rule: String.trim(rest)}, "Rule:")
  end

  defp consume_trimmed_line("Background:" <> _rest, state) do
    %{state | mode: {:background, state.current_rule}}
  end

  defp consume_trimmed_line("Scenario Outline:" <> rest, state) do
    state
    |> finalize_current()
    |> Map.put(:mode, :outline_steps)
    |> Map.put(:current, %{
      type: :outline,
      name: String.trim(rest),
      steps: [],
      headers: nil,
      rows: []
    })
  end

  defp consume_trimmed_line("Scenario:" <> rest, state) do
    state
    |> finalize_current()
    |> Map.put(:mode, :scenario_steps)
    |> Map.put(:current, %{type: :scenario, name: String.trim(rest), steps: []})
  end

  defp consume_trimmed_line("Examples:" <> _rest, state), do: %{state | mode: :examples}

  defp consume_trimmed_line(line, state) do
    state
    |> maybe_append_step(line)
    |> maybe_append_table_row(line)
    |> maybe_finalize_examples(line)
  end

  defp maybe_append_step(state, line) do
    if step_keyword?(line), do: append_step(state, line), else: state
  end

  defp maybe_append_table_row(state, line) do
    if table_row?(line), do: append_table_row(state, line), else: state
  end

  defp maybe_finalize_examples(%{mode: :examples} = state, _line) do
    finalize_outline_if_ready(state)
  end

  defp maybe_finalize_examples(state, _line), do: state

  defp finalize_current(%{current: nil} = state), do: finalize_outline_if_ready(state)

  defp finalize_current(%{current: %{type: :scenario} = current} = state) do
    background = background_steps(state.backgrounds, state.current_rule)

    scenario = %Scenario{
      feature: state.feature,
      rule: state.current_rule,
      name: current.name,
      steps: background ++ current.steps
    }

    %{state | current: nil, scenarios: [scenario | state.scenarios], mode: :idle}
  end

  defp finalize_current(%{current: %{type: :outline}} = state), do: finalize_outline_if_ready(state)

  defp finalize_outline_if_ready(%{current: %{type: :outline, headers: headers, rows: rows} = current} = state)
       when is_list(headers) and rows != [] do
    background = background_steps(state.backgrounds, state.current_rule)

    expanded =
      Enum.map(rows, fn row ->
        vars = headers |> Enum.zip(row) |> Map.new()

        %Scenario{
          feature: state.feature,
          rule: state.current_rule,
          name: interpolate(current.name, vars),
          steps: background ++ Enum.map(current.steps, &interpolate_step(&1, vars))
        }
      end)

    %{state | current: nil, mode: :idle, scenarios: Enum.reverse(expanded, state.scenarios)}
  end

  defp finalize_outline_if_ready(state), do: state

  defp append_step(%{mode: {:background, rule}} = state, line) do
    step = parse_step(line)
    backgrounds = Map.update(state.backgrounds, rule, [step], &(&1 ++ [step]))
    %{state | backgrounds: backgrounds}
  end

  defp append_step(%{current: %{steps: steps} = current} = state, line) do
    %{state | current: %{current | steps: steps ++ [parse_step(line)]}}
  end

  defp append_step(state, _line), do: state

  defp append_table_row(%{mode: :examples, current: %{type: :outline} = current} = state, line) do
    cells = parse_table_cells(line)

    updated =
      case current.headers do
        nil -> %{current | headers: cells}
        _ -> %{current | rows: current.rows ++ [cells]}
      end

    %{state | current: updated}
  end

  defp append_table_row(%{mode: {:background, rule}} = state, line) do
    update_background_last_step(state, rule, line)
  end

  defp append_table_row(%{current: %{steps: steps} = current} = state, line) when steps != [] do
    [last | rest] = Enum.reverse(steps)
    updated_last = %{last | table: last.table ++ [parse_table_cells(line)]}
    %{state | current: %{current | steps: Enum.reverse([updated_last | rest])}}
  end

  defp append_table_row(state, _line), do: state

  defp update_background_last_step(%{backgrounds: backgrounds} = state, rule, line) do
    steps = Map.get(backgrounds, rule, [])

    case Enum.reverse(steps) do
      [last | rest] ->
        updated_last = %{last | table: last.table ++ [parse_table_cells(line)]}
        updated_steps = Enum.reverse([updated_last | rest])
        %{state | backgrounds: Map.put(backgrounds, rule, updated_steps)}

      _ ->
        state
    end
  end

  defp background_steps(backgrounds, rule) do
    Map.get(backgrounds, nil, []) ++ Map.get(backgrounds, rule, [])
  end

  defp parse_step(line) do
    [keyword, text] = String.split(line, ~r/\s+/, parts: 2)
    %Step{keyword: keyword, text: String.trim(text)}
  end

  defp step_keyword?(line), do: Regex.match?(~r/^(Given|When|Then|And|But)\s+/, line)
  defp table_row?(line), do: String.starts_with?(line, "|") and String.ends_with?(line, "|")

  defp parse_table_cells(line) do
    line
    |> String.trim("|")
    |> String.split("|")
    |> Enum.map(&String.trim/1)
  end

  defp interpolate_step(step, vars), do: %{step | text: interpolate(step.text, vars)}

  defp interpolate(text, vars) do
    Enum.reduce(vars, text, fn {k, v}, acc -> String.replace(acc, "<#{k}>", v) end)
  end
end
