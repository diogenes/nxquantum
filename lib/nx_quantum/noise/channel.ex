defmodule NxQuantum.Noise.Channel do
  @moduledoc """
  Kraus-operator noise channels (experimental).

  A channel is a list of Kraus operators `K_k`, each a complex (`{:c, 64}`) Nx tensor.
  Every constructor validates its parameters and checks Kraus completeness,
  `sum_k K_k^† K_k = I`, within `completeness_tolerance/0`. Constructors return
  `{:ok, channel}` or `{:error, %{code: :invalid_noise_channel, channel: name, reason: reason, ...}}`.

  Conventions:

    * `depolarizing(p)` maps `rho` to `(1 - p) rho + p I / 2`, so `p = 1` is the maximally mixed state.
    * `amplitude_damping(gamma)` and `phase_damping(lambda)` use the standard Kraus operators
      of Nielsen and Chuang.
    * `pauli(px, py, pz)` maps `rho` to `(1 - px - py - pz) rho + px X rho X + py Y rho Y + pz Z rho Z`.
    * `bit_flip(p)` and `phase_flip(p)` are the one-parameter Pauli X and Z channels.

  This module is pure: it has no backend, adapter or randomness. It does not change how the
  scalar `noise:` option of the Estimator and Sampler works.
  """

  import Bitwise

  @completeness_tolerance 1.0e-6

  @enforce_keys [:name, :kraus, :params, :num_qubits]
  defstruct [:name, :kraus, :params, :num_qubits]

  @type t :: %__MODULE__{
          name: atom(),
          kraus: [Nx.Tensor.t()],
          params: map(),
          num_qubits: pos_integer()
        }

  @type error :: %{
          required(:code) => :invalid_noise_channel,
          required(:channel) => atom(),
          required(:reason) => atom(),
          optional(atom()) => term()
        }

  @doc "Largest accepted deviation of `sum_k K_k^† K_k` from the identity, in each entry."
  @spec completeness_tolerance() :: float()
  def completeness_tolerance, do: @completeness_tolerance

  @doc "Depolarizing channel `(1 - p) rho + p I / 2` with `p` in `[0, 1]`."
  @spec depolarizing(number()) :: {:ok, t()} | {:error, error()}
  def depolarizing(p) do
    with :ok <- probability(:depolarizing, :p, p) do
      build(
        :depolarizing,
        %{p: p},
        [
          scaled_pauli(:i, :math.sqrt(1 - 3 * p / 4)),
          scaled_pauli(:x, :math.sqrt(p) / 2),
          scaled_pauli(:y, :math.sqrt(p) / 2),
          scaled_pauli(:z, :math.sqrt(p) / 2)
        ]
      )
    end
  end

  @doc "Amplitude damping channel with decay probability `gamma` in `[0, 1]`."
  @spec amplitude_damping(number()) :: {:ok, t()} | {:error, error()}
  def amplitude_damping(gamma) do
    with :ok <- probability(:amplitude_damping, :gamma, gamma) do
      build(
        :amplitude_damping,
        %{gamma: gamma},
        [
          kraus_matrix([[1.0, 0.0], [0.0, :math.sqrt(1 - gamma)]], zeros()),
          kraus_matrix([[0.0, :math.sqrt(gamma)], [0.0, 0.0]], zeros())
        ]
      )
    end
  end

  @doc "Phase damping channel with dephasing probability `lambda` in `[0, 1]`."
  @spec phase_damping(number()) :: {:ok, t()} | {:error, error()}
  def phase_damping(lambda) do
    with :ok <- probability(:phase_damping, :lambda, lambda) do
      build(
        :phase_damping,
        %{lambda: lambda},
        [
          kraus_matrix([[1.0, 0.0], [0.0, :math.sqrt(1 - lambda)]], zeros()),
          kraus_matrix([[0.0, 0.0], [0.0, :math.sqrt(lambda)]], zeros())
        ]
      )
    end
  end

  @doc "Pauli channel with X, Y and Z probabilities `px`, `py`, `pz`, each in `[0, 1]`, summing to at most 1."
  @spec pauli(number(), number(), number()) :: {:ok, t()} | {:error, error()}
  def pauli(px, py, pz) do
    with :ok <- probability(:pauli, :px, px),
         :ok <- probability(:pauli, :py, py),
         :ok <- probability(:pauli, :pz, pz),
         :ok <- total_probability(px + py + pz) do
      identity = max(0.0, 1.0 - px - py - pz)

      build(
        :pauli,
        %{px: px, py: py, pz: pz},
        [
          scaled_pauli(:i, :math.sqrt(identity)),
          scaled_pauli(:x, :math.sqrt(px)),
          scaled_pauli(:y, :math.sqrt(py)),
          scaled_pauli(:z, :math.sqrt(pz))
        ]
      )
    end
  end

  @doc "Bit flip channel: Pauli X with probability `p` in `[0, 1]`."
  @spec bit_flip(number()) :: {:ok, t()} | {:error, error()}
  def bit_flip(p) do
    with :ok <- probability(:bit_flip, :p, p) do
      build(
        :bit_flip,
        %{p: p},
        [scaled_pauli(:i, :math.sqrt(1 - p)), scaled_pauli(:x, :math.sqrt(p))]
      )
    end
  end

  @doc "Phase flip channel: Pauli Z with probability `p` in `[0, 1]`."
  @spec phase_flip(number()) :: {:ok, t()} | {:error, error()}
  def phase_flip(p) do
    with :ok <- probability(:phase_flip, :p, p) do
      build(
        :phase_flip,
        %{p: p},
        [scaled_pauli(:i, :math.sqrt(1 - p)), scaled_pauli(:z, :math.sqrt(p))]
      )
    end
  end

  @doc """
  Channel from a list of square Kraus operators.

  Every operator must be an Nx tensor of shape `{d, d}` with `d = 2^k` and `k >= 1`, and all
  operators must share `d`. The qubit count is `k`. Operators are converted to `{:c, 64}`.
  """
  @spec kraus([Nx.Tensor.t()]) :: {:ok, t()} | {:error, error()}
  def kraus(operators) when is_list(operators) and operators != [] do
    with {:ok, tensors, num_qubits} <- normalize_operators(operators) do
      build(:kraus, %{}, tensors, num_qubits)
    end
  end

  def kraus(_operators) do
    {:error, error(:kraus, :invalid_kraus_list, %{expected: "non-empty list of square tensors"})}
  end

  defp probability(_channel, _parameter, value) when is_number(value) and value >= 0 and value <= 1, do: :ok

  defp probability(channel, parameter, value) do
    {:error,
     error(channel, :invalid_parameter, %{
       parameter: parameter,
       value: value,
       expected: "number in [0, 1]"
     })}
  end

  defp total_probability(sum) when sum <= 1.0 + @completeness_tolerance, do: :ok

  defp total_probability(sum) do
    {:error, error(:pauli, :probabilities_exceed_one, %{sum: sum, expected: "sum <= 1"})}
  end

  defp normalize_operators(operators) do
    dims = Enum.map(operators, &operator_dim/1)
    dim = hd(dims)

    case Enum.find_index(dims, &(&1 == nil or &1 != dim)) do
      nil -> normalize_dimension(operators, dim)
      index -> {:error, invalid_operator(index, "square tensors of one dimension 2^k")}
    end
  end

  defp normalize_dimension(operators, dim) do
    case qubits_for_dim(dim) do
      {:ok, num_qubits} ->
        {:ok, Enum.map(operators, &Nx.as_type(&1, {:c, 64})), num_qubits}

      :error ->
        {:error,
         error(:kraus, :invalid_kraus_operator, %{
           dimension: dim,
           expected: "dimension 2^k with k >= 1"
         })}
    end
  end

  defp operator_dim(%Nx.Tensor{shape: {dim, dim}}) when dim >= 2, do: dim
  defp operator_dim(_other), do: nil

  defp qubits_for_dim(dim) do
    k = trunc(:math.log2(dim))
    if bsl(1, k) == dim, do: {:ok, k}, else: :error
  end

  defp invalid_operator(index, expected) do
    error(:kraus, :invalid_kraus_operator, %{index: index, expected: expected})
  end

  defp build(name, params, kraus, num_qubits \\ 1) do
    deviation = completeness_deviation(kraus)

    if deviation <= @completeness_tolerance do
      {:ok, %__MODULE__{name: name, kraus: kraus, params: params, num_qubits: num_qubits}}
    else
      {:error, error(name, :incomplete, %{max_deviation: deviation, tolerance: @completeness_tolerance})}
    end
  end

  defp completeness_deviation([first | rest]) do
    sum = Enum.reduce(rest, kdag_k(first), fn k, acc -> Nx.add(acc, kdag_k(k)) end)
    dim = elem(Nx.shape(first), 0)

    sum
    |> Nx.subtract(Nx.eye(dim, type: {:c, 64}))
    |> Nx.abs()
    |> Nx.reduce_max()
    |> Nx.to_number()
  end

  defp kdag_k(k), do: Nx.dot(Nx.conjugate(Nx.transpose(k)), k)

  defp error(channel, reason, details) do
    Map.merge(%{code: :invalid_noise_channel, channel: channel, reason: reason}, details)
  end

  defp scaled_pauli(:i, s), do: kraus_matrix(scale([[1.0, 0.0], [0.0, 1.0]], s), zeros())
  defp scaled_pauli(:x, s), do: kraus_matrix(scale([[0.0, 1.0], [1.0, 0.0]], s), zeros())
  defp scaled_pauli(:y, s), do: kraus_matrix(zeros(), scale([[0.0, -1.0], [1.0, 0.0]], s))
  defp scaled_pauli(:z, s), do: kraus_matrix(scale([[1.0, 0.0], [0.0, -1.0]], s), zeros())

  defp kraus_matrix(real_rows, imag_rows) do
    Nx.complex(
      Nx.tensor(real_rows, type: {:f, 32}),
      Nx.tensor(imag_rows, type: {:f, 32})
    )
  end

  defp scale(rows, s), do: Enum.map(rows, fn row -> Enum.map(row, &(&1 * s)) end)

  defp zeros, do: [[0.0, 0.0], [0.0, 0.0]]
end
