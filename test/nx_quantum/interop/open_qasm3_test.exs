defmodule NxQuantum.Interop.OpenQASM3Test do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
  alias NxQuantum.Gates
  alias NxQuantum.Interop.OpenQASM3
  alias NxQuantum.TestSupport.RandomCircuits

  describe "to_qasm/2 golden output" do
    test "exports a Bell circuit without measurement" do
      circuit =
        [qubits: 2]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 1)

      assert {:ok, qasm} = OpenQASM3.to_qasm(circuit)

      assert qasm == """
             OPENQASM 3.0;
             include "stdgates.inc";
             qubit[2] q;
             h q[0];
             cx q[0], q[1];
             """
    end

    test "appends bit declaration and full-register measurement when measure: true" do
      circuit =
        [qubits: 2]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.cnot(control: 0, target: 1)

      assert {:ok, qasm} = OpenQASM3.to_qasm(circuit, measure: true)

      assert qasm == """
             OPENQASM 3.0;
             include "stdgates.inc";
             qubit[2] q;
             bit[2] c;
             h q[0];
             cx q[0], q[1];
             c = measure q;
             """
    end

    test "exports an empty circuit as declarations only" do
      assert {:ok, "OPENQASM 3.0;\ninclude \"stdgates.inc\";\nqubit[1] q;\n"} =
               OpenQASM3.to_qasm(Circuit.new(qubits: 1))
    end

    test "emits every supported gate with its stdgates name" do
      circuit =
        [qubits: 3]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.x(1)
        |> Gates.y(2)
        |> Gates.z(0)
        |> Gates.rx(1, theta: 0.5)
        |> Gates.ry(2, theta: -1.25)
        |> Gates.rz(0, theta: 3.141592653589793)
        |> Gates.cnot(control: 0, target: 1)
        |> Circuit.add_gate(GateOperation.new(:swap, [1, 2]))

      assert {:ok, qasm} = OpenQASM3.to_qasm(circuit)

      assert qasm == """
             OPENQASM 3.0;
             include "stdgates.inc";
             qubit[3] q;
             h q[0];
             x q[1];
             y q[2];
             z q[0];
             rx(0.5) q[1];
             ry(-1.25) q[2];
             rz(3.141592653589793) q[0];
             cx q[0], q[1];
             swap q[1], q[2];
             """
    end

    test "prints angles with full shortest round-trip float precision" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rx(0, theta: :math.pi() / 3)
        |> Gates.ry(0, theta: 1.0e-7)

      assert {:ok, qasm} = OpenQASM3.to_qasm(circuit)
      assert qasm =~ "rx(1.0471975511965976) q[0];\n"
      assert qasm =~ "ry(1.0e-7) q[0];\n"
    end

    test "prints an integer angle as a float literal" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rz(0, theta: 2)

      assert {:ok, qasm} = OpenQASM3.to_qasm(circuit)
      assert qasm =~ "rz(2.0) q[0];\n"
    end

    test "prints an Nx scalar angle from its stored value" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rx(0, theta: Nx.tensor(0.1, type: {:f, 32}))

      assert {:ok, qasm} = OpenQASM3.to_qasm(circuit)
      assert qasm =~ "rx(0.10000000149011612) q[0];\n"
    end
  end

  describe "to_qasm/2 typed errors" do
    test "names an unsupported gate and its operation index" do
      circuit =
        [qubits: 3]
        |> Circuit.new()
        |> Gates.h(0)
        |> Circuit.add_gate(GateOperation.new(:ccx, [0, 1, 2]))

      assert {:error,
              %{
                code: :unsupported_qasm_construct,
                construct: :gate,
                gate: :ccx,
                wires: [0, 1, 2],
                operation_index: 1
              }} = OpenQASM3.to_qasm(circuit)
    end

    test "rejects a parameterised gate that has extra parameters" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.h(0)
        |> Gates.rx(0, theta: 0.1, phase: 1)

      assert {:error,
              %{
                code: :unsupported_qasm_construct,
                construct: :unsupported_parameter,
                gate: :rx,
                parameter: :phase,
                operation_index: 1
              }} = OpenQASM3.to_qasm(circuit)
    end

    test "rejects a fixed gate that carries parameters" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Circuit.add_gate(GateOperation.new(:h, [0], angle: 1))

      assert {:error, %{code: :unsupported_qasm_construct, construct: :gate, gate: :h}} =
               OpenQASM3.to_qasm(circuit)
    end

    test "rejects an unbound symbolic angle" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rx(0, theta: :theta)

      assert {:error,
              %{
                code: :unsupported_qasm_construct,
                construct: :unbound_parameter,
                gate: :rx,
                parameter: :theta,
                value: :theta,
                operation_index: 0
              }} = OpenQASM3.to_qasm(circuit)
    end

    test "rejects a rotation with no angle" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.ry(0)

      assert {:error,
              %{
                code: :unsupported_qasm_construct,
                construct: :unbound_parameter,
                gate: :ry,
                parameter: :theta,
                value: nil
              }} = OpenQASM3.to_qasm(circuit)
    end

    test "rejects a non-scalar Nx angle" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rx(0, theta: Nx.tensor([0.1, 0.2]))

      assert {:error, %{code: :unsupported_qasm_construct, construct: :non_scalar_parameter, shape: {2}}} =
               OpenQASM3.to_qasm(circuit)
    end

    test "rejects a non-finite angle" do
      circuit =
        [qubits: 1]
        |> Circuit.new()
        |> Gates.rx(0, theta: Nx.tensor(:nan, type: {:f, 32}))

      assert {:error, %{code: :unsupported_qasm_construct, construct: :non_finite_parameter, gate: :rx}} =
               OpenQASM3.to_qasm(circuit)
    end

    test "rejects a circuit that carries an expectation observable" do
      circuit = %Circuit{qubits: 1, measurement: %{observable: :pauli_z, wire: 0}}

      assert {:error,
              %{
                code: :unsupported_qasm_construct,
                construct: :observable_measurement,
                observable: :pauli_z,
                wire: 0
              }} = OpenQASM3.to_qasm(circuit)
    end
  end

  describe "to_qasm/2 determinism" do
    test "the same circuit exports byte-identical text on repeated calls" do
      circuit = seeded_circuit({1, 2, 3}, 3, 40)

      assert {:ok, first} = OpenQASM3.to_qasm(circuit, measure: true)
      assert {:ok, second} = OpenQASM3.to_qasm(circuit, measure: true)
      assert first == second
    end

    test "the same seed set rebuilds a circuit that exports identically" do
      assert {:ok, first} = OpenQASM3.to_qasm(seeded_circuit({7, 8, 9}, 4, 60))
      assert {:ok, second} = OpenQASM3.to_qasm(seeded_circuit({7, 8, 9}, 4, 60))
      assert first == second
    end
  end

  defp seeded_circuit(seed, qubits, depth) do
    {operations, _state} = RandomCircuits.operations(RandomCircuits.seeded(seed), qubits, depth)

    Enum.reduce(operations, Circuit.new(qubits: qubits), fn operation, circuit ->
      Circuit.add_gate(circuit, operation)
    end)
  end
end
