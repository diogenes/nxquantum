defmodule NxQuantum.Circuit.Error do
  @moduledoc """
  Typed domain exception for circuit/gate contract violations.
  """

  defexception [:code, :details, :message]

  @type t :: %__MODULE__{
          code: atom() | nil,
          details: map() | nil,
          message: String.t() | nil
        }

  @spec new(atom(), map()) :: t()
  def new(code, details \\ %{}) do
    %__MODULE__{
      code: code,
      details: details,
      message: "#{code}: #{inspect(details)}"
    }
  end
end
