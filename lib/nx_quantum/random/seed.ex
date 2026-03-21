defmodule NxQuantum.Random.Seed do
  @moduledoc false

  @spec seed(integer(), atom()) :: :ok
  def seed(seed, namespace) when is_integer(seed) and is_atom(namespace) do
    a = rem(:erlang.phash2({seed, namespace, :a}), 30_000) + 1
    b = rem(:erlang.phash2({seed, namespace, :b}), 30_000) + 1
    c = rem(:erlang.phash2({seed, namespace, :c}), 30_000) + 1
    _ = :rand.seed(:exsplus, {a, b, c})
    :ok
  end
end
