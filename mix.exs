defmodule NxQuantum.MixProject do
  use Mix.Project

  @version "0.7.0"
  @source_url "https://github.com/diogenes/nxquantum"

  def project do
    [
      app: :nx_quantum,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      test_ignore_filters: test_ignore_filters(),
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
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40", only: [:dev, :test], runtime: false},
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
      "test.provider_smoke": :test,
      "test.release_evidence": :test,
      "features.sync_glue": :test,
      "test.acceptance": :test,
      "bench.batch_obs_guard": :test,
      ci: :test,
      "docs.build": :dev,
      credo: :test,
      dialyzer: :dev
    ]
  end

  defp dialyzer do
    [
      plt_add_apps: [:ex_unit, :mix],
      flags: [:error_handling, :unmatched_returns]
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
        "CHANGELOG.md",
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
        "docs/python-comparison-workflows.md",
        "docs/migration-python-playbook.md",
        "docs/decision-matrix.md",
        "docs/livebook-tutorials.md",
        "docs/python-alternatives-benchmark-2026-03-21.md",
        "docs/python-alternatives-benchmark-2026-03-23-rerun.md",
        "docs/observability.md",
        "docs/observability-dashboards.md",
        "docs/standalone-integration-profiles.md",
        "docs/v0.5-feature-spec.md",
        "docs/v0.6-feature-spec.md",
        "docs/v0.6-acceptance-criteria.md",
        "docs/v0.6-feature-to-step-mapping.md",
        "docs/v0.7-feature-spec.md",
        "docs/v0.7-acceptance-criteria.md",
        "docs/v0.7-feature-to-step-mapping.md",
        "docs/v0.8-compiler-implementation-plan.md",
        "docs/v0.8-compiler-agent-prompts.md",
        "docs/v1.0-quantum-ai-tool-contracts.md",
        "docs/v1.0-hybrid-quantum-ai-benchmark.md",
        "docs/v1.0-hybrid-quantum-ai-integration-guide.md",
        "docs/quantum-llm-vision.md",
        "docs/v0.5-provider-implementation-plan.md",
        "docs/v0.5-acceptance-criteria.md",
        "docs/v0.5-migration-packs.md",
        "docs/v0.5-benchmark-matrix.md",
        "docs/v0.5-provider-support-tiers.md",
        "docs/case-study-beam-integration.md",
        "docs/axon-integration.md",
        "docs/model-recipes.md",
        "docs/api-stability.md",
        "docs/release-process.md",
        "docs/architecture.md",
        "docs/testing-strategy.md",
        "docs/roadmap.md",
        "docs/adr/0001-hexagonal-ddd-foundation.md",
        "docs/adr/0007-migration-assurance-toolkit.md",
        "docs/adr/0011-ai-tool-transport-sync-async-contract.md",
        "AGENTS.md",
        "SKILLS.md"
      ]
    ]
  end

  defp test_ignore_filters do
    [
      ~r{^test/features/.*\.ex$},
      ~r{^test/support/.*\.ex$}
    ]
  end

  defp description do
    "Pure-Elixir quantum circuit simulation and quantum machine learning primitives powered by Nx."
  end

  defp package do
    [
      name: "nx_quantum",
      files: ["lib", "mix.exs", "README.md", "CHANGELOG.md", "LICENSE"],
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
      "test.provider_smoke": [
        "test test/nx_quantum/providers_capabilities_test.exs test/nx_quantum/provider_adapters_test.exs test/nx_quantum/provider_bridge_test.exs test/nx_quantum/provider_azure_adapter_test.exs test/nx_quantum/observability_test.exs",
        "test test/features/features_test.exs"
      ],
      "test.release_evidence": [
        "test test/nx_quantum/provider_contract_serialization_test.exs test/nx_quantum/observability_test.exs test/nx_quantum/release_evidence_contract_test.exs"
      ],
      "features.sync_glue": ["cmd ./scripts/generate_cucumber_glue.sh"],
      "test.acceptance": ["test test/features/features_test.exs"],
      "bench.batch_obs_guard": ["run bench/batch_obs_regression_guard.exs"],
      "docs.build": ["docs"],
      ci: ["quality", "dialyzer", "docs.build"]
    ]
  end
end
