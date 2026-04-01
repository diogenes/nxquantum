defmodule NxQuantum.AI.Tools.KernelRerank.DatasetCSV do
  @moduledoc false

  @required_headers ["query_id", "candidate_id", "query_embedding", "candidate_embedding"]

  @spec load(map()) :: {:ok, map()} | {:error, map()}
  def load(input) when is_map(input) do
    with {:ok, path} <- fetch_required_binary(input, :dataset_path),
         {:ok, query_id} <- fetch_required_binary(input, :query_id),
         {:ok, rows} <- read_rows(path),
         {:ok, filtered} <- filter_rows(rows, query_id, Map.get(input, :candidate_ids, [])),
         {:ok, query_embedding} <- extract_query_embedding(filtered),
         {:ok, candidate_ids, candidate_embeddings} <- extract_candidates(filtered, Map.get(input, :candidate_ids, [])) do
      {:ok,
       %{
         candidate_ids: candidate_ids,
         query_embedding: query_embedding,
         candidate_embeddings: candidate_embeddings,
         dataset_source: Path.basename(path),
         dataset_query_id: query_id
       }}
    end
  end

  defp fetch_required_binary(input, key) do
    case Map.get(input, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _ -> {:error, %{code: :ai_tool_invalid_request, field: key, message: "#{key} required for dataset mode"}}
    end
  end

  defp read_rows(path) do
    with {:ok, validated_path} <- validate_path(path),
         true <- File.exists?(validated_path),
         {:ok, content} <- File.read(validated_path) do
      parse_csv(content)
    else
      {:error, :unauthorized} ->
        {:error,
         %{code: :ai_tool_invalid_request, field: :dataset_path, message: "unauthorized dataset path"}}

      false ->
        {:error,
         %{code: :ai_tool_invalid_request, field: :dataset_path, message: "dataset file not found"}}

      {:error, _} ->
        {:error,
         %{code: :ai_tool_invalid_request, field: :dataset_path, message: "unable to read dataset file"}}
    end
  end

  defp validate_path(path) do
    expanded = Path.expand(path)
    # Allowed directories: bench/datasets for production-like usage.
    # We include System.tmp_dir() but ensure the expanded path is within it correctly.
    allowed_dirs = [
      Path.expand("bench/datasets"),
      Path.expand(System.tmp_dir!())
    ]

    if Enum.any?(allowed_dirs, &is_path_contained?(&1, expanded)) do
      {:ok, expanded}
    else
      {:error, :unauthorized}
    end
  end

  defp is_path_contained?(parent, child) do
    parent = Path.expand(parent)
    child = Path.expand(child)

    # Ensure parent ends with a separator for prefix matching to avoid sibling directory bypass
    parent_prefix =
      if String.ends_with?(parent, "/") do
        parent
      else
        parent <> "/"
      end

    child == parent or String.starts_with?(child, parent_prefix)
  end

  defp parse_csv(content) do
    lines =
      content
      |> String.split("\n", trim: true)
      |> Enum.reject(&(&1 == ""))

    case lines do
      [header_line | row_lines] ->
        headers = split_row(header_line)

        with :ok <- validate_headers(headers) do
          parse_rows(headers, row_lines)
        end

      _ ->
        {:error, %{code: :ai_tool_invalid_request, field: :dataset_path, message: "dataset file is empty"}}
    end
  end

  defp validate_headers(headers) do
    if Enum.all?(@required_headers, &(&1 in headers)) do
      :ok
    else
      {:error,
       %{code: :ai_tool_invalid_request, field: :dataset_path, message: "dataset header missing required columns"}}
    end
  end

  defp parse_rows(_headers, []), do: {:ok, []}

  defp parse_rows(headers, row_lines) do
    row_lines
    |> Enum.with_index(2)
    |> Enum.reduce_while({:ok, []}, fn {line, line_number}, {:ok, acc} ->
      cells = split_row(line)

      if length(cells) == length(headers) do
        row = Map.new(Enum.zip(headers, cells))
        {:cont, {:ok, [row | acc]}}
      else
        {:halt,
         {:error,
          %{code: :ai_tool_invalid_request, field: :dataset_path, message: "invalid column count", line: line_number}}}
      end
    end)
    |> case do
      {:ok, rows} -> {:ok, Enum.reverse(rows)}
      {:error, _} = error -> error
    end
  end

  defp filter_rows(rows, query_id, candidate_ids) do
    filtered =
      rows
      |> Enum.filter(fn row -> Map.get(row, "query_id") == query_id end)
      |> maybe_filter_candidates(candidate_ids)

    if filtered == [] do
      {:error,
       %{code: :ai_tool_invalid_request, field: :query_id, message: "no dataset rows matched query_id/candidate_ids"}}
    else
      {:ok, filtered}
    end
  end

  defp maybe_filter_candidates(rows, candidate_ids) when is_list(candidate_ids) and candidate_ids != [] do
    allowed = MapSet.new(candidate_ids)
    Enum.filter(rows, fn row -> MapSet.member?(allowed, Map.get(row, "candidate_id")) end)
  end

  defp maybe_filter_candidates(rows, _candidate_ids), do: rows

  defp extract_query_embedding([first | rest]) do
    with {:ok, embedding} <- parse_vector(Map.get(first, "query_embedding")) do
      matches? =
        Enum.all?(rest, fn row ->
          case parse_vector(Map.get(row, "query_embedding")) do
            {:ok, parsed} -> parsed == embedding
            _ -> false
          end
        end)

      if matches? do
        {:ok, embedding}
      else
        {:error,
         %{
           code: :ai_tool_invalid_request,
           field: :query_embedding,
           message: "dataset query_embedding differs across rows for the same query_id"
         }}
      end
    end
  end

  defp extract_query_embedding(_rows),
    do: {:error, %{code: :ai_tool_invalid_request, field: :query_embedding, message: "query_embedding missing"}}

  defp extract_candidates(rows, requested_candidate_ids) do
    with {:ok, candidates_map} <- parse_candidate_map(rows),
         {:ok, candidate_ids} <- resolve_candidate_ids(candidates_map, requested_candidate_ids) do
      candidate_embeddings = Map.new(candidate_ids, fn id -> {id, Map.fetch!(candidates_map, id)} end)
      {:ok, candidate_ids, candidate_embeddings}
    end
  end

  defp parse_candidate_map(rows) do
    Enum.reduce_while(rows, {:ok, %{}}, fn row, {:ok, acc} ->
      candidate_id = Map.get(row, "candidate_id")

      case parse_vector(Map.get(row, "candidate_embedding")) do
        {:ok, vector} ->
          {:cont, {:ok, Map.put_new(acc, candidate_id, vector)}}

        {:error, _} ->
          {:halt,
           {:error,
            %{
              code: :ai_tool_invalid_request,
              field: :candidate_embedding,
              message: "invalid candidate_embedding in dataset"
            }}}
      end
    end)
  end

  defp resolve_candidate_ids(candidates_map, requested_candidate_ids)
       when is_list(requested_candidate_ids) and requested_candidate_ids != [] do
    missing = Enum.reject(requested_candidate_ids, &Map.has_key?(candidates_map, &1))

    if missing == [] do
      {:ok, requested_candidate_ids}
    else
      {:error,
       %{
         code: :ai_tool_invalid_request,
         field: :candidate_ids,
         message: "candidate_ids not present in dataset",
         missing: missing
       }}
    end
  end

  defp resolve_candidate_ids(candidates_map, _requested_candidate_ids) do
    ids = candidates_map |> Map.keys() |> Enum.sort()

    if ids == [] do
      {:error, %{code: :ai_tool_invalid_request, field: :candidate_id, message: "dataset contained no candidate rows"}}
    else
      {:ok, ids}
    end
  end

  defp parse_vector(raw) when is_binary(raw) do
    values =
      raw
      |> String.replace("\"", "")
      |> String.split(~r/[|,\s;]+/, trim: true)

    if values == [] do
      {:error, :invalid}
    else
      values
      |> Enum.reduce_while({:ok, []}, fn value, {:ok, acc} ->
        case Float.parse(value) do
          {parsed, ""} -> {:cont, {:ok, [parsed | acc]}}
          _ -> {:halt, {:error, :invalid}}
        end
      end)
      |> case do
        {:ok, parsed} -> {:ok, Enum.reverse(parsed)}
        {:error, _} = error -> error
      end
    end
  end

  defp parse_vector(_), do: {:error, :invalid}

  defp split_row(line) do
    line
    |> String.trim()
    |> String.split(",", trim: false)
    |> Enum.map(&String.trim/1)
  end
end
