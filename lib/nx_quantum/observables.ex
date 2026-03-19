defmodule NxQuantum.Observables do
  @moduledoc """
  Domain utilities for supported observables.
  """

  @type observable :: :pauli_x | :pauli_y | :pauli_z

  @supported ~w(pauli_x pauli_y pauli_z)a

  @spec supported() :: [observable()]
  def supported, do: @supported

  @spec normalize(observable()) :: observable()
  def normalize(observable) when observable in @supported, do: observable
end
