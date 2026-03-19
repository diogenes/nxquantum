defmodule NxQuantum.Sampler.ResultBuilder do
  @moduledoc false

  alias NxQuantum.Sampler.Result

  @spec build(map(), non_neg_integer(), non_neg_integer()) :: Result.t()
  def build(config, zero_count, one_count) do
    shots = config.shots

    %Result{
      probabilities: Nx.tensor([zero_count / shots, one_count / shots], type: {:f, 32}),
      counts: %{"0" => zero_count, "1" => one_count},
      metadata: %{
        mode: :sampler,
        runtime_profile: config.runtime_profile,
        shots: shots,
        seed: config.seed,
        observable: config.observable,
        wire: config.wire
      }
    }
  end
end
