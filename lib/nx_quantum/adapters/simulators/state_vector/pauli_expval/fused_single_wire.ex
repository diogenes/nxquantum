defmodule NxQuantum.Adapters.Simulators.StateVector.PauliExpval.FusedSingleWire do
  @moduledoc false

  import Bitwise

  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.CompiledScaffoldCache
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.FusedCompiledKernel

  defguardp unit_scale(scale) when abs(scale - 1.0) < 1.0e-12
  defguardp neg_unit_scale(scale) when abs(scale + 1.0) < 1.0e-12
  @kernel_resolution_key :nxq_fused_kernel_resolution

  @type prepared_term :: map()

  @spec eligible?([prepared_term()], pos_integer()) :: boolean()
  def eligible?(terms, qubits) when is_list(terms) do
    qubits <= 12 and
      length(terms) >= 24 and
      Enum.all?(terms, fn
        %{kind: kind, wire: wire, scale: scale}
        when kind in [:pauli_x, :pauli_y, :pauli_z] and is_integer(wire) and is_number(scale) ->
          wire >= 0 and wire < qubits

        _ ->
          false
      end)
  end

  @spec expectations(Nx.Tensor.t(), [prepared_term()], pos_integer()) :: [Nx.Tensor.t()]
  def expectations(%Nx.Tensor{} = state, terms, qubits) do
    dim = 1 <<< qubits
    amps = state |> Nx.to_flat_list() |> List.to_tuple()

    z_by_wire = z_by_wire(amps, qubits, dim)
    {x_by_wire, y_by_wire} = xy_by_wire(amps, qubits, dim)

    tensor_by_term =
      Enum.reduce(terms, %{}, fn %{term_key: term_key, kind: kind, wire: wire, scale: scale}, acc ->
        Map.put_new_lazy(acc, term_key, fn ->
          base =
            case kind do
              :pauli_x -> Map.fetch!(x_by_wire, wire)
              :pauli_y -> Map.fetch!(y_by_wire, wire)
              :pauli_z -> Map.fetch!(z_by_wire, wire)
            end

          Nx.tensor(apply_scale(base, scale), type: {:f, 64})
        end)
      end)

    Enum.map(terms, fn %{term_key: term_key} ->
      Map.fetch!(tensor_by_term, term_key)
    end)
  end

  @spec expectations_for_runtime(Nx.Tensor.t(), [prepared_term()], pos_integer(), keyword()) ::
          [Nx.Tensor.t()]
  def expectations_for_runtime(%Nx.Tensor{} = state, terms, qubits, opts \\ []) do
    {kernel, reason} = resolve_kernel(opts, qubits, length(terms))
    Process.put(@kernel_resolution_key, kernel_resolution(opts, kernel, reason))

    case kernel do
      :compiled -> expectations_compiled(state, terms, qubits)
      :portable -> expectations(state, terms, qubits)
    end
  end

  @spec kernel_for_runtime(keyword()) :: :portable | :compiled
  def kernel_for_runtime(opts \\ []) do
    case runtime_profile_id(opts) do
      :cpu_compiled -> :compiled
      :nvidia_gpu_compiled -> :compiled
      _ -> :portable
    end
  end

  defp z_by_wire(amps, qubits, dim) do
    Enum.reduce(0..(qubits - 1), %{}, fn wire, acc ->
      mask = 1 <<< wire

      sum =
        Enum.reduce(0..(dim - 1), 0.0, fn idx, inner ->
          {re, im} = complex_components(elem(amps, idx))
          probability = re * re + im * im
          sign = if (idx &&& mask) == 0, do: 1.0, else: -1.0
          inner + sign * probability
        end)

      Map.put(acc, wire, sum)
    end)
  end

  defp xy_by_wire(amps, qubits, dim) do
    Enum.reduce(0..(qubits - 1), {%{}, %{}}, fn wire, {x_acc, y_acc} ->
      mask = 1 <<< wire

      {x_sum, y_sum} =
        Enum.reduce(0..(dim - 1), {0.0, 0.0}, fn idx, {x_inner, y_inner} ->
          if (idx &&& mask) == 0 do
            {ar, ai} = complex_components(elem(amps, idx))
            {br, bi} = complex_components(elem(amps, bxor(idx, mask)))
            overlap_re = ar * br + ai * bi
            overlap_im = ar * bi - ai * br
            {x_inner + 2.0 * overlap_re, y_inner + 2.0 * overlap_im}
          else
            {x_inner, y_inner}
          end
        end)

      {Map.put(x_acc, wire, x_sum), Map.put(y_acc, wire, y_sum)}
    end)
  end

  defp complex_components(%Complex{re: re, im: im}), do: {re * 1.0, im * 1.0}
  defp complex_components({re, im}) when is_number(re) and is_number(im), do: {re * 1.0, im * 1.0}
  defp complex_components(value) when is_number(value), do: {value * 1.0, 0.0}

  defp apply_scale(value, scale) when unit_scale(scale), do: value
  defp apply_scale(value, scale) when neg_unit_scale(scale), do: -value
  defp apply_scale(value, scale), do: value * scale

  defp expectations_compiled(%Nx.Tensor{} = state, terms, qubits) do
    wires = terms |> Enum.uniq_by(& &1.wire) |> Enum.map(& &1.wire)
    backend = backend_from_state(state)

    %{selector: selector, signs: signs, flipped_indices: flipped_indices, wire_index: wire_index} =
      CompiledScaffoldCache.fetch_batch(qubits, wires, backend: backend)

    {x_by_wire, y_by_wire, z_by_wire} =
      FusedCompiledKernel.evaluate(
        Nx.as_type(state, {:c, 64}),
        selector,
        signs,
        flipped_indices
      )

    wire_values =
      Enum.reduce(wires, %{}, fn wire, acc ->
        index = Map.fetch!(wire_index, wire)
        index_tensor = Nx.tensor(index, type: {:s, 64})

        Map.put(acc, wire, %{
          x: Nx.take(x_by_wire, index_tensor),
          y: Nx.take(y_by_wire, index_tensor),
          z: Nx.take(z_by_wire, index_tensor)
        })
      end)

    tensor_by_term =
      Enum.reduce(terms, %{}, fn %{term_key: term_key, kind: kind, wire: wire, scale: scale}, acc ->
        Map.put_new_lazy(acc, term_key, fn ->
          base =
            case kind do
              :pauli_x -> Map.fetch!(wire_values, wire).x
              :pauli_y -> Map.fetch!(wire_values, wire).y
              :pauli_z -> Map.fetch!(wire_values, wire).z
            end

          apply_scale_tensor(base, scale)
        end)
      end)

    Enum.map(terms, fn %{term_key: term_key} -> Map.fetch!(tensor_by_term, term_key) end)
  end

  defp apply_scale_tensor(value, scale) when unit_scale(scale), do: value
  defp apply_scale_tensor(value, scale) when neg_unit_scale(scale), do: Nx.negate(value)
  defp apply_scale_tensor(value, scale), do: Nx.multiply(value, scale)

  defp runtime_profile_id(opts) do
    case Keyword.get(opts, :runtime_profile) do
      %{id: id} when is_atom(id) -> id
      id when is_atom(id) -> id
      _ -> nil
    end
  end

  defp resolve_kernel(opts, qubits, term_count) do
    requested = kernel_for_runtime(opts)

    if requested == :compiled and portable_preferred_by_cost_model?(opts, qubits, term_count) do
      {:portable, :portable_preferred_batch_shape_cost_model}
    else
      {requested, :runtime_profile}
    end
  end

  defp portable_preferred_by_cost_model?(opts, qubits, term_count) do
    policy = Keyword.get(opts, :fused_compiled_kernel_policy, :auto)

    case policy do
      :force_compiled ->
        false

      :force_portable ->
        true

      _ ->
        qubits <= 12 and term_count >= 24
    end
  end

  defp kernel_resolution(opts, selected_kernel, reason) do
    requested_kernel = kernel_for_runtime(opts)

    %{
      requested_kernel: requested_kernel,
      selected_kernel: selected_kernel,
      reason: reason
    }
  end

  defp backend_from_state(%Nx.Tensor{} = state) do
    backend = state.data.__struct__

    if backend == exla_backend_module() do
      {backend, client: Map.get(state.data, :client, :host)}
    else
      backend
    end
  end

  defp exla_backend_module, do: :"Elixir.EXLA.Backend"
end
