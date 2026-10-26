# Numerics digest for the dependency-currency evidence (docs/roadmap.md, H1.6).
#
# Prints a SHA-256 prefix per line over a canonical encoding of: the fixed-seed
# random circuit fixtures, production expectation values, the float64 dense
# reference, seeded Sampler.run counts, the shot-based estimator, Compiler.optimize
# output, readout mitigation, gradients, the quantum kernel matrix, and raw
# c64/c128 Nx primitives. It also prints the worst absolute error against the
# float64 reference and the analytic gradients.
#
# Hashes never use :erlang.term_to_binary (stable only within one OTP major).
# The canonical encoding is: gate names as strings, wires as integers, params
# sorted by key with floats as <<f::float-64>>, tensors as type, shape and
# Nx.to_binary. Only public APIs are called. Every seed is fixed.
#
# Digests go to stdout and contain no paths, usernames or hostnames. Two runs on
# the same toolchain and lock must be byte-identical.
#
# Run from the repository root:
#   MIX_ENV=test mix run bench/numerics_digest.exs [--env-out <path>]
#
# With `--env-out`, the environment block (date, OS, CPU, toolchain, dependency
# versions, env flags, git HEAD, default backend) is written to that file. The
# CPU brand and git HEAD lines are the only host-specific values and never go
# to stdout.

alias NumericsDigest.Canonical
alias NxQuantum.Circuit
alias NxQuantum.Compiler
alias NxQuantum.Estimator
alias NxQuantum.GateOperation
alias NxQuantum.Gates
alias NxQuantum.Grad
alias NxQuantum.Kernels
alias NxQuantum.Mitigation
alias NxQuantum.Sampler
alias NxQuantum.TestSupport.NumericsCases

Code.require_file("test/support/dense_reference.ex")
Code.require_file("test/support/random_circuits.ex")
Code.require_file("test/support/numerics_cases.ex")

{opts, _args, _invalid} = OptionParser.parse(System.argv(), strict: [env_out: :string])

defmodule NumericsDigest.Canonical do
  @moduledoc false

  # Length-prefixed, type-tagged encoding. Stable across OTP releases.
  def encode(x) when is_float(x), do: <<?f, x::float-64>>
  def encode(x) when is_integer(x), do: str(?i, Integer.to_string(x))
  def encode(x) when is_atom(x), do: str(?a, Atom.to_string(x))
  def encode(x) when is_binary(x), do: str(?b, x)
  def encode(x) when is_list(x), do: [<<?l, length(x)::unsigned-32>> | Enum.map(x, &encode/1)]
  def encode(%Nx.Tensor{} = t), do: tensor(t)
  def encode(%GateOperation{} = op), do: operation(op)

  def encode(%{} = map) when not is_struct(map) do
    entries = map |> Enum.sort_by(fn {k, _v} -> sort_key(k) end) |> Enum.flat_map(fn {k, v} -> [encode(k), encode(v)] end)
    [<<?m, map_size(map)::unsigned-32>> | entries]
  end

  def operation(%GateOperation{name: name, wires: wires, params: params}) do
    [str(?g, Atom.to_string(name)), encode(wires), encode(params)]
  end

  def tensor(%Nx.Tensor{} = t) do
    {kind, bits} = Nx.type(t)
    shape = t |> Nx.shape() |> Tuple.to_list()
    [str(?T, "#{kind}#{bits}"), encode(shape), str(?d, Nx.to_binary(t))]
  end

  defp str(tag, bin), do: <<tag, byte_size(bin)::unsigned-64, bin::binary>>
  defp sort_key(k) when is_atom(k), do: Atom.to_string(k)
  defp sort_key(k) when is_binary(k), do: k
  defp sort_key(k), do: inspect(k)
end

digest = fn term ->
  :sha256
  |> :crypto.hash(IO.iodata_to_binary(Canonical.encode(term)))
  |> Base.encode16(case: :lower)
  |> binary_part(0, 16)
end

# --- Expectation values against the float64 dense reference -------------------

rows =
  for {qubits, _depth, _count, _seed} = spec <- NumericsCases.cases(),
      ops <- NumericsCases.circuits(spec),
      measurement <- NumericsCases.measure(qubits, ops) do
    {value, reference} = measurement
    {ops, value, reference, abs(Nx.to_number(value) - reference)}
  end

fixtures =
  for {qubits, _depth, _count, _seed} = spec <- NumericsCases.cases(), ops <- NumericsCases.circuits(spec) do
    [qubits, ops]
  end

production = Enum.map(rows, fn {_ops, value, _reference, _delta} -> value end)
reference = Enum.map(rows, fn {_ops, _value, ref, _delta} -> ref end)
deltas = Enum.map(rows, fn {_ops, _value, _ref, delta} -> delta end)
expectation_types = production |> Enum.map(&Nx.type/1) |> Enum.uniq()

# --- Sampler.run end to end ----------------------------------------------------

ry_z = fn theta ->
  [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: theta) |> Circuit.expectation(observable: :pauli_z, wire: 0)
end

sampler_ry =
  for theta <- [0.0, 0.5, 1.1, 2.0, :math.pi()], seed <- [1, 7, 42] do
    circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: theta)
    {:ok, result} = Sampler.run(circuit, shots: 1024, seed: seed, observable: :pauli_z, wire: 0)
    [result.counts, result.probabilities]
  end

# Circuits for the primitive-level lines: the first six of the 4-qubit case.
[four_qubit_case | _] = NumericsCases.cases()
circs = four_qubit_case |> NumericsCases.circuits() |> Enum.take(6) |> Enum.map(&%Circuit{qubits: 4, operations: &1})

sampler_e2e =
  for circuit <- circs, wire <- 0..3, observable <- [:pauli_z, :pauli_x], seed <- [1, 7, 42] do
    {:ok, result} = Sampler.run(circuit, shots: 1024, seed: seed, observable: observable, wire: wire)
    [result.counts, result.probabilities]
  end

# --- Estimator shot path, compiler, mitigation ---------------------------------

estimator_shots =
  for circuit <- circs, seed <- [123, 5] do
    {:ok, value} = Estimator.expectation_result(circuit, shots: 128, seed: seed, observable: :pauli_z, wire: 1)
    value
  end

optimized =
  for circuit <- circs do
    {optimized_circuit, _report} = Compiler.optimize(circuit)
    optimized_circuit.operations
  end

{:ok, mitigation_input} = Sampler.run(hd(circs), shots: 512, seed: 99)
calibration = Nx.tensor([[0.95, 0.05], [0.06, 0.94]], type: {:f, 32})
{:ok, mitigated} = Mitigation.pipeline(mitigation_input, [{:readout, calibration: calibration}])

# --- Raw complex primitives ----------------------------------------------------

complex_lines =
  for type <- [{:c, 64}, {:c, 128}] do
    c = &Complex.new/2
    a = Nx.tensor([c.(0.3, -1.7), c.(-2.5, 0.125), c.(1.0e-3, 7.0), c.(-0.0, 1.0)], type: type)
    b = Nx.tensor([c.(1.1, 0.9), c.(0.2, -3.3), c.(-4.0, 0.5), c.(2.0, -0.0)], type: type)
    m = Nx.tensor([[c.(0.6, 0.8), c.(0.0, 1.0)], [c.(-0.28, 0.96), c.(1.0, 0.0)]], type: type)
    v = Nx.tensor([c.(0.5, 0.5), c.(-0.5, 0.5)], type: type)

    ops = [
      multiply: Nx.multiply(a, b),
      conjugate: Nx.conjugate(a),
      divide: Nx.divide(a, b),
      add: Nx.add(a, b),
      exp: Nx.exp(a),
      abs: Nx.abs(a),
      sqrt: Nx.sqrt(a),
      phase: Nx.phase(a),
      real: Nx.real(a),
      imag: Nx.imag(a),
      dot: Nx.dot(m, v),
      dot_mm: Nx.dot(m, m),
      sum: Nx.sum(a),
      cos: Nx.cos(a),
      sin: Nx.sin(a),
      as_c64: Nx.as_type(a, {:c, 64})
    ]

    {type, Enum.map_join(ops, " ", fn {name, tensor} -> "#{name}=#{digest.(tensor)}" end)}
  end

# --- Gradients and kernel ------------------------------------------------------

adjoint_builder = fn theta ->
  [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: theta) |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
end

{_, grad_backprop} = Grad.value_and_grad(ry_z, Nx.tensor(1.1), mode: :backprop, epsilon: 1.0e-6)
{_, grad_shift} = Grad.value_and_grad(ry_z, Nx.tensor(1.1), mode: :parameter_shift)

{_, grad_adjoint} =
  Grad.value_and_grad(ry_z, Nx.tensor(1.234), mode: :adjoint, circuit_builder: adjoint_builder)

{_, grad_backprop_fine} = Grad.value_and_grad(ry_z, Nx.tensor(1.1), mode: :backprop, epsilon: 1.0e-3)

grads = Enum.map([grad_backprop, grad_shift, grad_adjoint], &Nx.to_number/1)
[_, shift_value, adjoint_value] = grads
analytic_shift = -:math.sin(1.1)
analytic_adjoint = -:math.sin(1.234)

kernel =
  Kernels.matrix(Nx.tensor([[0.1, 0.2], [0.3, -0.4], [1.0, 0.5]], type: {:f, 64}), gamma: 0.7, seed: 11)

sampler_sample = sampler_ry |> Enum.slice(6, 3) |> Enum.map(fn [counts, _probs] -> counts end)

lines =
  [
    "fixture_ops_sha=#{digest.(fixtures)}",
    "production_expval_bits_sha=#{digest.(production)} (#{length(rows)} obs)",
    "float64_reference_bits_sha=#{digest.(reference)}",
    "sampler_run_ry_sha=#{digest.(sampler_ry)} sample=#{inspect(sampler_sample)}",
    "sampler_run_e2e_sha=#{digest.(sampler_e2e)} (#{length(sampler_e2e)} runs)",
    "estimator_shots_sha=#{digest.(estimator_shots)}",
    "compiler_optimize_ops_sha=#{digest.(optimized)}",
    "readout_mitigation_sha=#{digest.(mitigated.probabilities)} probs=#{inspect(Nx.to_flat_list(mitigated.probabilities))}",
    "grad_values=#{inspect(grads)} analytic_ps=#{analytic_shift} analytic_adj=#{analytic_adjoint}",
    "grad_bits_sha=#{digest.(grads)}",
    "kernel_bits_sha=#{digest.(kernel)}"
  ] ++
    Enum.map(complex_lines, fn {type, line} -> "complex_prims #{inspect(type)} #{line}" end) ++
    [
      "expectation_types=#{inspect(expectation_types)}",
      "max_abs_delta_vs_float64=#{Enum.max(deltas)}",
      "grad_abs_err_parameter_shift=#{abs(shift_value - analytic_shift)}",
      "grad_abs_err_adjoint=#{abs(adjoint_value - analytic_adjoint)}",
      "grad_abs_err_backprop_eps1e-3=#{abs(Nx.to_number(grad_backprop_fine) - analytic_shift)}"
    ]

IO.write(Enum.join(lines, "\n") <> "\n")

# --- Environment block (optional) ----------------------------------------------

if path = opts[:env_out] do
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

  sw_product = run.("sw_vers", ["-productName"])
  sw_version = run.("sw_vers", ["-productVersion"])

  env_lines = [
    "date_utc: #{Date.to_iso8601(Date.utc_today())}",
    "os: #{sw_product} #{sw_version}",
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
    "backend: #{inspect(Nx.default_backend())}"
  ]

  File.write!(path, Enum.join(env_lines, "\n") <> "\n")
end
