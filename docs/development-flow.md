# Development Flow

## 1) Environment Setup

`mix` is the primary developer interface.

`mise` is used to pin and install Erlang/Elixir versions.

```bash
mise trust
mise install
mix setup
```

This installs the pinned Erlang/Elixir versions from `mise.toml`.

## 2) Daily Development Loop

```bash
mix test.unit
mix test.property
mix quality
```

When implementing scenario-level behavior:

```bash
mix test.features
```

## 3) Task Catalog

- `mix setup`
- `mix test`
- `mix test.unit`
- `mix test.property`
- `mix test.arch`
- `mix test.features`
- `mix test.provider_smoke`
- `mix test.acceptance` (compatibility alias to `mix test.features`)
- `mix quality`
- `mix dialyzer`
- `mix docs.build`
- `mix ci`

If your shell session is not activated for `mise`, you can force toolchain usage with:

```bash
mise exec -- mix ci
```

## 4) Behavior-First Contribution Path

1. Write/update a scenario in `features/*.feature`.
2. Implement/update steps in `test/features/steps/*_steps.ex`.
3. Map the scenario to a bounded context in `docs/bounded-context-map.md`.
4. Add unit/property tests for invariants.
5. Implement in domain/application layers first.
6. Wire adapters behind ports.
7. Run `mix ci` before opening PR.

Shared test utilities live under `test/support/test_support/` with `NxQuantum.TestSupport.*` modules.

## 5) Tooling Conventions

- Formatting: `mix format` (Styler plugin configured in `.formatter.exs`).
- Linting: `mix credo --strict`.
- Type checking: `mix dialyzer`.
- Performance baseline: `benchee` scripts under `bench/` (`bench/milestone_b.exs` currently).

## 5.1) Topology Routing Contribution Pattern (v0.3 Step 1)

When changing `NxQuantum.Transpiler` routing behavior:

1. Update `features/topology_transpilation.feature` first.
2. Mirror scenario intent in `test/features/steps/topology_transpilation_steps.ex`.
3. Add/adjust unit tests for:
   - shortest-path route selection,
   - equal-path tie-break determinism,
   - strict-mode typed errors,
   - transpilation report contract fields.
4. Implement with deterministic graph traversal and explicit tie-break.
5. Validate semantic preservation in expectation tests within tolerance.

## 6) Backend Capability Toggles (Local/CI)

Backend deps are intentionally toggleable to keep CI and onboarding predictable.

- `NXQ_ENABLE_EXLA=1|0` (default: `1`)
- `NXQ_ENABLE_TORCHX=1|0` (default: `0`)

Examples:

```bash
# Core portable lane (no EXLA/Torchx)
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0 mix test

# EXLA lane
NXQ_ENABLE_EXLA=1 NXQ_ENABLE_TORCHX=0 mix test

# Torchx lane (optional; requires native LibTorch toolchain)
NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=1 mix test
```

Runtime capability auto-detection can also be forced for smoke tests:

- `NXQ_PROFILE_CPU_COMPILED_AVAILABLE=1|0`
- `NXQ_PROFILE_NVIDIA_GPU_COMPILED_AVAILABLE=1|0`
- `NXQ_PROFILE_TORCH_INTEROP_RUNTIME_AVAILABLE=1|0`

## 7) VSCode Cucumber Integration

To keep Cucumber extension step discovery aligned with Elixir step modules:

1. Run `./scripts/generate_cucumber_glue.sh` after editing feature steps.
   or `mix features.sync_glue`.
2. Ensure `.vscode/settings.json` points:
   - `cucumber.features` to `features/**/*.feature`
   - `cucumber.glue` to `.vscode/cucumber-glue/**/*.js` and `test/features/steps/**/*.ex`

## 8) Observability Contribution Path (v0.5+)

When adding provider or workflow instrumentation:

1. Read `docs/observability.md` and `docs/adr/0006-opentelemetry-observability-standard.md` first.
2. Add/update observability scenarios in `features/provider_observability.feature`.
3. Add/update step mappings under `test/features/steps/provider_observability_steps.ex`.
4. Add schema tests for span names/attributes, metric contracts, and log redaction behavior.
5. Validate profile behavior (`high_level`, `granular`, `forensics`) with deterministic fixtures.

## 9) Provider Release-Hardening Path (v0.5 Milestone K)

When preparing provider release evidence:

1. Update migration assets in `docs/v0.5-migration-packs.md`.
2. Run and record benchmark evidence via `bench/milestone_k.exs`.
3. Update support tiers and known limits in `docs/v0.5-provider-support-tiers.md`.
4. Validate observability dashboards against `docs/observability-dashboards.md`.
5. Run `mix test.provider_smoke` before final release checklist sign-off.

## 10) Parallel Batch Execution Guidelines

`NxQuantum.Estimator.batched_expectation/3` and `NxQuantum.Sampler.batched_run/3` support optional parallel mode:

1. Enable with `parallel: true`.
2. Bound worker count with `max_concurrency: System.schedulers_online()` (or lower).
3. Keep deterministic reproducibility by using fixed `seed` values in sampler workflows.
4. Use sequential mode (`parallel: false`) for very small batches where task overhead may dominate.
