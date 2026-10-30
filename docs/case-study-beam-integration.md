# Pattern: Embedding NxQuantum in a Supervised BEAM Service

This page is an illustrative pattern, not a user report. No external deployment is documented yet (README "What Is Still Planned"). It reports no performance figures.

## The Pattern

1. Run NxQuantum under your own supervision tree. The library defines no application callback and starts no processes of its own (`mix.exs` has no `mod:`), so supervision, restarts, and concurrency limits are yours. For example, call `Estimator.run/2` or `Sampler.run/2` from a `GenServer` or `Task.Supervisor` child.
2. Pass the seed and runtime profile explicitly. Fixed inputs, `seed:`, and `runtime_profile:` give the same outputs in simulator and fixture lanes, so a restarted worker repeats its result (`docs/getting-started.md`, "What Deterministic Means Here").
3. Persist the envelopes. Provider jobs, results, and errors serialize to versioned `v1` envelopes (`NxQuantum.ProviderBridge.Serialization`), and 0.12.0 (unreleased) adds decoding stored envelopes so a restarted service can resume a job (`from_external_map/1`, CHANGELOG `[Unreleased]`).

## Check It Yourself

- Supervised-service Livebook: `examples/livebook/supervised_service.livemd` (expected with H1.5 PR-2; not in the tree yet).
- Numerics held across the Nx and OTP upgrade on one host: `bench/results/2026-10-26-h1.6/SUMMARY.md`.
- Envelope snapshots: `test/nx_quantum/contracts/envelope_snapshot_test.exs`.

## Limits

1. No performance figures. The former throughput numbers on this page came from `NxQuantum.Performance`, which returns modeled latency and throughput from a formula, not measurements (KG-24 in `docs/roadmap.md`), so they were removed.
2. Live provider and QPU runs are probabilistic. Determinism applies to simulator and fixture lanes only.
3. Provider breadth is narrower than Python-first ecosystems (`docs/product-positioning.md`).
