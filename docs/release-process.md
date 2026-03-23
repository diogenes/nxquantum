# Release Process

## Goals

1. Keep release quality gates identical to CI quality gates.
2. Ensure package and docs artifacts are built deterministically before publish.
3. Keep release steps explicit and auditable.

## Pre-Release Checklist

1. `mix quality`
2. `mix dialyzer`
3. `mix test.provider_smoke` when optional live smoke lanes are enabled and credentials are available
4. `mix docs.build`
5. `mix hex.build`
6. Update roadmap/spec status and release notes summary.

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
