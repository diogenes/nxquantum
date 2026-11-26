defmodule NxQuantum.Noise.ModelTest do
  use ExUnit.Case, async: true

  alias NxQuantum.Noise.Channel
  alias NxQuantum.Noise.Model

  setup do
    {:ok, depol} = Channel.depolarizing(0.1)
    {:ok, damp} = Channel.amplitude_damping(0.2)
    {:ok, flip} = Channel.bit_flip(0.05)
    {:ok, multi} = Channel.kraus([Nx.eye(4, type: {:c, 64})])
    %{depol: depol, damp: damp, flip: flip, multi: multi}
  end

  describe "new/0" do
    test "starts with no channels" do
      assert Model.channels_for(Model.new(), :h, [0, 1]) == []
    end
  end

  describe "add_gate_noise/3" do
    test "adds channels that apply to the named gate in insertion order", %{depol: depol, damp: damp} do
      {:ok, model} = Model.add_gate_noise(Model.new(), :rx, depol)
      {:ok, model} = Model.add_gate_noise(model, :rx, damp)

      assert Model.channels_for(model, :rx, [0]) == [depol, damp]
      assert Model.channels_for(model, :ry, [0]) == []
    end

    test "rejects a gate name that is not an atom", %{depol: depol} do
      assert {:error, %{code: :invalid_noise_model, target: :gate, reason: :invalid_gate_name}} =
               Model.add_gate_noise(Model.new(), "rx", depol)
    end

    test "rejects a value that is not a channel" do
      assert {:error, %{code: :invalid_noise_model, target: :channel, reason: :not_a_channel}} =
               Model.add_gate_noise(Model.new(), :rx, %{kraus: []})
    end
  end

  describe "add_qubit_noise/3" do
    test "applies to every gate that touches the qubit, after the gate channels", %{
      depol: depol,
      damp: damp,
      flip: flip
    } do
      {:ok, model} = Model.add_gate_noise(Model.new(), :cnot, depol)
      {:ok, model} = Model.add_qubit_noise(model, 1, damp)
      {:ok, model} = Model.add_qubit_noise(model, 0, flip)

      assert Model.channels_for(model, :cnot, [0, 1]) == [depol, flip, damp]
      assert Model.channels_for(model, :h, [1]) == [damp]
      assert Model.channels_for(model, :h, [2]) == []
    end

    test "rejects a negative or non-integer qubit", %{damp: damp} do
      assert {:error, %{target: :qubit, reason: :invalid_qubit}} =
               Model.add_qubit_noise(Model.new(), -1, damp)

      assert {:error, %{target: :qubit, reason: :invalid_qubit}} =
               Model.add_qubit_noise(Model.new(), 0.0, damp)
    end

    test "rejects a multi-qubit channel because it has no single wire", %{multi: multi} do
      assert {:error, %{code: :invalid_noise_model, target: :qubit, reason: :multi_qubit_channel, num_qubits: 2}} =
               Model.add_qubit_noise(Model.new(), 0, multi)
    end

    test "rejects a value that is not a channel" do
      assert {:error, %{target: :channel, reason: :not_a_channel}} =
               Model.add_qubit_noise(Model.new(), 0, :depolarizing)
    end
  end

  describe "purity and determinism" do
    test "the same inputs give equal models and equal lookups", %{depol: depol, damp: damp} do
      build = fn ->
        {:ok, m} = Model.add_gate_noise(Model.new(), :h, depol)
        {:ok, m} = Model.add_qubit_noise(m, 0, damp)
        m
      end

      assert build.() == build.()
      assert Model.channels_for(build.(), :h, [0]) == Model.channels_for(build.(), :h, [0])
    end

    test "adding a channel does not change the model it was added to", %{depol: depol} do
      original = Model.new()
      {:ok, _updated} = Model.add_gate_noise(original, :h, depol)

      assert Model.channels_for(original, :h, [0]) == []
    end
  end
end
