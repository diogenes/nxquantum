defmodule NxQuantum.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/diogenes/nxquantum"

  def project do
    [
      app: :nx_quantum,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      docs: docs(),
      dialyzer: dialyzer(),
      description: description(),
      package: package()
    ]
  end

  def application do
    [
      extra_applications: [:logger]
    ]
  end

  def cli do
    [
      preferred_envs: preferred_cli_env()
    ]
  end

  defp deps do
    [
      {:nx, "~> 0.10"},
      {:axon, "~> 0.8", optional: true},
      {:stream_data, "~> 1.3", only: :test},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false},
      {:benchee, "~> 1.5", only: :dev},
      {:styler, "~> 1.11", only: [:dev, :test], runtime: false}
    ] ++ optional_backend_deps()
  end

  defp optional_backend_deps do
    []
    |> maybe_add_exla()
    |> maybe_add_torchx()
  end

  defp maybe_add_exla(deps) do
    if feature_enabled?("NXQ_ENABLE_EXLA", default: true) do
      [{:exla, "~> 0.10", optional: true} | deps]
    else
      deps
    end
  end

  defp maybe_add_torchx(deps) do
    if feature_enabled?("NXQ_ENABLE_TORCHX", default: false) do
      [{:torchx, "~> 0.10", optional: true} | deps]
    else
      deps
    end
  end

  defp feature_enabled?(env_key, opts) do
    default = Keyword.get(opts, :default, false)

    case System.get_env(env_key) do
      nil -> default
      "1" -> true
      "true" -> true
      "0" -> false
      "false" -> false
      _ -> default
    end
  end

  defp preferred_cli_env do
    [
      setup: :dev,
      quality: :test,
      "test.unit": :test,
      "test.property": :test,
      "test.arch": :test,
      "test.features": :test,
      "features.sync_glue": :test,
      "test.acceptance": :test,
      ci: :test,
      "docs.build": :dev,
      credo: :test,
      dialyzer: :dev
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      flags: [:error_handling, :race_conditions, :unmatched_returns]
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      source_url: @source_url,
      homepage_url: "https://hexdocs.pm/nx_quantum",
      extras: [
        "README.md",
        "CONTRIBUTING.md",
        "docs/development-flow.md",
        "docs/backend-support.md",
        "docs/bounded-context-map.md",
        "docs/v0.2-feature-spec.md",
        "docs/v0.2-improvement-plan.md",
        "docs/v0.3-feature-spec.md",
        "docs/v0.4-feature-spec.md",
        "docs/getting-started.md",
        "docs/product-positioning.md",
        "docs/axon-integration.md",
        "docs/model-recipes.md",
        "docs/api-stability.md",
        "docs/release-process.md",
        "docs/architecture.md",
        "docs/testing-strategy.md",
        "docs/roadmap.md",
        "docs/adr/0001-hexagonal-ddd-foundation.md",
        "AGENTS.md",
        "SKILLS.md"
      ]
    ]
  end

  defp description do
    "Pure-Elixir quantum circuit simulation and quantum machine learning primitives powered by Nx."
  end

  defp package do
    [
      name: "nx_quantum",
      files: ["lib", "mix.exs", "README.md", "LICENSE"],
      licenses: ["MIT"],
      links: %{
        "GitHub" => @source_url,
        "Docs" => "https://hexdocs.pm/nx_quantum"
      }
    ]
  end

  defp aliases do
    [
      setup: ["local.hex --force", "local.rebar --force", "deps.get"],
      quality: ["format --check-formatted", "credo --strict", "test.arch", "test"],
      "test.unit": ["test test/nx_quantum"],
      "test.property": ["test test/property"],
      "test.arch": ["test test/architecture"],
      "test.features": ["test test/features/features_test.exs"],
      "features.sync_glue": ["cmd ./scripts/generate_cucumber_glue.sh"],
      "test.acceptance": ["test test/features/features_test.exs"],
      "docs.build": ["docs"],
      ci: ["quality", "dialyzer", "docs.build"]
    ]
  end
end
