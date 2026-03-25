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

cold_artifact_path =
  System.get_env("NXQ_BATCH_OBS_COLD_ARTIFACT_PATH") || "tmp/bench_reports/batch_obs_8q_cold_report.csv"

hot_report =
  case BatchObsGuard.run(
         iterations: iterations,
         warmup: warmup,
         max_per_op_ms: max_per_op_ms,
         cache_mode: :hot
       ) do
    {:ok, report} -> report
    {:error, metadata} -> raise "batch_obs hot-lane guard configuration error: #{inspect(metadata)}"
  end

IO.puts(
  "NXQ_BATCH_OBS_GUARD_HOT cache_mode=#{hot_report.cache_mode} guard_mode=#{hot_report.guard_mode} status=#{hot_report.status} per_op_ms=#{Float.round(hot_report.per_op_ms, 6)} max_per_op_ms=#{Float.round(hot_report.max_per_op_ms, 6)}"
)

if hot_report.status == :failed do
  raise "batch_obs_8q hot-lane regression guard failed: per_op_ms=#{hot_report.per_op_ms} exceeded max_per_op_ms=#{hot_report.max_per_op_ms}"
end

cold_report =
  case BatchObsGuard.run(
         iterations: iterations,
         warmup: warmup,
         max_per_op_ms: max_per_op_ms,
         cache_mode: :cold,
         artifact_path: cold_artifact_path
       ) do
    {:ok, report} -> report
    {:error, metadata} -> raise "batch_obs cold-lane reporting configuration error: #{inspect(metadata)}"
  end

IO.puts(
  "NXQ_BATCH_OBS_GUARD_COLD cache_mode=#{cold_report.cache_mode} guard_mode=#{cold_report.guard_mode} status=#{cold_report.status} per_op_ms=#{Float.round(cold_report.per_op_ms, 6)} max_per_op_ms=#{Float.round(cold_report.max_per_op_ms, 6)} artifact=#{cold_artifact_path}"
)
