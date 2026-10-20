# Provider Release Hardening Playbook

## Use When
Preparing provider-related release evidence, support-tier updates, and hardening checks.

## Required Reading
- `docs/release-process.md`
- `docs/provider-support-catalog.md`
- `docs/migration-packs.md`
- `docs/roadmap.md`

## Flow
1. Confirm release scope and targeted provider capabilities.
2. Refresh deterministic migration assets and compatibility notes.
3. Run provider hardening checks:
   - `mix test.provider_smoke`
   - `mix test.release_evidence`
   - enable credentialed live-smoke gates as needed (`NXQ_PROVIDER_LIVE_SMOKE` or provider-specific env keys including `NXQ_PROVIDER_LIVE_SMOKE_GOOGLE_QUANTUM_AI`)
4. Run reproducible benchmark scripts under `bench/` when performance claims changed.
5. Critic: verify contract changes are versioned and architecture ownership is explicit.
6. Verifier: run `mix ci`.
7. Update release notes and support-tier docs.

## Stop Conditions
- provider contract changes are undocumented
- support tiers and known limits drift from implementation
- release evidence is missing for changed behavior
