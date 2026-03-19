defmodule NxQuantum.Gates do
  @moduledoc """
  Pipe-friendly gate constructors for `NxQuantum.Circuit`.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.Circuit.Validation
  alias NxQuantum.GateOperation

  @spec h(Circuit.t(), non_neg_integer()) :: Circuit.t()
  def h(%Circuit{} = circuit, wire), do: add_single_qubit_gate(circuit, :h, wire)

  @spec x(Circuit.t(), non_neg_integer()) :: Circuit.t()
  def x(%Circuit{} = circuit, wire), do: add_single_qubit_gate(circuit, :x, wire)

  @spec y(Circuit.t(), non_neg_integer()) :: Circuit.t()
  def y(%Circuit{} = circuit, wire), do: add_single_qubit_gate(circuit, :y, wire)

  @spec z(Circuit.t(), non_neg_integer()) :: Circuit.t()
  def z(%Circuit{} = circuit, wire), do: add_single_qubit_gate(circuit, :z, wire)

  @spec rx(Circuit.t(), non_neg_integer(), keyword()) :: Circuit.t()
  def rx(%Circuit{} = circuit, wire, opts \\ []), do: add_rotation_gate(circuit, :rx, wire, opts)

  @spec ry(Circuit.t(), non_neg_integer(), keyword()) :: Circuit.t()
  def ry(%Circuit{} = circuit, wire, opts \\ []), do: add_rotation_gate(circuit, :ry, wire, opts)

  @spec rz(Circuit.t(), non_neg_integer(), keyword()) :: Circuit.t()
  def rz(%Circuit{} = circuit, wire, opts \\ []), do: add_rotation_gate(circuit, :rz, wire, opts)

  @spec cnot(Circuit.t(), keyword()) :: Circuit.t()
  def cnot(%Circuit{} = circuit, opts) when is_list(opts) do
    control = Validation.fetch_wire_option!(opts, :control)
    target = Validation.fetch_wire_option!(opts, :target)
    {control, target} = Validation.validate_wire_pair!(control, target)
    Circuit.add_gate(circuit, GateOperation.new(:cnot, [control, target]))
  end

  defp add_single_qubit_gate(circuit, gate_name, wire) do
    normalized_wire = Validation.validate_wire!(wire)
    Circuit.add_gate(circuit, GateOperation.new(gate_name, [normalized_wire]))
  end

  defp add_rotation_gate(circuit, gate_name, wire, opts) do
    normalized_wire = Validation.validate_wire!(wire)
    Circuit.add_gate(circuit, GateOperation.new(gate_name, [normalized_wire], opts))
  end
end
