alias NxQuantum.Performance.BatchObsGuard

parse_int = fn value, default ->
  case Integer.parse(to_string(value || "")) do
    {parsed, ""} when parsed >= 0 -> parsed
    _ -> default
  end
end

parse_float = fn value, default ->
  case Float.parse(to_string(value || "")) do
    {parsed, ""} when parsed > 0.0 -> parsed
    _ -> default
  end
end

iterations = parse_int.(System.get_env("NXQ_BATCH_OBS_GUARD_ITERATIONS"), 100)
warmup = parse_int.(System.get_env("NXQ_BATCH_OBS_GUARD_WARMUP"), 20)
max_per_op_ms = parse_float.(System.get_env("NXQ_BATCH_OBS_MAX_PER_OP_MS"), 2.028_193_5)

case BatchObsGuard.run(iterations: iterations, warmup: warmup, max_per_op_ms: max_per_op_ms) do
  {:ok, %{status: :ok} = report} ->
    IO.puts(
      "NXQ_BATCH_OBS_GUARD status=ok per_op_ms=#{Float.round(report.per_op_ms, 6)} max_per_op_ms=#{Float.round(report.max_per_op_ms, 6)} iterations=#{report.iterations} warmup=#{report.warmup}"
    )

  {:ok, %{status: :failed} = report} ->
    IO.puts(
      "NXQ_BATCH_OBS_GUARD status=failed per_op_ms=#{Float.round(report.per_op_ms, 6)} max_per_op_ms=#{Float.round(report.max_per_op_ms, 6)} iterations=#{report.iterations} warmup=#{report.warmup}"
    )

    raise "batch_obs_8q regression guard failed: per_op_ms=#{report.per_op_ms} exceeded max_per_op_ms=#{report.max_per_op_ms}"

  {:error, metadata} ->
    raise "batch_obs_8q regression guard configuration error: #{inspect(metadata)}"
end
