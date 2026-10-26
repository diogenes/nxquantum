# NxQuantum lane of the cross-framework benchmark (H1.3 Track A).
#
# Driven by bench/python_alternatives_benchmark.py. Scenario ids, counts, fixed
# circuits and thread counts come from bench/scenarios/python_alternatives.json;
# angle sets come from bench/scenarios/python_alternatives_fixture.json (sha256
# verified). An unknown scenario id raises.
#
# Only public facades are called: NxQuantum.Circuit, Gates, Estimator and
# Runtime. No @moduledoc false adapter module is used (R2). The one exception is
# test/support/dense_reference.ex in --mode dense_export, which is the
# independent reference under test, not an NxQuantum adapter.
#
#   mix run bench/nxquantum_python_comparison.exs --mode values --scenario deep_6q \
#     --profile cpu_portable --cache-mode cold --warmup 1 --iterations 3
#
# Modes: values | timed | pretime | env | dense_export
#   values/timed  warmup + timed loop; one NXQ_ITER line per timed iteration with
#                 the per-observable values in shortest round-trip form.
#   pretime       the same with warmup 0 / iterations 1 (single untimed sample).
#   env           writes the environment block (numerics_digest.exs --env-out format).
#   dense_export  float64 dense-reference states and Pauli expectations (<= 6 qubits).
#
# Cold mode builds every iteration's circuit (distinct angle set) before the timed
# loop and turns the result caches off; only structure-keyed caches stay warm.

alias NxQuantum.Circuit
alias NxQuantum.Estimator
alias NxQuantum.Gates
alias NxQuantum.Runtime

{opts, _args, invalid} =
  OptionParser.parse(System.argv(),
    strict: [
      mode: :string,
      scenario: :string,
      profile: :string,
      cache_mode: :string,
      warmup: :integer,
      iterations: :integer,
      zz: :boolean,
      out: :string,
      cases: :string,
      env_out: :string,
      table: :string
    ]
  )

if invalid != [], do: raise(ArgumentError, "invalid options: #{inspect(invalid)}")

Code.require_file("test/support/bench_scenarios.ex")

defmodule BenchPlan do
  @moduledoc false
  # Script-local helpers. Circuit structure, table and fixture loading live in
  # test/support/bench_scenarios.ex (shared with the guard tests).

  def shortest(x) when is_float(x), do: :erlang.float_to_binary(x, [:short])
  def shortest(x) when is_integer(x), do: shortest(x * 1.0)

  def cache_flags("cold", scenario) do
    case scenario["kind"] do
      "sampled_" <> _ -> [cache_parsed_counts: false, cache_mask_lookup_plan: false]
      _ -> [cache_evolved_state: false]
    end
  end

  def cache_flags("hot", _scenario), do: [cache_evolved_state: true]

  def flags_string(flags), do: Enum.map_join(flags, ",", fn {k, v} -> "#{k}=#{v}" end)
end

alias NxQuantum.TestSupport.BenchScenarios

table_path = opts[:table] || "bench/scenarios/python_alternatives.json"
table = BenchScenarios.table(table_path)
mode = opts[:mode] || "values"

if mode not in ["values", "timed", "pretime", "env", "dense_export"],
  do: raise(ArgumentError, "unknown mode #{inspect(mode)}")

load_fixture = fn -> BenchScenarios.fixture(table) end

# ---------------------------------------------------------------------------------------------
# env mode
# ---------------------------------------------------------------------------------------------

if mode == "env" do
  path = opts[:env_out] || raise ArgumentError, "--env-out is required in env mode"

  run = fn cmd, args ->
    try do
      case System.cmd(cmd, args, stderr_to_stdout: true) do
        {out, 0} -> String.trim(out)
        _ -> "unavailable"
      end
    rescue
      _ -> "unavailable"
    end
  end

  version = fn app ->
    _ = Application.load(app)

    case Application.spec(app, :vsn) do
      nil -> "not present"
      vsn -> to_string(vsn)
    end
  end

  otp_release = :otp_release |> :erlang.system_info() |> to_string()

  otp_full =
    [:code.root_dir(), "releases", otp_release, "OTP_VERSION"]
    |> Path.join()
    |> File.read()
    |> case do
      {:ok, text} -> String.trim(text)
      _ -> "unavailable"
    end

  flag = fn name -> System.get_env(name) || "unset" end

  lines = [
    "date_utc: #{Date.to_iso8601(Date.utc_today())}",
    "os: #{run.("sw_vers", ["-productName"])} #{run.("sw_vers", ["-productVersion"])}",
    "cpu: #{run.("sysctl", ["-n", "machdep.cpu.brand_string"])}",
    "elixir: #{System.version()}",
    "otp_release: #{otp_release}",
    "otp_version: #{otp_full}",
    "nx: #{version.(:nx)}",
    "exla: #{version.(:exla)}",
    "torchx: #{version.(:torchx)}",
    "complex: #{version.(:complex)}",
    "NXQ_ENABLE_EXLA: #{flag.("NXQ_ENABLE_EXLA")}",
    "NXQ_ENABLE_TORCHX: #{flag.("NXQ_ENABLE_TORCHX")}",
    "MIX_ENV: #{Mix.env()}",
    "git_head: #{run.("git", ["rev-parse", "HEAD"])}",
    "git_dirty: #{run.("git", ["status", "--porcelain"]) != ""}",
    "backend: #{inspect(Nx.default_backend())}",
    "beam_schedulers_online: #{System.schedulers_online()}",
    "beam_dirty_cpu_schedulers_online: #{:erlang.system_info(:dirty_cpu_schedulers_online)}",
    "beam_schedulers_expected: #{table["threads"]["beam_schedulers"]}",
    "beam_max_concurrency: #{table["threads"]["max_concurrency"]}",
    "ELIXIR_ERL_OPTIONS: #{flag.("ELIXIR_ERL_OPTIONS")}"
  ]

  File.write!(path, Enum.join(lines, "\n") <> "\n")
  System.halt(0)
end

# ---------------------------------------------------------------------------------------------
# dense_export mode: float64 dense reference (independent of the production matrix library)
# ---------------------------------------------------------------------------------------------

if mode == "dense_export" do
  Code.require_file("test/support/dense_reference.ex")
  {fixture, _sha} = load_fixture.()
  out_path = opts[:out] || raise ArgumentError, "--out is required in dense_export mode"
  cases = (opts[:cases] || raise(ArgumentError, "--cases is required")) |> String.split(",", trim: true)

  case_gates = fn name ->
    case Regex.run(~r/^(real|complex)_(\d+)_set(\d+)$/, name) do
      [_, family, width, set] ->
        entry = fixture["families"][family]["widths"][width]
        n = String.to_integer(width)
        {n, BenchScenarios.family_gates(family, n, Enum.at(entry["k"], String.to_integer(set)), fixture["layers"])}

      nil ->
        scenario = BenchScenarios.scenario!(table, name)
        {scenario["qubits"], scenario["gates"]}
    end
  end

  pauli_expectations = fn n, amps ->
    dim = Bitwise.bsl(1, n)
    amp = List.to_tuple(amps)

    for axis <- ["X", "Y", "Z"], w <- 0..(n - 1) do
      mask = Bitwise.bsl(1, n - 1 - w)

      Enum.reduce(0..(dim - 1), 0.0, fn i, acc ->
        {ar, ai} = elem(amp, i)
        {cr, ci} = elem(amp, Bitwise.bxor(i, mask))
        bit = if Bitwise.band(i, mask) == 0, do: 0, else: 1

        term =
          case axis do
            "Z" -> (ar * ar + ai * ai) * (1 - 2 * bit)
            "X" -> ar * cr + ai * ci
            "Y" ->
              {dr, di} = if bit == 0, do: {ci, -cr}, else: {-ci, cr}
              ar * dr + ai * di
          end

        acc + term
      end)
    end
  end

  exported =
    Map.new(cases, fn name ->
      {n, gates} = case_gates.(name)
      circuit = BenchScenarios.build_circuit(n, gates, & &1)
      unitary = NxQuantum.TestSupport.DenseReference.unitary(n, circuit.operations)
      column = unitary |> Nx.slice_along_axis(0, 1, axis: 1) |> Nx.reshape({:auto})
      re = Nx.to_flat_list(Nx.real(column))
      im = Nx.to_flat_list(Nx.imag(column))
      amps = Enum.zip(re, im)
      {name, %{"n" => n, "re" => re, "im" => im, "expectations" => pauli_expectations.(n, amps)}}
    end)

  File.write!(out_path, JSON.encode!(exported))
  IO.puts("NXQ_DENSE_EXPORT cases=#{length(cases)} out=#{out_path}")
  System.halt(0)
end

# ---------------------------------------------------------------------------------------------
# values / timed / pretime
# ---------------------------------------------------------------------------------------------

scenario_id = opts[:scenario] || raise(ArgumentError, "--scenario is required")
scenario = BenchScenarios.scenario!(table, scenario_id)
kind = scenario["kind"]
qubits = scenario["qubits"]
cache_mode = opts[:cache_mode] || "cold"

if cache_mode not in scenario["cache_modes"],
  do: raise(ArgumentError, "scenario #{scenario_id} does not allow cache mode #{cache_mode}; allowed #{inspect(scenario["cache_modes"])}")

if cache_mode == "hot" and qubits > 10,
  do: raise(ArgumentError, "hot rows are published only at 10 qubits or fewer")

if scenario["nx_public_api"] == false,
  do: raise(ArgumentError, "scenario #{scenario_id}: #{scenario["nx_public_api_note"]}")

{warmup, iterations} =
  case mode do
    "pretime" -> {0, 1}
    _ -> {opts[:warmup] || scenario["warmup"], opts[:iterations] || scenario["iterations"]}
  end

threads = table["threads"]

if mode in ["timed", "pretime"] and System.schedulers_online() != threads["beam_schedulers"],
  do: raise("BEAM schedulers #{System.schedulers_online()} != table #{threads["beam_schedulers"]}; start with ELIXIR_ERL_OPTIONS='+S N:N'")

max_concurrency = threads["max_concurrency"]

runtime_profile =
  case opts[:profile] || "cpu_portable" do
    "cpu_portable" -> :cpu_portable
    "cpu_compiled" -> :cpu_compiled
    other -> raise ArgumentError, "unsupported profile #{inspect(other)} for this benchmark"
  end

resolved_profile =
  case Runtime.resolve(runtime_profile, fallback_policy: :allow_cpu_compiled) do
    {:ok, profile} -> profile.id
    {:error, _reason} -> :cpu_portable
  end

{fixture, fixture_sha} = load_fixture.()
total = warmup + iterations
cache_flags = BenchPlan.cache_flags(cache_mode, scenario)
nx_opts = Enum.map(scenario["nx_opts"] || %{}, fn {k, v} -> {String.to_atom(k), v} end)
f32 = fn angle -> Nx.tensor(angle) end

specs_for = fn observables ->
  Enum.map(observables, fn [axis, wire] -> %{observable: BenchScenarios.observable_atom(axis), wire: wire} end)
end

gates_for_family = fn index ->
  entry = fixture["families"][scenario["family"]]["widths"][Integer.to_string(qubits)]
  BenchScenarios.family_gates(scenario["family"], qubits, Enum.at(entry["k"], index), fixture["layers"])
end

# Inputs for every warmup + timed iteration are built BEFORE the timed loop.
{inputs, specs, run_once} =
  case kind do
    "family" ->
      specs = specs_for.(for w <- 0..(qubits - 1), do: ["Z", w])

      gate_sets =
        if cache_mode == "hot",
          do: List.duplicate(gates_for_family.(0), total),
          else: Enum.map(0..(total - 1), gates_for_family)

      inputs = Enum.map(gate_sets, &BenchScenarios.build_circuit(qubits, &1, f32))
      {inputs, specs, :batch}

    "fixed" ->
      specs = specs_for.(scenario["observables"])
      circuit = BenchScenarios.build_circuit(qubits, scenario["gates"], f32)
      kind_run = if length(specs) == 1, do: :scalar, else: :batch
      {List.duplicate(circuit, total), specs, kind_run}

    "sampled_z_wires" ->
      {List.duplicate(scenario["counts"], total), specs_for.(scenario["observables"]), :sampled}
  end

run_fun =
  case run_once do
    :scalar ->
      [%{observable: observable, wire: wire}] = specs

      fn circuit ->
        opts =
          [observable: observable, wire: wire, runtime_profile: runtime_profile, fallback_policy: :allow_cpu_compiled] ++
            cache_flags

        case Estimator.expectation_result(circuit, opts) do
          {:ok, value} -> Nx.reshape(value, {1})
          {:error, reason} -> raise "NxQuantum benchmark failed: #{inspect(reason)}"
        end
      end

    :batch ->
      fn circuit ->
        opts =
          [
            observables: specs,
            runtime_profile: runtime_profile,
            fallback_policy: :allow_cpu_compiled,
            max_concurrency: max_concurrency
          ] ++ nx_opts ++ cache_flags

        case Estimator.run(circuit, opts) do
          {:ok, result} -> result.values
          {:error, reason} -> raise "NxQuantum benchmark failed: #{inspect(reason)}"
        end
      end

    :sampled ->
      sampled_mode = if resolved_profile == :cpu_compiled, do: :force_parallel, else: :force_scalar

      fn counts ->
        opts = [observables: specs, sampled_parallel_mode: sampled_mode, max_concurrency: max_concurrency] ++ cache_flags

        case Estimator.sampled_expectation_from_counts(counts, opts) do
          {:ok, value} -> Nx.reshape(value, {:auto})
          {:error, reason} -> raise "NxQuantum sampled benchmark failed: #{inspect(reason)}"
        end
      end
  end

{warm_inputs, timed_inputs} = Enum.split(inputs, warmup)
Enum.each(warm_inputs, fn input -> _ = run_fun.(input) end)

timed =
  Enum.map(timed_inputs, fn input ->
    {microseconds, tensor} = :timer.tc(fn -> run_fun.(input) end)
    {microseconds, tensor}
  end)

total_us = timed |> Enum.map(&elem(&1, 0)) |> Enum.sum()
total_ms = total_us / 1000.0
per_op_ms = total_ms / iterations
ops_s = if total_us > 0, do: iterations / (total_us / 1_000_000.0), else: 0.0
rows = Enum.map(timed, fn {us, tensor} -> {us, Nx.to_flat_list(tensor)} end)
{_, last_values} = List.last(rows)
last_sum = Enum.sum(last_values)

IO.puts(
  "NXQ_BENCH scenario=#{scenario_id} runtime_profile=#{runtime_profile} resolved_profile=#{resolved_profile} " <>
    "cache_mode=#{cache_mode} mode=#{mode} warmup=#{warmup} iterations=#{iterations} " <>
    "total_ms=#{BenchPlan.shortest(total_ms)} per_op_ms=#{BenchPlan.shortest(per_op_ms)} ops_s=#{BenchPlan.shortest(ops_s)} " <>
    "value=#{BenchPlan.shortest(last_sum)} fixture_sha256=#{fixture_sha} schedulers=#{System.schedulers_online()} " <>
    "max_concurrency=#{max_concurrency} dirty_cpu_schedulers=#{:erlang.system_info(:dirty_cpu_schedulers_online)} observables=#{length(last_values)} dtype=f32 " <>
    "flags=#{BenchPlan.flags_string(cache_flags)}"
)

rows
|> Enum.with_index()
|> Enum.each(fn {{us, values}, index} ->
  IO.puts("NXQ_ITER i=#{index} ms=#{BenchPlan.shortest(us / 1000.0)} values=#{Enum.map_join(values, ",", &BenchPlan.shortest/1)}")
end)

# Untimed ZZ check: <Z_a Z_b> = <Z_b> after appending CNOT(a, b) (CNOT Z_b CNOT = Z_a Z_b).
if opts[:zz] && kind == "family" do
  entry = fixture["families"][scenario["family"]]["widths"][Integer.to_string(qubits)]
  base = gates_for_family.(0)

  Enum.each(entry["zz_pairs"], fn [a, b] ->
    circuit = BenchScenarios.build_circuit(qubits, base ++ [["cnot", a, b]], f32)

    zz_opts = [
      observables: specs_for.([["Z", b]]),
      runtime_profile: runtime_profile,
      fallback_policy: :allow_cpu_compiled
    ]

    {:ok, result} = Estimator.run(circuit, zz_opts)
    [value] = Nx.to_flat_list(result.values)
    IO.puts("NXQ_ZZ pair=#{a},#{b} value=#{BenchPlan.shortest(value)}")
  end)
end
