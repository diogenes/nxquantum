defmodule NxQuantum.Sampler.Options do
  @moduledoc false

  @type t :: %{
          shots: pos_integer(),
          seed: integer(),
          observable: atom(),
          wire: non_neg_integer(),
          runtime_profile: atom(),
          fallback_policy: atom(),
          runtime_available?: boolean()
        }

  @spec normalize(keyword()) :: {:ok, t()} | {:error, map()}
  def normalize(opts) do
    shots = Keyword.get(opts, :shots, 1_024)

    if not is_integer(shots) or shots <= 0 do
      {:error, %{code: :invalid_shots, shots: shots}}
    else
      {:ok,
       %{
         shots: shots,
         seed: Keyword.get(opts, :seed, 0),
         observable: Keyword.get(opts, :observable, :pauli_z),
         wire: Keyword.get(opts, :wire, 0),
         runtime_profile: Keyword.get(opts, :runtime_profile, :cpu_portable),
         fallback_policy: Keyword.get(opts, :fallback_policy, :strict),
         runtime_available?: Keyword.get(opts, :runtime_available?, true)
       }}
    end
  end

  @spec estimator_opts(t()) :: keyword()
  def estimator_opts(config) do
    [
      runtime_profile: config.runtime_profile,
      fallback_policy: config.fallback_policy,
      runtime_available?: config.runtime_available?,
      observable: config.observable,
      wire: config.wire
    ]
  end
end
