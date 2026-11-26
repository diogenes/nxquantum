defmodule NxQuantum.Noise.Model do
  @moduledoc """
  Map from gate names and qubit wires to noise channels (experimental).

  A model holds two maps: channels keyed by gate name, and channels keyed by qubit wire.
  `channels_for/3` returns the channels that follow a gate, in a fixed order: the gate's channels in
  insertion order, then the channels of each listed qubit in the order given. Channels on a qubit
  must be single-qubit channels (`num_qubits: 1`).

  The model is a pure value. It does not apply channels, contain an executor, or use randomness.
  """

  alias NxQuantum.Noise.Channel

  defstruct gate_channels: %{}, qubit_channels: %{}

  @type t :: %__MODULE__{
          gate_channels: %{atom() => [Channel.t()]},
          qubit_channels: %{non_neg_integer() => [Channel.t()]}
        }

  @type error :: %{
          required(:code) => :invalid_noise_model,
          required(:target) => :gate | :qubit | :channel,
          required(:reason) => atom(),
          optional(atom()) => term()
        }

  @doc "An empty model with no channels."
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc "Appends `channel` to the channels of gate `gate`. The gate name must be an atom."
  @spec add_gate_noise(t(), atom(), Channel.t()) :: {:ok, t()} | {:error, error()}
  def add_gate_noise(%__MODULE__{} = model, gate, channel) do
    with :ok <- check_gate(gate),
         :ok <- check_channel(channel) do
      {:ok, %{model | gate_channels: append(model.gate_channels, gate, channel)}}
    end
  end

  @doc "Appends single-qubit `channel` to the channels of wire `qubit`."
  @spec add_qubit_noise(t(), non_neg_integer(), Channel.t()) :: {:ok, t()} | {:error, error()}
  def add_qubit_noise(%__MODULE__{} = model, qubit, channel) do
    with :ok <- check_qubit(qubit),
         :ok <- check_channel(channel),
         :ok <- check_single_qubit(channel) do
      {:ok, %{model | qubit_channels: append(model.qubit_channels, qubit, channel)}}
    end
  end

  @doc "Channels that follow `gate` applied to `qubits`, in the order described in the moduledoc."
  @spec channels_for(t(), atom(), [non_neg_integer()]) :: [Channel.t()]
  def channels_for(%__MODULE__{} = model, gate, qubits) when is_list(qubits) do
    Map.get(model.gate_channels, gate, []) ++
      Enum.flat_map(qubits, &Map.get(model.qubit_channels, &1, []))
  end

  defp check_gate(gate) when is_atom(gate), do: :ok

  defp check_gate(gate) do
    {:error, error(:gate, :invalid_gate_name, %{value: gate, expected: "atom gate name"})}
  end

  defp check_qubit(qubit) when is_integer(qubit) and qubit >= 0, do: :ok

  defp check_qubit(qubit) do
    {:error, error(:qubit, :invalid_qubit, %{value: qubit, expected: "integer >= 0"})}
  end

  defp check_channel(%Channel{}), do: :ok

  defp check_channel(value) do
    {:error, error(:channel, :not_a_channel, %{value: value, expected: "NxQuantum.Noise.Channel"})}
  end

  defp check_single_qubit(%Channel{num_qubits: 1}), do: :ok

  defp check_single_qubit(%Channel{num_qubits: num_qubits}) do
    {:error, error(:qubit, :multi_qubit_channel, %{num_qubits: num_qubits})}
  end

  defp append(map, key, channel) do
    Map.update(map, key, [channel], &(&1 ++ [channel]))
  end

  defp error(target, reason, details) do
    Map.merge(%{code: :invalid_noise_model, target: target, reason: reason}, details)
  end
end
