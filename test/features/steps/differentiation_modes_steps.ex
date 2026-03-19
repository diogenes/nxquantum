defmodule NxQuantum.Features.Steps.DifferentiationModesSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Circuit
  alias NxQuantum.Features.StepExecutor
  alias NxQuantum.GateOperation
  alias NxQuantum.Gates
  alias NxQuantum.Grad
  alias NxQuantum.Grad.Error
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "differentiation_modes.feature"

  @impl true
  def execute(step, ctx) do
    handlers = [&handle_setup/2, &handle_execution/2, &handle_assertions/2, &handle_errors/2]

    case StepExecutor.run(step, ctx, handlers) do
      {:handled, updated} -> updated
      :unhandled -> raise "unhandled step: #{step.text}"
    end
  end

  defp handle_setup(%{text: text}, ctx) do
    cond do
      text == "a one-qubit variational circuit with RY(theta)" ->
        objective = fn theta ->
          [qubits: 1]
          |> Circuit.new()
          |> Gates.ry(0, theta: theta)
          |> Circuit.expectation(observable: :pauli_z, wire: 0)
        end

        {:handled, Map.put(ctx, :objective, objective)}

      text =~ ~r/^theta is / ->
        {:handled, Map.put(ctx, :theta, Nx.tensor(Helpers.parse_quoted_number(text)))}

      text =~ ~r/^numerical tolerance is / ->
        {:handled, Map.put(ctx, :tolerance, Helpers.parse_quoted_number(text))}

      text =~ ~r/^gradient mode / ->
        {:handled, Map.put(ctx, :mode, String.to_atom(Helpers.parse_quoted(text)))}

      text == "a two-qubit circuit RX(theta_0) -> CNOT(0,1) -> RY(theta_1) is configured" ->
        objective = fn p ->
          [qubits: 2]
          |> Circuit.new()
          |> Gates.rx(0, theta: p[0])
          |> Gates.cnot(control: 0, target: 1)
          |> Gates.ry(1, theta: p[1])
          |> Circuit.expectation(observable: :pauli_z, wire: 1)
        end

        {:handled, Map.put(ctx, :objective2, objective)}

      text =~ ~r/^theta vector is / ->
        vec = text |> Helpers.parse_quoted() |> Helpers.parse_list_of_numbers()
        {:handled, Map.put(ctx, :theta_vec, Nx.tensor(vec))}

      text == "the circuit includes an unsupported operation for adjoint mode" ->
        objective = fn theta ->
          [qubits: 1]
          |> Circuit.new()
          |> Circuit.add_gate(GateOperation.new(:unsupported_gate, [0], theta: theta))
          |> Circuit.expectation(observable: :pauli_z, wire: 0)
        end

        {:handled, Map.put(ctx, :unsupported_objective, objective)}

      text == "no circuit builder is provided" ->
        {:handled, Map.put(ctx, :no_builder, true)}

      true ->
        :unhandled
    end
  end

  defp handle_execution(%{text: text}, ctx) do
    cond do
      text == "I compute the gradient of expectation loss with respect to theta" ->
        mode = Map.fetch!(ctx, :mode)
        {_loss, grad} = gradient_result_for_mode(mode, ctx)
        {:handled, Map.put(ctx, :gradient, Nx.to_number(grad))}

      text == "I compute gradients with adjoint and parameter_shift" ->
        objective = ctx.objective2
        params = ctx.theta_vec

        {_la, ga} =
          Grad.value_and_grad(objective, params,
            mode: :adjoint,
            circuit_builder: fn p ->
              [qubits: 2]
              |> Circuit.new()
              |> Gates.rx(0, theta: p[0])
              |> Gates.cnot(control: 0, target: 1)
              |> Gates.ry(1, theta: p[1])
              |> Map.put(:measurement, %{observable: :pauli_z, wire: 1})
            end
          )

        {lp, gp} = Grad.value_and_grad(objective, params, mode: :parameter_shift)

        updated =
          ctx
          |> Map.put(:grad_adj, Nx.to_flat_list(ga))
          |> Map.put(:grad_ps, Nx.to_flat_list(gp))
          |> Map.put(:loss_ps, Nx.to_number(lp))

        {:handled, updated}

      text == "I compute gradients" ->
        mode = Map.get(ctx, :mode, :adjoint)
        {:handled, Map.put(ctx, :grad_error, assert_grad_error(ctx, mode))}

      true ->
        :unhandled
    end
  end

  defp handle_assertions(%{text: text}, ctx) do
    cond do
      text =~ ~r/^the gradient should be approximately / ->
        assert_in_delta ctx.gradient, Helpers.parse_quoted_number(text), Map.get(ctx, :tolerance, 1.0e-4)
        {:handled, ctx}

      text =~ ~r/^each gradient component should match within / ->
        tol = Helpers.parse_quoted_number(text)
        ctx.grad_adj |> Enum.zip(ctx.grad_ps) |> Enum.each(fn {a, b} -> assert_in_delta a, b, tol end)
        {:handled, ctx}

      text == "both modes should return finite scalar loss" ->
        assert is_number(ctx.loss_ps)
        assert ctx.loss_ps == ctx.loss_ps
        {:handled, ctx}

      text == "the error includes the unsupported operation name" ->
        assert ctx.grad_error.details.operation == :unsupported_gate
        {:handled, ctx}

      text =~ ~r/^error / ->
        code = text |> Helpers.parse_quoted() |> String.to_atom()
        assert ctx.grad_error.code == code
        {:handled, ctx}

      true ->
        :unhandled
    end
  end

  defp handle_errors(%{text: "error \"adjoint_requires_circuit_builder\" is returned"}, ctx) do
    error =
      assert_raise Error, fn ->
        Grad.value_and_grad(ctx.objective, ctx.theta, mode: :adjoint)
      end

    assert error.code == :adjoint_requires_circuit_builder
    {:handled, Map.put(ctx, :grad_error, error)}
  end

  defp handle_errors(_step, _ctx), do: :unhandled

  defp gradient_result_for_mode(:adjoint, ctx) do
    Grad.value_and_grad(ctx.objective, ctx.theta,
      mode: :adjoint,
      circuit_builder: fn t ->
        [qubits: 1]
        |> Circuit.new()
        |> Gates.ry(0, theta: t)
        |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
      end
    )
  end

  defp gradient_result_for_mode(mode, ctx) do
    Grad.value_and_grad(ctx.objective, ctx.theta, mode: mode, epsilon: 1.0e-3)
  end

  defp assert_grad_error(ctx, mode) do
    assert_raise Error, fn ->
      Grad.value_and_grad(
        Map.get(ctx, :unsupported_objective, ctx.objective),
        Map.get(ctx, :theta, Nx.tensor(1.0)),
        mode: mode,
        circuit_builder:
          if(Map.has_key?(ctx, :unsupported_objective),
            do: fn t ->
              [qubits: 1]
              |> Circuit.new()
              |> Circuit.add_gate(GateOperation.new(:unsupported_gate, [0], theta: t))
              |> Map.put(:measurement, %{observable: :pauli_z, wire: 0})
            end
          )
      )
    end
  end
end
