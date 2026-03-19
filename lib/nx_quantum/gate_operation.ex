defmodule NxQuantum.GateOperation do
  @moduledoc """
  Immutable value object describing a quantum gate application.
  """

  alias NxQuantum.Circuit.Validation

  @enforce_keys [:name, :wires, :params]
  defstruct [:name, :wires, :params]

  @type wire :: non_neg_integer()
  @type t :: %__MODULE__{
          name: atom(),
          wires: [wire()],
          params: map()
        }

  @spec new(atom(), [wire()], keyword() | map()) :: t()
  def new(name, wires, params \\ []) when is_atom(name) and is_list(wires) do
    normalized_params = Validation.normalize_params!(params)
    normalized_wires = Enum.map(wires, &Validation.validate_wire!/1)

    %__MODULE__{
      name: name,
      wires: normalized_wires,
      params: normalized_params
    }
  end
end
