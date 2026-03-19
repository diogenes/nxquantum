defmodule NxQuantum.Grad do
  @moduledoc """
  Gradient orchestration facade for quantum objective functions.

  Planned modes:
  - `:backprop` (default)
  - `:parameter_shift`
  - `:adjoint`
  """

  alias NxQuantum.Grad.Adjoint
  alias NxQuantum.Grad.Numeric

  @type mode :: :backprop | :parameter_shift | :adjoint

  @spec value_and_grad((Nx.Tensor.t() -> Nx.Tensor.t()), Nx.Tensor.t(), keyword()) ::
          {Nx.Tensor.t(), Nx.Tensor.t()}
  def value_and_grad(fun, %Nx.Tensor{} = params, opts \\ []) when is_function(fun, 1) do
    mode = Keyword.get(opts, :mode, :backprop)

    case mode do
      :backprop ->
        epsilon = Keyword.get(opts, :epsilon, 1.0e-4)
        Numeric.finite_difference(fun, params, epsilon)

      :parameter_shift ->
        shift = Keyword.get(opts, :shift, :math.pi() / 2.0)
        Numeric.parameter_shift(fun, params, shift)

      :adjoint ->
        Adjoint.value_and_grad(fun, params, opts)

      unsupported_mode ->
        raise ArgumentError, "unsupported gradient mode #{inspect(unsupported_mode)}"
    end
  end
end
