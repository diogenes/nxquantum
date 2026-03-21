defmodule NxQuantum.Adapters.Simulators.StateVector.Operations do
  @moduledoc false

  defmodule SingleQubit do
    @moduledoc false
    @enforce_keys [:wire, :gate_matrix, :gate_coefficients]
    defstruct [:wire, :gate_matrix, :gate_coefficients]
  end

  defmodule Cnot do
    @moduledoc false
    @enforce_keys [:permutation]
    defstruct [:permutation]
  end

  defmodule Dense do
    @moduledoc false
    @enforce_keys [:matrix]
    defstruct [:matrix]
  end
end
