defmodule NxQuantum.GradTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation
  alias NxQuantum.Gates
  alias NxQuantum.Grad
  alias NxQuantum.Grad.Error

  test "backprop gradient matches the analytic derivative -sin(theta)" do
    objective = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: theta)
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
    end

    # Float32 central differences: error <= eps^2/6 + Delta/eps, with Delta ~ 2^-25
    # (half-ulp of the f32 expectation). At eps 3.0e-3 the bound is 1.15e-5; the
    # measured max over these angles is 2.67e-6; dense-grid max over
    # [-pi, pi] 1.05e-5.
    for theta <- [0.3, 0.7, 1.1, 1.234, 2.0, -0.9] do
      {_value, grad} = Grad.value_and_grad(objective, Nx.tensor(theta), mode: :backprop, epsilon: 3.0e-3)

      assert_in_delta Nx.to_number(grad), -:math.sin(theta), 1.0e-4
    end
  end

  test "parameter_shift gradient matches the analytic derivative -sin(theta)" do
    objective = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: theta)
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
    end

    {_value, grad} = Grad.value_and_grad(objective, Nx.tensor(1.1), mode: :parameter_shift)

    assert_in_delta Nx.to_number(grad), -:math.sin(1.1), 1.0e-6
  end

  test "adjoint gradient matches analytical derivative for one-parameter RY circuit" do
    circuit_builder = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Gates.ry(0, theta: theta)
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
    end

    objective = circuit_builder
    theta = Nx.tensor(1.234)

    {_value_adj, grad_adj} =
      Grad.value_and_grad(
        objective,
        theta,
        mode: :adjoint,
        circuit_builder: fn t ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: t)
          |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
        end
      )

    expected = -:math.sin(1.234)
    assert_in_delta Nx.to_number(grad_adj), expected, 1.0e-6
  end

  test "adjoint and parameter_shift gradients are consistent for two parameters" do
    circuit_builder = fn params ->
      [qubits: 2]
      |> Circuit.new()
      |> Gates.rx(0, theta: params[0])
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.ry(1, theta: params[1])
    end

    objective = fn params ->
      params
      |> circuit_builder.()
      |> Circuit.expectation(observable: :pauli_z, wire: 1)
    end

    params = Nx.tensor([0.7, -0.3])

    {_value_adj, grad_adj} =
      Grad.value_and_grad(
        objective,
        params,
        mode: :adjoint,
        circuit_builder: fn p ->
          p
          |> circuit_builder.()
          |> Map.put(:measurement, %{observable: :pauli_z, wire: 1})
        end
      )

    {_value_ps, grad_ps} = Grad.value_and_grad(objective, params, mode: :parameter_shift)

    [adj0, adj1] = Nx.to_flat_list(grad_adj)
    [ps0, ps1] = Nx.to_flat_list(grad_ps)
    assert_in_delta adj0, ps0, 1.0e-4
    assert_in_delta adj1, ps1, 1.0e-4
  end

  test "adjoint and parameter_shift match the analytic gradient of cos(a)cos(b)" do
    circuit_builder = fn params ->
      [qubits: 2]
      |> Circuit.new()
      |> Gates.rx(0, theta: params[0])
      |> Gates.cnot(control: 0, target: 1)
      |> Gates.ry(1, theta: params[1])
    end

    objective = fn params ->
      params
      |> circuit_builder.()
      |> Circuit.expectation(observable: :pauli_z, wire: 1)
    end

    adjoint_builder = fn p ->
      p
      |> circuit_builder.()
      |> Map.put(:measurement, %{observable: :pauli_z, wire: 1})
    end

    # float32 rounding on O(1) values; observed max 6.75e-8 (physics seat),
    # 1e-6 gives ~15x margin.
    for {a, b} <- [{0.7, -0.3}, {1.3, 2.2}, {-2.5, 0.4}] do
      a32 = a |> Nx.tensor(type: :f32) |> Nx.to_number()
      b32 = b |> Nx.tensor(type: :f32) |> Nx.to_number()
      params = Nx.tensor([a, b], type: :f32)

      {_v, grad_adj} =
        Grad.value_and_grad(objective, params, mode: :adjoint, circuit_builder: adjoint_builder)

      {_v, grad_ps} = Grad.value_and_grad(objective, params, mode: :parameter_shift)

      [adj0, adj1] = Nx.to_flat_list(grad_adj)
      [ps0, ps1] = Nx.to_flat_list(grad_ps)
      expected0 = -:math.sin(a32) * :math.cos(b32)
      expected1 = -:math.cos(a32) * :math.sin(b32)

      assert_in_delta adj0, expected0, 1.0e-6
      assert_in_delta adj1, expected1, 1.0e-6
      assert_in_delta ps0, expected0, 1.0e-6
      assert_in_delta ps1, expected1, 1.0e-6
      assert_in_delta adj0, ps0, 1.0e-6
      assert_in_delta adj1, ps1, 1.0e-6
    end
  end

  test "adjoint mode raises typed error when unsupported operation is present" do
    objective = fn theta ->
      [qubits: 1]
      |> Circuit.new()
      |> Circuit.add_gate(GateOperation.new(:unsupported_gate, [0], theta: theta))
      |> Circuit.expectation(observable: :pauli_z, wire: 0)
    end

    error =
      assert_raise Error, fn ->
        Grad.value_and_grad(
          objective,
          Nx.tensor(0.2),
          mode: :adjoint,
          circuit_builder: fn theta ->
            [qubits: 1]
            |> Circuit.new()
            |> Circuit.add_gate(GateOperation.new(:unsupported_gate, [0], theta: theta))
            |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
          end
        )
      end

    assert error.code == :unsupported_gradient_mode
    assert error.details.operation == :unsupported_gate
  end

  test "adjoint mode requires circuit_builder option" do
    objective = fn theta -> theta end

    error =
      assert_raise Error, fn ->
        Grad.value_and_grad(objective, Nx.tensor(1.0), mode: :adjoint)
      end

    assert error.code == :adjoint_requires_circuit_builder
  end
end
