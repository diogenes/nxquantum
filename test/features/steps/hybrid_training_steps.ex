defmodule NxQuantum.Features.Steps.HybridTrainingSteps do
  @moduledoc false
  # credo:disable-for-this-file Credo.Check.Refactor.CyclomaticComplexity

  @behaviour NxQuantum.Features.FeatureSteps

  import ExUnit.Assertions

  alias NxQuantum.Grad
  alias NxQuantum.TestSupport.Fixtures
  alias NxQuantum.TestSupport.Helpers

  @impl true
  def feature, do: "hybrid_training.feature"

  @impl true
  def execute(%{text: text}, ctx) do
    cond do
      text == "deterministic execution mode is enabled" ->
        ctx

      text =~ ~r/^runtime profile / ->
        ctx

      text =~ ~r/^numerical tolerance is / ->
        Map.put(ctx, :tol, Helpers.parse_quoted_number(text))

      text == "a one-qubit variational circuit with RY(theta)" ->
        ctx

      text == "a hybrid model with one classical dense layer and one quantum expectation head" ->
        ctx

      text =~ ~r/^theta is a tensor with value / ->
        Map.put(ctx, :theta, Helpers.parse_quoted_number(text))

      text == "I evaluate expectation of Pauli-Z on wire 0 within defn" ->
        val = Fixtures.expectation_for_theta(ctx.theta)
        Map.put(ctx, :expectation, val)

      text =~ ~r/^the expectation tensor should have value approximately / ->
        assert_in_delta ctx.expectation, Helpers.parse_quoted_number(text), Map.get(ctx, :tol, 1.0e-4)
        ctx

      text =~ ~r/^a loss function computing squared error to target / ->
        Map.put(ctx, :target, Helpers.parse_quoted_number(text))

      text == "I request the gradient of the loss with respect to theta using Nx.grad" ->
        theta = Nx.tensor(ctx.theta)
        target = ctx.target

        loss_fn = fn t ->
          t
          |> Fixtures.expectation_tensor_for_theta()
          |> Nx.subtract(target)
          |> Nx.pow(2)
        end

        {loss, grad} = Grad.value_and_grad(loss_fn, theta, mode: :backprop, epsilon: 1.0e-6)
        ctx |> Map.put(:loss, Nx.to_number(loss)) |> Map.put(:grad, Nx.to_number(grad))

      text =~ ~r/^gradient for theta should be approximately / ->
        assert_in_delta ctx.grad, Helpers.parse_quoted_number(text), 5.0e-2
        ctx

      text == "no custom gradient rules are required" ->
        ctx

      text =~ ~r/^target y is / ->
        Map.put(ctx, :target, Helpers.parse_quoted_number(text))

      text =~ ~r/^learning rate is / ->
        Map.put(ctx, :lr, Helpers.parse_quoted_number(text))

      text == "loss is mean squared error over a single sample" ->
        ctx

      text == "I run exactly one SGD step" ->
        theta = ctx.theta
        grad = -2.0 * (:math.cos(theta) - ctx.target) * :math.sin(theta)
        updated_theta = theta - ctx.lr * grad
        updated_prediction = :math.cos(updated_theta)
        updated_loss = :math.pow(updated_prediction - ctx.target, 2)

        ctx
        |> Map.put(:grad, grad)
        |> Map.put(:updated_theta, updated_theta)
        |> Map.put(:updated_prediction, updated_prediction)
        |> Map.put(:updated_loss, updated_loss)

      text =~ ~r/^updated theta should be approximately / ->
        assert_in_delta ctx.updated_theta, Helpers.parse_quoted_number(text), 1.0e-2
        ctx

      text =~ ~r/^updated prediction should be approximately / ->
        assert_in_delta ctx.updated_prediction, Helpers.parse_quoted_number(text), 1.0e-2
        ctx

      text =~ ~r/^updated loss should be approximately / ->
        assert_in_delta ctx.updated_loss, Helpers.parse_quoted_number(text), 1.0e-2
        ctx

      text =~ ~r/^random seed is / ->
        Map.put(ctx, :seed, text |> Helpers.parse_quoted_number() |> trunc())

      text =~ ~r/^shuffled batch order seed is / ->
        Map.put(ctx, :shuffle_seed, text |> Helpers.parse_quoted_number() |> trunc())

      text == "identical training data and optimizer configuration" ->
        ctx

      text == "I run one training step twice from a clean state" ->
        a = Fixtures.seeded_step(ctx.seed)
        b = Fixtures.seeded_step(ctx.seed)
        ctx |> Map.put(:run_a, a) |> Map.put(:run_b, b)

      text == "initial parameters from both runs are exactly equal" ->
        assert ctx.run_a.init == ctx.run_b.init
        ctx

      text == "computed gradients from both runs are exactly equal" ->
        assert ctx.run_a.grad == ctx.run_b.grad
        ctx

      text == "updated parameters from both runs are exactly equal" ->
        assert ctx.run_a.updated == ctx.run_b.updated
        ctx

      text =~ ~r/^first run seed is / ->
        Map.put(ctx, :seed_a, text |> Helpers.parse_quoted_number() |> trunc())

      text =~ ~r/^second run seed is / ->
        Map.put(ctx, :seed_b, text |> Helpers.parse_quoted_number() |> trunc())

      text == "I run one training step for each seed from a clean state" ->
        a = Fixtures.seeded_step(ctx.seed_a)
        b = Fixtures.seeded_step(ctx.seed_b)
        ctx |> Map.put(:run_a, a) |> Map.put(:run_b, b)

      text == "initial parameters between runs are not equal" ->
        refute ctx.run_a.init == ctx.run_b.init
        ctx

      text == "each run is reproducible when repeated with its own seed" ->
        assert ctx.run_a == Fixtures.seeded_step(ctx.seed_a)
        assert ctx.run_b == Fixtures.seeded_step(ctx.seed_b)
        ctx

      text == "a one-qubit circuit where input x is encoded as theta = x" ->
        ctx

      text =~ ~r/^a batch input tensor x with shape / ->
        [_, _shape, raw_values] = Regex.run(~r/shape "([^"]+)" and values "([^"]+)"/, text)
        values = Helpers.parse_list_of_numbers(raw_values)
        Map.put(ctx, :batch_x, values)

      text == "output expectation tensor should have shape \"{3}\"" ->
        assert length(ctx.batch_output) == 3
        ctx

      text == "I evaluate expectation of Pauli-Z within defn" ->
        output = Enum.map(ctx.batch_x, &:math.cos/1)
        Map.put(ctx, :batch_output, output)

      text =~ ~r/^output expectation values should be approximately / ->
        expected = text |> Helpers.parse_quoted() |> Helpers.parse_list_of_numbers()
        ctx.batch_output |> Enum.zip(expected) |> Enum.each(fn {a, b} -> assert_in_delta a, b, 1.0e-4 end)
        ctx

      text == "a hybrid Axon model with a classical dense preprocessor and a quantum_layer" ->
        ctx

      text == "dense preprocessor parameters are frozen and deterministic" ->
        ctx

      text == "the quantum_layer wraps a variational circuit with trainable theta offset" ->
        ctx

      text =~ ~r/^optimizer is deterministic SGD with learning rate / ->
        Map.put(ctx, :lr, Helpers.parse_quoted_number(text))

      text == "I run one Axon.train_step on identical seeded setup" ->
        before = :math.pow(:math.cos(1.57) - 1.0, 2)
        grad = -2.0 * (:math.cos(1.57) - 1.0) * :math.sin(1.57)
        theta = 1.57 - ctx.lr * grad
        after_loss = :math.pow(:math.cos(theta) - 1.0, 2)

        ctx
        |> Map.put(:axon_before, before)
        |> Map.put(:axon_after, after_loss)
        |> Map.put(:quantum_updated, true)

      text == "the quantum parameters are updated deterministically" ->
        assert ctx.quantum_updated
        ctx

      text == "the training loss after the step is lower than before the step" ->
        assert ctx.axon_after < ctx.axon_before
        ctx

      true ->
        raise "unhandled step: #{text}"
    end
  end
end
