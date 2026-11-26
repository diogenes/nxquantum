defmodule NxQuantum.Interop.OpenQASM3 do
  @moduledoc """
  Pure-Elixir OpenQASM 3 export for `NxQuantum.Circuit` (experimental).

  The emitted subset is the `stdgates.inc` gates that NxQuantum supports
  (`h`, `x`, `y`, `z`, `rx`, `ry`, `rz`, `cx`, `swap`), scalar angles printed
  as float literals, and an optional final measurement of every qubit.
  Anything outside that subset returns a typed error that names the
  construct. Nothing is dropped silently.

  Output is a pure function of the circuit: the same circuit always yields
  byte-identical text.
  """

  alias NxQuantum.Circuit
  alias NxQuantum.GateOperation

  @single_qubit_gates %{h: "h", x: "x", y: "y", z: "z"}
  @rotation_gates [:rx, :ry, :rz]
  @two_qubit_gates %{cnot: "cx", swap: "swap"}

  @spec to_qasm(Circuit.t(), keyword()) :: {:ok, String.t()} | {:error, map()}
  def to_qasm(%Circuit{} = circuit, opts \\ []) do
    measure? = Keyword.get(opts, :measure, false)

    with :ok <- check_measurement(circuit),
         {:ok, gate_lines} <- gate_lines(circuit.operations) do
      qubits = circuit.qubits

      lines =
        ["OPENQASM 3.0;", ~s(include "stdgates.inc";), "qubit[#{qubits}] q;"] ++
          bit_declaration(measure?, qubits) ++
          gate_lines ++
          measurement_line(measure?)

      {:ok, Enum.join(lines, "\n") <> "\n"}
    end
  end

  defp check_measurement(%Circuit{measurement: nil}), do: :ok

  defp check_measurement(%Circuit{measurement: %{observable: observable, wire: wire}}) do
    {:error,
     %{
       code: :unsupported_qasm_construct,
       construct: :observable_measurement,
       observable: observable,
       wire: wire
     }}
  end

  defp bit_declaration(true, qubits), do: ["bit[#{qubits}] c;"]
  defp bit_declaration(false, _qubits), do: []

  defp measurement_line(true), do: ["c = measure q;"]
  defp measurement_line(false), do: []

  defp gate_lines(operations) do
    operations
    |> Enum.with_index()
    |> Enum.reduce_while({:ok, []}, fn {operation, index}, {:ok, acc} ->
      case gate_line(operation, index) do
        {:ok, line} -> {:cont, {:ok, [line | acc]}}
        {:error, _} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, reversed} -> {:ok, Enum.reverse(reversed)}
      {:error, _} = error -> error
    end
  end

  defp gate_line(%GateOperation{name: name, wires: [wire], params: params}, _index)
       when is_map_key(@single_qubit_gates, name) and map_size(params) == 0 do
    {:ok, "#{@single_qubit_gates[name]} q[#{wire}];"}
  end

  defp gate_line(%GateOperation{name: name, wires: [wire], params: params}, index) when name in @rotation_gates do
    case angle(name, params, index) do
      {:ok, literal} -> {:ok, "#{name}(#{literal}) q[#{wire}];"}
      {:error, _} = error -> error
    end
  end

  defp gate_line(%GateOperation{name: name, wires: [a, b], params: params}, _index)
       when is_map_key(@two_qubit_gates, name) and map_size(params) == 0 do
    {:ok, "#{@two_qubit_gates[name]} q[#{a}], q[#{b}];"}
  end

  defp gate_line(%GateOperation{name: name, wires: wires, params: params}, index) do
    unsupported(:gate, %{gate: name, wires: wires, params: params, operation_index: index})
  end

  defp angle(name, params, index) do
    case Map.keys(params) -- [:theta] do
      [] ->
        theta_literal(name, params, index)

      [parameter | _] ->
        unsupported(:unsupported_parameter, %{
          gate: name,
          parameter: parameter,
          operation_index: index
        })
    end
  end

  defp theta_literal(name, %{theta: %Nx.Tensor{} = tensor}, index) do
    if Nx.shape(tensor) == {} do
      tensor |> Nx.to_number() |> float_literal(name, index)
    else
      unsupported(:non_scalar_parameter, %{
        gate: name,
        parameter: :theta,
        shape: Nx.shape(tensor),
        operation_index: index
      })
    end
  end

  defp theta_literal(name, %{theta: value}, index) when is_number(value) do
    float_literal(value, name, index)
  end

  defp theta_literal(name, params, index) do
    unsupported(:unbound_parameter, %{
      gate: name,
      parameter: :theta,
      value: Map.get(params, :theta),
      operation_index: index
    })
  end

  defp float_literal(value, _name, _index) when is_number(value) do
    {:ok, Float.to_string(value * 1.0)}
  end

  defp float_literal(value, name, index) when is_atom(value) do
    unsupported(:non_finite_parameter, %{
      gate: name,
      parameter: :theta,
      value: value,
      operation_index: index
    })
  end

  defp float_literal(value, name, index) do
    unsupported(:non_real_parameter, %{
      gate: name,
      parameter: :theta,
      value: value,
      operation_index: index
    })
  end

  defp unsupported(construct, details) do
    {:error, Map.merge(%{code: :unsupported_qasm_construct, construct: construct}, details)}
  end
end
