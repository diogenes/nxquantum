# Release Process

## Goals

1. Keep release quality gates identical to CI quality gates.
2. Ensure package and docs artifacts are built deterministically before publish.
3. Keep release steps explicit and auditable.

## Versioning Policy

1. `v1.0` is deferred until explicit production-grade adoption evidence is documented.
2. Continue additive release cadence on `0.x` (`0.9.1`, `0.10.0`, `0.11.0`, ...) while preserving stable public contracts.
3. A major-version bump requires an explicit release note section summarizing:
   - production workload adoption evidence,
   - operational reliability evidence,
   - reproducible benchmark/rollout evidence.

## Pre-Release Checklist

1. `mix quality`
2. `mix dialyzer`
3. `mix test.provider_smoke` when optional live smoke lanes are enabled and credentials are available
4. `mix docs.build`
5. `mix hex.build`
6. `mix test.release_evidence`
7. Update roadmap/spec status and release notes summary.

### Optional Live-Smoke Provider Gates

For credentialed provider readiness checks, enable one of:

1. global gate: `NXQ_PROVIDER_LIVE_SMOKE=1`
2. provider-specific gates:
   - `NXQ_PROVIDER_LIVE_SMOKE_IBM_RUNTIME=1`
   - `NXQ_PROVIDER_LIVE_SMOKE_AWS_BRAKET=1`
   - `NXQ_PROVIDER_LIVE_SMOKE_AZURE_QUANTUM=1`
   - `NXQ_PROVIDER_LIVE_SMOKE_GOOGLE_QUANTUM_AI=1`

Google-specific readiness config (`provider_config`) must include:

1. `auth_token`
2. `project_id`
3. `location`
4. `processor_id`

## CI Release Automation

The repository includes:

1. `.github/workflows/ci.yml` for matrix quality/testing lanes.
2. `.github/workflows/release.yml` for release dry-run on tags/manual dispatch.

`release.yml` performs:

1. dependency install and compile,
2. `mix ci`,
3. `mix hex.build`,
4. `mix docs.build`,
5. artifact upload for package tarball and generated docs.

## Publishing

Use the repository publishing flow:

1. `mix hex.publish`
2. `mix hex.publish docs`

Dry-run before publish:

1. `mix hex.publish --dry-run`

## v0.5 Provider Evidence Bundle

Include these references in the release PR or release note:

1. `docs/v0.5-migration-packs.md`
2. `docs/v0.5-benchmark-matrix.md`
3. `docs/v0.5-provider-support-tiers.md`
4. `docs/observability.md`
5. `docs/observability-dashboards.md`

## v0.6 Docs and Evidence Bundle

Include these references when releasing v0.6 docs/status updates:

1. `docs/v0.6-feature-spec.md`
2. `docs/v0.6-acceptance-criteria.md`
3. `docs/v0.6-feature-to-step-mapping.md`
4. `docs/roadmap.md`
5. `docs/testing-strategy.md`

## v0.7 Contract and Schema Evidence Bundle

Include these references when releasing v0.7 standalone + integration profile work:

1. `docs/v0.7-feature-spec.md`
2. `docs/v0.7-acceptance-criteria.md`
3. `docs/v0.7-feature-to-step-mapping.md`
4. `docs/standalone-integration-profiles.md`
5. `test/nx_quantum/provider_contract_serialization_test.exs`
6. `test/nx_quantum/observability_test.exs`
7. `test/nx_quantum/release_evidence_contract_test.exs`
