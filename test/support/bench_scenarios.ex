defmodule NxQuantum.TestSupport.BenchScenarios do
  @moduledoc """
  Scenario table, angle fixture and circuit structure shared by
  `bench/nxquantum_python_comparison.exs` and the benchmark guard tests.

  Reads `bench/scenarios/python_alternatives.json` and the committed fixture with
  the stdlib `JSON` module and verifies the fixture sha256. Circuits are built
  only through the public `NxQuantum.Circuit` and `NxQuantum.Gates` facades. The
  Python harness builds the same structure from the same files, and its
  agreement checks catch any divergence.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Gates

  @table_path "bench/scenarios/python_alternatives.json"

  @spec table(String.t()) :: map()
  def table(path \\ @table_path), do: path |> File.read!() |> JSON.decode!()

  @spec fixture(map()) :: {map(), String.t()}
  def fixture(table) do
    bytes = File.read!(table["fixture"]["path"])
    expected = table["fixture"]["sha256_path"] |> File.read!() |> String.split() |> hd()
    actual = :sha256 |> :crypto.hash(bytes) |> Base.encode16(case: :lower)

    if actual != expected, do: raise("fixture sha256 mismatch: file=#{actual} committed=#{expected}")
    {JSON.decode!(bytes), actual}
  end

  @spec scenario!(map(), String.t()) :: map()
  def scenario!(table, id) do
    case Map.fetch(table["scenarios"], id) do
      {:ok, scenario} ->
        scenario

      :error ->
        raise ArgumentError,
              "unknown scenario id #{inspect(id)}; known ids: #{table["scenarios"] |> Map.keys() |> Enum.sort() |> inspect()}"
    end
  end

  @doc "CNOT(i, i + 1) for i = layer mod 2, layer mod 2 + 2, ... while i + 1 < n."
  @spec brickwork(non_neg_integer(), pos_integer()) :: [list()]
  def brickwork(layer, n) do
    start = rem(layer, 2)
    for i <- 0..(n - 2)//1, rem(i, 2) == start, do: ["cnot", i, i + 1]
  end

  @doc "Gate list of a width family for one angle row `ks` (integers k, angle = k / 1024)."
  @spec family_gates(String.t(), pos_integer(), [integer()], pos_integer()) :: [list()]
  def family_gates("real", n, ks, layers) do
    angles = Enum.map(ks, &(&1 / 1024))
    hadamards = for w <- 0..(n - 1), do: ["h", w]

    layered =
      for layer <- 0..(layers - 1) do
        rotations = for w <- 0..(n - 1), do: ["ry", w, Enum.at(angles, layer * n + w)]
        rotations ++ brickwork(layer, n)
      end

    hadamards ++ Enum.concat(layered)
  end

  def family_gates("complex", n, ks, layers) do
    angles = Enum.map(ks, &(&1 / 1024))

    layered =
      for layer <- 0..(layers - 1) do
        base = layer * 2 * n
        rx = for w <- 0..(n - 1), do: ["rx", w, Enum.at(angles, base + w)]
        rz = for w <- 0..(n - 1), do: ["rz", w, Enum.at(angles, base + n + w)]
        rx ++ rz ++ brickwork(layer, n)
      end

    Enum.concat(layered)
  end

  @doc "Prefix-parity analytic circuit: product-state rotations, then CNOT(j, j + 1) for j = 0..n-2."
  @spec prefix_parity_gates(String.t(), pos_integer(), map()) :: [list()]
  def prefix_parity_gates(family, n, entry) do
    theta = Enum.map(entry["theta_k"], &(&1 / 1024))

    rotations =
      case family do
        "real" ->
          for w <- 0..(n - 1), do: ["ry", w, Enum.at(theta, w)]

        "complex" ->
          phi = Enum.map(entry["phi_k"], &(&1 / 1024))
          for(w <- 0..(n - 1), do: ["rx", w, Enum.at(theta, w)]) ++ for(w <- 0..(n - 1), do: ["rz", w, Enum.at(phi, w)])
      end

    rotations ++ for(j <- 0..(n - 2)//1, do: ["cnot", j, j + 1])
  end

  @doc "Product of cosines: the analytic value of <Z_k> after the prefix-parity circuit."
  @spec prefix_parity_expected(map()) :: [float()]
  def prefix_parity_expected(entry) do
    entry["theta_k"]
    |> Enum.map(&:math.cos(&1 / 1024))
    |> Enum.scan(&(&1 * &2))
  end

  @spec observable_atom(String.t()) :: atom()
  def observable_atom("X"), do: :pauli_x
  def observable_atom("Y"), do: :pauli_y
  def observable_atom("Z"), do: :pauli_z

  @spec z_specs(pos_integer()) :: [map()]
  def z_specs(n), do: for(w <- 0..(n - 1), do: %{observable: :pauli_z, wire: w})

  @spec build_circuit(pos_integer(), [list()], (number() -> term())) :: Circuit.t()
  def build_circuit(n, gates, angle_fun) do
    Enum.reduce(gates, Circuit.new(qubits: n), fn
      ["h", w], c -> Gates.h(c, w)
      ["cnot", a, b], c -> Gates.cnot(c, control: a, target: b)
      ["rx", w, angle], c -> Gates.rx(c, w, theta: angle_fun.(angle))
      ["ry", w, angle], c -> Gates.ry(c, w, theta: angle_fun.(angle))
      ["rz", w, angle], c -> Gates.rz(c, w, theta: angle_fun.(angle))
    end)
  end
end
