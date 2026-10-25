defmodule NxQuantum.TestSupport.GateIdentities do
  @moduledoc """
  Gate identities that act as the semantic oracle for compiler passes.

  Each entry names the pass it justifies. For every angle list, `lhs` and `rhs`
  are equal as unitaries up to global phase. The identities are checked against
  `NxQuantum.TestSupport.DenseReference`, so they also validate that reference.
  """

  alias NxQuantum.GateOperation

  @spec catalog() :: [map()]
  def catalog do
    [
      identity("hh_cancels", :cancel, 1, 0, fn [] -> [op(:h, [0]), op(:h, [0])] end, fn [] -> [] end),
      identity("xx_cancels", :cancel, 1, 0, fn [] -> [op(:x, [0]), op(:x, [0])] end, fn [] -> [] end),
      identity("yy_cancels", :cancel, 1, 0, fn [] -> [op(:y, [0]), op(:y, [0])] end, fn [] -> [] end),
      identity("zz_cancels", :cancel, 1, 0, fn [] -> [op(:z, [0]), op(:z, [0])] end, fn [] -> [] end),
      identity("cnot_cancels", :cancel, 2, 0, fn [] -> [op(:cnot, [0, 1]), op(:cnot, [0, 1])] end, fn [] -> [] end),
      identity("zero_rx_is_identity", :simplify, 1, 0, fn [] -> [op(:rx, [0], 0.0)] end, fn [] -> [] end),
      identity("zero_ry_is_identity", :simplify, 1, 0, fn [] -> [op(:ry, [0], 0.0)] end, fn [] -> [] end),
      identity("zero_rz_is_identity", :simplify, 1, 0, fn [] -> [op(:rz, [0], 0.0)] end, fn [] -> [] end),
      identity(
        "rz_composes",
        :fuse,
        1,
        2,
        fn [a, b] -> [op(:rz, [0], a), op(:rz, [0], b)] end,
        fn [a, b] -> [op(:rz, [0], a + b)] end
      ),
      identity(
        "rx_composes",
        :fuse,
        1,
        2,
        fn [a, b] -> [op(:rx, [0], a), op(:rx, [0], b)] end,
        fn [a, b] -> [op(:rx, [0], a + b)] end
      ),
      identity(
        "ry_composes",
        :fuse,
        1,
        2,
        fn [a, b] -> [op(:ry, [0], a), op(:ry, [0], b)] end,
        fn [a, b] -> [op(:ry, [0], a + b)] end
      ),
      identity(
        "hxh_is_z",
        :resynthesize_1q,
        1,
        0,
        fn [] -> [op(:h, [0]), op(:x, [0]), op(:h, [0])] end,
        fn [] -> [op(:z, [0])] end
      ),
      identity(
        "hzh_is_x",
        :resynthesize_1q,
        1,
        0,
        fn [] -> [op(:h, [0]), op(:z, [0]), op(:h, [0])] end,
        fn [] -> [op(:x, [0])] end
      ),
      identity(
        "xy_is_z_up_to_phase",
        :resynthesize_1q,
        1,
        0,
        fn [] -> [op(:x, [0]), op(:y, [0])] end,
        fn [] -> [op(:z, [0])] end
      )
    ]
  end

  defp identity(id, pass, qubits, angles, lhs, rhs) do
    %{id: id, pass: pass, qubits: qubits, angles: angles, lhs: lhs, rhs: rhs}
  end

  defp op(name, wires), do: GateOperation.new(name, wires)
  defp op(name, wires, theta), do: GateOperation.new(name, wires, theta: theta)
end
