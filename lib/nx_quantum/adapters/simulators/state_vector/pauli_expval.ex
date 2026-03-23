defmodule NxQuantum.Adapters.Simulators.StateVector.PauliExpval do
  @moduledoc false

  import Bitwise

  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.ExecutionStrategy
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.ExpectationPlan
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.FusedSingleWire
  alias NxQuantum.Adapters.Simulators.StateVector.PauliExpval.SmallPlanCache
  alias NxQuantum.Adapters.Simulators.StateVector.State

  @type coefficient :: {number(), number()}
  @type pauli_term :: %{
          x_mask: non_neg_integer(),
          z_mask: non_neg_integer(),
          coeff: coefficient()
        }
  @type prepared_term :: map()
  @type expectation_plan :: ExpectationPlan.t()

  @spec term_for_observable(atom(), non_neg_integer()) :: pauli_term() | nil
  def term_for_observable(:pauli_x, wire), do: %{x_mask: 1 <<< wire, z_mask: 0, coeff: {1.0, 0.0}}
  def term_for_observable(:pauli_y, wire), do: %{x_mask: 1 <<< wire, z_mask: 1 <<< wire, coeff: {0.0, 1.0}}
  def term_for_observable(:pauli_z, wire), do: %{x_mask: 0, z_mask: 1 <<< wire, coeff: {1.0, 0.0}}
  def term_for_observable(_observable, _wire), do: nil

  @spec expectation(Nx.Tensor.t(), pauli_term(), pos_integer()) :: Nx.Tensor.t()
  def expectation(%Nx.Tensor{} = state, term, qubits) do
    plan = ExpectationPlan.single_term(term, qubits)
    expectation_with_prepared_term(state, hd(plan.terms))
  end

  @spec expectations(Nx.Tensor.t(), [pauli_term()], pos_integer(), keyword()) :: [Nx.Tensor.t()]
  def expectations(_state, [], _qubits, _opts), do: []

  def expectations(%Nx.Tensor{} = state, terms, qubits, opts) do
    plan = plan(terms, qubits, opts)
    expectations_with_plan(state, plan)
  end

  @spec plan([pauli_term()], pos_integer(), keyword()) :: expectation_plan()
  def plan(terms, qubits, opts \\ []) when is_list(terms) do
    strategy = ExecutionStrategy.select(length(terms), opts)
    ExpectationPlan.new(terms, qubits, strategy)
  end

  @spec expectations_with_plan(Nx.Tensor.t(), expectation_plan()) :: [Nx.Tensor.t()]
  def expectations_with_plan(_state, %ExpectationPlan{terms: []}), do: []

  def expectations_with_plan(%Nx.Tensor{} = state, %ExpectationPlan{} = plan) do
    case plan.strategy.mode do
      :parallel ->
        plan.terms
        |> unique_terms()
        |> chunk_for_parallel(plan.strategy.chunk_size)
        |> Task.async_stream(
          fn chunk ->
            Enum.map(chunk, &expectation_with_prepared_term(state, &1))
          end,
          max_concurrency: plan.strategy.max_concurrency,
          ordered: true,
          timeout: :infinity
        )
        |> Enum.flat_map(fn
          {:ok, values} -> values
          {:exit, reason} -> raise "parallel observable evaluation failed: #{inspect(reason)}"
        end)
        |> map_values_to_plan_order(plan.terms)

      :scalar ->
        if FusedSingleWire.eligible?(plan.terms, plan.qubits) do
          FusedSingleWire.expectations(state, plan.terms, plan.qubits)
        else
          evaluate_scalar_with_memo(state, plan)
        end
    end
  end

  @spec expectations_with_reuse_cache(Nx.Tensor.t(), expectation_plan()) :: [Nx.Tensor.t()]
  def expectations_with_reuse_cache(%Nx.Tensor{} = state, %ExpectationPlan{} = plan) do
    if cache_eligible?(plan) do
      cached_scalar_expectations(state, plan)
    else
      expectations_with_plan(state, plan)
    end
  end

  defp cache_eligible?(%ExpectationPlan{} = plan) do
    length(plan.terms) <= 4 and
      Enum.all?(plan.terms, fn
        %{kind: kind} when kind in [:pauli_x, :pauli_y, :pauli_z] -> true
        _ -> false
      end)
  end

  defp cached_scalar_expectations(%Nx.Tensor{} = state, %ExpectationPlan{} = plan) do
    key =
      {:pauli_expval, :small_scalar_cache, plan.qubits, term_keys(plan.terms), state_hash(state)}

    SmallPlanCache.fetch(key, fn ->
      evaluate_scalar_with_memo(state, plan)
    end)
  end

  defp term_keys(terms) do
    terms
    |> Enum.map(& &1.term_key)
    |> :erlang.phash2()
  end

  defp state_hash(%Nx.Tensor{} = state) do
    {Nx.type(state), :erlang.phash2(Nx.to_binary(state))}
  end

  @spec expectation_with_term_plan(Nx.Tensor.t(), prepared_term()) :: Nx.Tensor.t()
  def expectation_with_term_plan(%Nx.Tensor{} = state, prepared_term) when is_map(prepared_term) do
    expectation_with_prepared_term(state, prepared_term)
  end

  defp expectation_with_prepared_term(state, %{kind: :pauli_x, wire: wire, scale: scale}) do
    value = State.expectation_pauli_x(state, wire, qubits_from_state(state))
    apply_scale(value, scale)
  end

  defp expectation_with_prepared_term(state, %{kind: :pauli_y, wire: wire, scale: scale}) do
    value = State.expectation_pauli_y(state, wire, qubits_from_state(state))
    apply_scale(value, scale)
  end

  defp expectation_with_prepared_term(state, %{kind: :pauli_z, wire: wire, scale: scale}) do
    value = State.expectation_pauli_z(state, wire, qubits_from_state(state))
    apply_scale(value, scale)
  end

  defp expectation_with_prepared_term(state, %{kind: :generic} = prepared_term) do
    flipped = Nx.take(state, prepared_term.permutation)
    signed = apply_signs(flipped, prepared_term.signs)
    phased = apply_phase(signed, prepared_term.coeff_tensor)
    bra = Nx.conjugate(Nx.as_type(state, {:c, 64}))
    ket = Nx.as_type(phased, {:c, 64})
    Nx.real(Nx.sum(Nx.multiply(bra, ket)))
  end

  defp apply_signs(state, nil), do: state
  defp apply_signs(state, signs), do: Nx.multiply(state, signs)

  defp apply_phase(state, nil), do: state
  defp apply_phase(state, coeff_tensor), do: Nx.multiply(state, coeff_tensor)

  defp chunk_for_parallel(terms, chunk_size) do
    terms
    |> Enum.chunk_every(max(1, chunk_size))
    |> Enum.reject(&(&1 == []))
  end

  defp evaluate_scalar_with_memo(state, %ExpectationPlan{} = plan) do
    memo = %{term_values: %{}, xy_values: %{}, z_probabilities: nil, qubits: plan.qubits}

    {values, _memo} =
      Enum.map_reduce(plan.terms, memo, fn term, acc ->
        case Map.fetch(acc.term_values, term.term_key) do
          {:ok, cached} ->
            {cached, acc}

          :error ->
            {value, next_acc} = evaluate_term_with_memo(state, term, acc)
            updated_cache = Map.put(next_acc.term_values, term.term_key, value)
            {value, %{next_acc | term_values: updated_cache}}
        end
      end)

    values
  end

  defp evaluate_term_with_memo(state, %{kind: :pauli_x, wire: wire, scale: scale}, memo) do
    {{x_value, _y_value}, next_memo} = fetch_or_compute_xy(state, wire, memo)
    {apply_scale(x_value, scale), next_memo}
  end

  defp evaluate_term_with_memo(state, %{kind: :pauli_y, wire: wire, scale: scale}, memo) do
    {{_x_value, y_value}, next_memo} = fetch_or_compute_xy(state, wire, memo)
    {apply_scale(y_value, scale), next_memo}
  end

  defp evaluate_term_with_memo(state, %{kind: :pauli_z, wire: wire, scale: scale}, memo) do
    {probabilities, next_memo} = fetch_or_compute_probabilities(state, memo)
    value = State.expectation_pauli_z_from_probabilities(probabilities, wire, memo.qubits)
    {apply_scale(value, scale), next_memo}
  end

  defp evaluate_term_with_memo(state, %{kind: :generic} = term, memo) do
    {expectation_with_prepared_term(state, term), memo}
  end

  defp fetch_or_compute_xy(state, wire, memo) do
    case Map.fetch(memo.xy_values, wire) do
      {:ok, pair} ->
        {pair, memo}

      :error ->
        pair = State.expectation_pauli_xy(state, wire, memo.qubits)
        {pair, %{memo | xy_values: Map.put(memo.xy_values, wire, pair)}}
    end
  end

  defp fetch_or_compute_probabilities(state, memo) do
    case memo.z_probabilities do
      %Nx.Tensor{} = probabilities ->
        {probabilities, memo}

      nil ->
        probabilities = State.probabilities(state)
        {probabilities, %{memo | z_probabilities: probabilities}}
    end
  end

  defp unique_terms(terms) do
    terms
    |> Enum.reduce({[], MapSet.new()}, fn term, {acc, seen} ->
      if MapSet.member?(seen, term.term_key) do
        {acc, seen}
      else
        {[term | acc], MapSet.put(seen, term.term_key)}
      end
    end)
    |> elem(0)
    |> Enum.reverse()
  end

  defp map_values_to_plan_order(unique_values, plan_terms) do
    unique_map =
      unique_values
      |> Enum.zip(unique_terms(plan_terms))
      |> Enum.reduce(%{}, fn {value, term}, acc ->
        Map.put(acc, term.term_key, value)
      end)

    Enum.map(plan_terms, fn term ->
      Map.fetch!(unique_map, term.term_key)
    end)
  end

  defp qubits_from_state(%Nx.Tensor{} = state) do
    state
    |> Nx.shape()
    |> elem(0)
    |> :math.log2()
    |> round()
  end

  defp apply_scale(value, scale) when is_number(scale) and abs(scale - 1.0) < 1.0e-12, do: value
  defp apply_scale(value, scale) when is_number(scale) and abs(scale + 1.0) < 1.0e-12, do: Nx.negate(value)
  defp apply_scale(value, scale), do: Nx.multiply(value, scale)
end
