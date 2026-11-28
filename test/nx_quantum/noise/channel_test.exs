defmodule NxQuantum.Noise.ChannelTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Noise.Channel

  @tolerance 1.0e-6

  describe "built-in constructors" do
    test "return single-qubit channels that pass the completeness check" do
      built = [
        Channel.depolarizing(0.3),
        Channel.amplitude_damping(0.2),
        Channel.phase_damping(0.4),
        Channel.pauli(0.1, 0.2, 0.3),
        Channel.bit_flip(0.25),
        Channel.phase_flip(0.5)
      ]

      for result <- built do
        assert {:ok, %Channel{num_qubits: 1} = channel} = result
        assert completeness_deviation(channel) <= @tolerance
      end
    end

    test "depolarizing completeness holds at the boundaries and inside the range" do
      for p <- [0, 0.25, 0.5, 1] do
        assert {:ok, channel} = Channel.depolarizing(p)
        assert completeness_deviation(channel) <= @tolerance
      end
    end

    test "publish the completeness tolerance used for c64 channels" do
      assert Channel.completeness_tolerance() == @tolerance
    end

    test "record the name and parameters of the channel" do
      assert {:ok, %Channel{name: :amplitude_damping, params: %{gamma: 0.2}}} =
               Channel.amplitude_damping(0.2)
    end
  end

  describe "analytic checks" do
    test "amplitude damping shrinks <X> of |+><+| to sqrt(1 - gamma)" do
      {:ok, channel} = Channel.amplitude_damping(0.2)
      rho = apply_channel(channel, plus())

      assert_in_delta expectation_x(rho), :math.sqrt(0.8), @tolerance
    end

    test "amplitude damping moves population of |1> into |0> with probability gamma" do
      {:ok, channel} = Channel.amplitude_damping(0.3)
      rho = apply_channel(channel, ket1())

      assert [p0, p1] = populations(rho)
      assert_in_delta p0, 0.3, @tolerance
      assert_in_delta p1, 0.7, @tolerance
    end

    test "phase damping shrinks <X> of |+><+| to sqrt(1 - lambda)" do
      {:ok, channel} = Channel.phase_damping(0.36)
      rho = apply_channel(channel, plus())

      assert_in_delta expectation_x(rho), 0.8, @tolerance
    end

    test "depolarizing with p = 1 maps |0><0| to the maximally mixed state" do
      {:ok, channel} = Channel.depolarizing(1)
      rho = apply_channel(channel, ket0())

      assert [p0, p1] = populations(rho)
      assert_in_delta p0, 0.5, @tolerance
      assert_in_delta p1, 0.5, @tolerance
    end

    test "depolarizing keeps |0><0| with weight 1 - p / 2" do
      {:ok, channel} = Channel.depolarizing(0.2)
      rho = apply_channel(channel, ket0())

      assert [p0, _p1] = populations(rho)
      assert_in_delta p0, 0.9, @tolerance
    end

    test "bit flip moves |0> to |1> with probability p" do
      {:ok, channel} = Channel.bit_flip(0.25)
      rho = apply_channel(channel, ket0())

      assert [_p0, p1] = populations(rho)
      assert_in_delta p1, 0.25, @tolerance
    end

    test "phase flip scales <X> of |+><+| to 1 - 2p" do
      {:ok, channel} = Channel.phase_flip(0.1)
      rho = apply_channel(channel, plus())

      assert_in_delta expectation_x(rho), 0.8, @tolerance
    end

    test "pauli channel moves |0> to |1> with probability px + py" do
      {:ok, channel} = Channel.pauli(0.1, 0.2, 0.3)
      rho = apply_channel(channel, ket0())

      assert [p0, p1] = populations(rho)
      assert_in_delta p1, 0.3, @tolerance
      assert_in_delta p0, 0.7, @tolerance
    end

    test "every channel preserves the trace of the density matrix" do
      {:ok, channel} = Channel.pauli(0.1, 0.2, 0.3)
      rho = apply_channel(channel, plus())

      assert_in_delta trace(rho), 1.0, @tolerance
    end
  end

  # Tolerance note: Kraus operators are built in f32 and then cast to c64, so the
  # deviation from the exact value is set by float32 rounding. eps32 = 2^-23 is about
  # 1.19e-7, so the 1.0e-6 tolerance is roughly 8x that scale. Inputs are fixed, so
  # these checks have no randomness.
  describe "depolarizing analytic checks" do
    test "coherence of |+><+| shrinks to (1 - p) / 2 at p = 0.2" do
      {:ok, channel} = Channel.depolarizing(0.2)
      rho = apply_channel(channel, plus())

      [_r00, r01, r10, _r11] = rho |> Nx.real() |> Nx.to_flat_list()

      assert_in_delta r01, 0.4, @tolerance
      assert_in_delta r10, 0.4, @tolerance
    end

    test "trace is preserved for |0><0| and |+><+| at p in {0, 0.25, 1}" do
      for rho_in <- [ket0(), plus()], p <- [0, 0.25, 1] do
        {:ok, channel} = Channel.depolarizing(p)
        rho = apply_channel(channel, rho_in)

        assert_in_delta trace(rho), 1.0, @tolerance
      end
    end

    test "<Z> of |0><0| after depolarizing(p) is (1 - p) for p in {0, 0.25, 1}" do
      for p <- [0, 0.25, 1] do
        {:ok, channel} = Channel.depolarizing(p)
        rho = apply_channel(channel, ket0())

        assert_in_delta expectation_z(rho), 1 - p, @tolerance
      end
    end

    test "accepts c128 Kraus operators and stores them as c64" do
      {:ok, reference} = Channel.depolarizing(0.2)
      c128 = Enum.map(reference.kraus, &Nx.as_type(&1, {:c, 128}))

      assert {:ok, channel} = Channel.kraus(c128)
      assert Enum.all?(channel.kraus, &(Nx.type(&1) == {:c, 64}))
      assert completeness_deviation(channel) <= @tolerance
    end
  end

  describe "kraus/1" do
    test "accepts a generic set of single-qubit Kraus operators" do
      {:ok, reference} = Channel.amplitude_damping(0.2)
      assert {:ok, channel} = Channel.kraus(reference.kraus)

      assert channel.name == :kraus
      assert channel.num_qubits == 1
      assert completeness_deviation(channel) <= @tolerance
    end

    test "infers the qubit count from the operator dimension" do
      identity = Nx.eye(4, type: {:c, 64})

      assert {:ok, %Channel{num_qubits: 2}} = Channel.kraus([identity])
    end

    test "rejects an empty or non-list operator set" do
      assert {:error, %{code: :invalid_noise_channel, channel: :kraus, reason: :invalid_kraus_list}} =
               Channel.kraus([])

      assert {:error, %{reason: :invalid_kraus_list}} = Channel.kraus(:not_a_list)
    end

    test "rejects an operator that is not a square tensor" do
      assert {:error, %{reason: :invalid_kraus_operator, index: 0}} =
               Channel.kraus([:not_a_tensor])

      assert {:error, %{reason: :invalid_kraus_operator, index: 0}} =
               Channel.kraus([Nx.tensor([1.0, 0.0], type: {:c, 64})])

      assert {:error, %{reason: :invalid_kraus_operator, index: 0}} =
               Channel.kraus([Nx.iota({2, 3}, type: {:c, 64})])
    end

    test "rejects operators with different dimensions" do
      assert {:error, %{reason: :invalid_kraus_operator, index: 1}} =
               Channel.kraus([Nx.eye(2, type: {:c, 64}), Nx.eye(4, type: {:c, 64})])
    end

    test "rejects a dimension that is not a power of two" do
      assert {:error, %{reason: :invalid_kraus_operator, dimension: 3}} =
               Channel.kraus([Nx.eye(3, type: {:c, 64})])
    end

    test "rejects an incomplete set and reports the deviation" do
      half = Nx.multiply(Nx.eye(2, type: {:c, 64}), 0.5)

      assert {:error, %{code: :invalid_noise_channel, reason: :incomplete} = error} =
               Channel.kraus([half])

      assert error.max_deviation > 0.5
      assert error.tolerance == @tolerance
    end
  end

  describe "parameter validation" do
    test "rejects probabilities outside [0, 1] and non-numbers" do
      assert_invalid_parameter(Channel.depolarizing(-0.1), :depolarizing, :p)
      assert_invalid_parameter(Channel.depolarizing(1.1), :depolarizing, :p)
      assert_invalid_parameter(Channel.amplitude_damping(2), :amplitude_damping, :gamma)
      assert_invalid_parameter(Channel.amplitude_damping("0.2"), :amplitude_damping, :gamma)
      assert_invalid_parameter(Channel.phase_damping(nil), :phase_damping, :lambda)
      assert_invalid_parameter(Channel.bit_flip(-0.5), :bit_flip, :p)
      assert_invalid_parameter(Channel.phase_flip(2), :phase_flip, :p)
    end

    test "rejects a Pauli component outside [0, 1]" do
      assert_invalid_parameter(Channel.pauli(-0.1, 0.0, 0.0), :pauli, :px)
      assert_invalid_parameter(Channel.pauli(0.0, 0.0, 1.5), :pauli, :pz)
    end

    test "rejects Pauli probabilities that sum above one" do
      assert {:error, %{code: :invalid_noise_channel, channel: :pauli, reason: :probabilities_exceed_one}} =
               Channel.pauli(0.5, 0.4, 0.2)
    end
  end

  defp assert_invalid_parameter(result, channel, parameter) do
    assert {:error,
            %{
              code: :invalid_noise_channel,
              channel: ^channel,
              reason: :invalid_parameter,
              parameter: ^parameter
            }} = result
  end

  defp plus, do: Nx.tensor([[0.5, 0.5], [0.5, 0.5]], type: {:c, 64})
  defp ket0, do: Nx.tensor([[1.0, 0.0], [0.0, 0.0]], type: {:c, 64})
  defp ket1, do: Nx.tensor([[0.0, 0.0], [0.0, 1.0]], type: {:c, 64})

  defp apply_channel(%Channel{kraus: kraus}, rho) do
    kraus
    |> Enum.map(fn k -> Nx.dot(Nx.dot(k, rho), Nx.conjugate(Nx.transpose(k))) end)
    |> Enum.reduce(&Nx.add/2)
  end

  defp completeness_deviation(%Channel{kraus: [first | rest]}) do
    sum =
      Enum.reduce(rest, kdag_k(first), fn k, acc -> Nx.add(acc, kdag_k(k)) end)

    sum
    |> Nx.subtract(Nx.eye(2, type: {:c, 64}))
    |> Nx.abs()
    |> Nx.reduce_max()
    |> Nx.to_number()
  end

  defp kdag_k(k), do: Nx.dot(Nx.conjugate(Nx.transpose(k)), k)

  defp expectation_x(rho) do
    x = Nx.tensor([[0.0, 1.0], [1.0, 0.0]], type: {:c, 64})

    rho
    |> Nx.multiply(x)
    |> Nx.sum()
    |> Nx.real()
    |> Nx.to_number()
  end

  defp expectation_z(rho) do
    z = Nx.tensor([[1.0, 0.0], [0.0, -1.0]], type: {:c, 64})

    rho
    |> Nx.multiply(z)
    |> Nx.sum()
    |> Nx.real()
    |> Nx.to_number()
  end

  defp populations(rho) do
    rho
    |> Nx.take_diagonal()
    |> Nx.real()
    |> Nx.to_flat_list()
  end

  defp trace(rho) do
    rho
    |> Nx.take_diagonal()
    |> Nx.real()
    |> Nx.sum()
    |> Nx.to_number()
  end
end
