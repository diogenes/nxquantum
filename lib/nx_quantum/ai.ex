defmodule NxQuantum.AI do
  @moduledoc """
  Public facade for typed AI tool contracts.
  """

  alias NxQuantum.AI.Request
  alias NxQuantum.AI.ToolRunner

  @spec build_request(map() | keyword()) :: {:ok, Request.t()} | {:error, map()}
  def build_request(attrs), do: Request.new(attrs)

  @spec run_tool(map() | keyword(), keyword()) :: {:ok, NxQuantum.AI.Result.t()} | {:error, map()}
  def run_tool(attrs, opts \\ []) do
    with {:ok, request} <- build_request(attrs) do
      ToolRunner.run(request, opts)
    end
  end
end
