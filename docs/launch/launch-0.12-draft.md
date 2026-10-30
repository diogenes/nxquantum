# NxQuantum 0.12 launch write-up (draft)

> **Status: DRAFT. Not for publication until the launch checklist is complete. The owner publishes.**
>
> Launch checklist (all items must be done before publishing):
>
> - [ ] 0.12.0 published on Hex and tagged.
> - [ ] Hex description (`mix.exs`) aligned to decision D1 (`docs/roadmap.md`).
> - [ ] Claims cleanup done in the 0.12.0 docs.
> - [ ] A Hex-based quick start is in the README and `docs/getting-started.md`.
> - [ ] Time to first result (TTFR) measured on the published 0.12.0.
> - [ ] Survey live (`docs/research/kano-survey-h1.5.md`).
> - [ ] A green CI run is linked in the evidence section.
> - [ ] FluxQ G2 contract test merged, if FluxQ is mentioned.
>
> Everything marked "0.12.0" below is in `[Unreleased]` in `CHANGELOG.md` until the release is on Hex.
> The claims table at the end is internal and is removed before publication.

Working title: **Same seed, same counts: reproducible quantum workloads on the BEAM with NxQuantum 0.12**

Alternatives:

1. NxQuantum 0.12: deterministic quantum circuit execution for Elixir and Nx 1.0
2. NxQuantum: quantum circuits inside your supervision tree, with seeded results and versioned envelopes

---

## What it is, and who it is for

NxQuantum is a quantum circuit library for Elixir and Nx. It runs a state-vector simulator inside your BEAM process and puts the focus on reproducibility: a fixed seed gives the same sampled counts, and job, result and error records have a versioned shape.

It is for two groups. One group is BEAM and Nx teams who want to embed quantum workloads in a supervised service. The other is researchers who need to rerun a result and get the same answer. It is not for you if your top need is provider breadth, compiler depth, or GPU-scale simulation.

## Try it in two minutes

Install from Hex (the default `Nx.BinaryBackend`, no EXLA):

```elixir
Mix.install([{:nx_quantum, "~> 0.12.0"}])

alias NxQuantum.{Circuit, Gates, Sampler}

circuit = [qubits: 1] |> Circuit.new() |> Gates.ry(0, theta: 1.1)

{:ok, result} = Sampler.run(circuit, shots: 1024, seed: 13, observable: :pauli_z, wire: 0)
result.counts
#=> %{"0" => 752, "1" => 272}
```

These counts are pinned in the test suite. The analytic probability of measuring 1 is (1 - cos 1.1) / 2 = 0.2732; the pinned run observed 0.2656. `Sampler.run` is an experimental API: it may change between minor releases.

We would like to hear whether you get the same counts. If you reply, tell us your OTP version, OS and CPU architecture. Our own check covers one host (below), so other hosts are exactly what we want to learn about.

## How we check it

We make three claims and point to the files behind each. Every one is scoped to what was run.

**Toolchain upgrades changed no tracked number.** Moving from Nx 0.11 to Nx 1.0, and from OTP 28 to OTP 29, changed none of the tracked numerics digest lines on the default backend. The digests cover seeded sampler counts, gradients, expectation values and compiler output, and each state was run twice. The scope is one host (Apple M4, macOS 26.6.2), `Nx.BinaryBackend` alone, recorded 2026-10-26. Evidence: `bench/results/2026-10-26-h1.6/SUMMARY.md`. We say "held from OTP 28 to 29 in our run", not more.

**Envelopes are guarded and resumable.** Job, result and error envelopes for the four core provider adapters (IBM Runtime, AWS Braket, Azure Quantum, Google Quantum AI), in the fixture lane, are compared byte for byte with stored snapshots, and a stored envelope can be decoded and resumed. The snapshot tree id was unchanged across the Nx 1.0 upgrade, and FluxQ's test suite passed against that state in a local check on 2026-10-26. Evidence: `test/nx_quantum/contracts/envelope_snapshot_test.exs`, `test/nx_quantum/contracts/envelope_decode_test.exs`, `test/fixtures/contracts/envelopes/`, `docs/api-stability.md`, `bench/results/2026-10-26-h1.6/fluxq-consumer-check.txt`.

**Compiler and transpiler passes are checked against an independent dense reference.** The compiler property suite uses 3 fixed seed sets with 12 random circuits each, up to 6 qubits. The tolerance is 1e-9 for exact rewrites and 1e-6 for single-qubit resynthesis. Routing equivalence and a gate-identity catalogue are checked the same way. The suites found 2 defects, both fixed with regression tests. Evidence: `test/property/compiler_semantic_equivalence_property_test.exs`, `test/property/gate_identity_property_test.exs`, `test/property/transpiler_routing_equivalence_property_test.exs`, `test/support/dense_reference.ex`, `CHANGELOG.md`.

CI status: <link a green CI run at publish time>.

## Contracts for hosts

For a host application, the useful part is the envelope contract. Job, result and error records carry a `v1` schema version. A shape or meaning change requires a version bump and a CHANGELOG entry. In 0.12.0, `Serialization.from_external_map/1` decodes stored `v1` envelopes and returns typed errors for unknown versions, types, states, codes and operations.

FluxQ, a separate project that is still in development, reads these envelopes unchanged and gates its releases on the snapshot files. It is not yet available to you.

Determinism here means the simulator and fixture lanes. Live provider runs are probabilistic, are gated by environment configuration, and are covered by typed lifecycle contracts, not by result guarantees.

## Limits and the ask

- The simulator uses single precision (`complex64`). Measured error against a float64 reference is at most 4.5e-7 over up to 6 qubits and depth 200.
- We make no performance claims in this post.
- The hybrid benchmark datasets in the repo are synthetic.
- Live provider lanes are env-gated.

What we would like from you: try the two-minute example and tell us what happened, fill in the short survey (<survey link>), read the roadmap (`docs/roadmap.md`, no promises attached), and tell us if you want to be a design partner.

## What we don't claim

- Speed or throughput of any kind, crossover points, or comparisons with other libraries. We publish no benchmark in this release.
- Figures in the BEAM case study. They are modeled, not measured (KG-24).
- That any team uses NxQuantum in production. We have no known dependents on Hex.
- Rerank quality, latency, compression or TurboQuant figures (KG-5, KG-11), or that the rerank and optimization tools are quantum computations (KG-12).
- OpenTelemetry export. The adapter named for it does not export (KG-13).
- That every envelope serializes. The guarantee covers the snapshot-covered shapes (KG-14).
- Calibration provenance (KG-15).
- Hardware results of any kind, or repeatable live results.
- Bit-identical numbers on EXLA or Torchx, on other CPU architectures, or as a guarantee across OTP majors. We observed it from OTP 28 to 29 on one host.
- Float64 precision (KG-10).
- Distributed execution.
- That we are the only quantum library for Elixir. `qx_sim` also exists.
- Anything in `[Unreleased]` before 0.12.0 is on Hex.

---

## Claims table (INTERNAL. Remove before publication.)

Every factual sentence of the draft above, with its in-repo evidence. Paths are relative to the repository root and were checked against origin/main (d271840).

| # | Claim | Evidence |
| --- | --- | --- |
| 1 | NxQuantum is a quantum circuit library for Elixir and Nx | `mix.exs` (deps `nx`, `description`); `README.md` |
| 2 | It runs a state-vector simulator inside the BEAM process | `lib/nx_quantum/adapters/simulators/state_vector/state.ex`; `docs/architecture.md` |
| 3 | A fixed seed gives the same sampled counts | `test/nx_quantum/sampler_test.exs` ("run/2 returns deterministic sampled results for fixed seed") |
| 4 | Job, result and error records have a versioned shape | `docs/api-stability.md` (Envelope Compatibility Policy); `test/fixtures/contracts/envelopes/` |
| 5 | Audience: BEAM/Nx teams embedding quantum workloads; researchers needing reproducibility | `docs/vision.md` §4 Audience (Primary, Secondary) |
| 6 | Not for users whose top need is provider breadth, compiler depth or GPU-scale simulation | `docs/vision.md` §4 (Not targeted); §10 item 4 |
| 7 | Install via `Mix.install([{:nx_quantum, "~> 0.12.0"}])` works on default `Nx.BinaryBackend`, no EXLA | `mix.exs` (EXLA optional, env-gated `NXQ_ENABLE_EXLA`); `CHANGELOG.md` Changed (env gating unchanged). Gate: TTFR on published 0.12.0 (checklist) |
| 8 | The example call returns `%{"0" => 752, "1" => 272}` | `test/nx_quantum/sampler_test.exs` ("Sampler.run counts are pinned for RY(1.1), seed 13, 1024 shots") |
| 9 | Analytic P(1) = (1 - cos 1.1)/2 = 0.2732; observed 0.2656 | same test, comment lines; 272/1024 = 0.265625 |
| 10 | `Sampler.run` is experimental | `docs/api-stability.md` (experimental tier, added by H1.5 PR-2; this claim waits for that PR) |
| 11 | Our own check covers one host | `bench/results/2026-10-26-h1.6/SUMMARY.md` header |
| 12 | Evidence 1: Nx 0.11 to 1.0 and OTP 28 to 29 changed no tracked digest line (default backend) | `bench/results/2026-10-26-h1.6/SUMMARY.md` (all lines "Identical y"; after-pr-b section) |
| 13 | Digests cover seeded sampler counts, gradients, expectation values, compiler output | same file: `sampler_run_ry_sha`, `grad_bits_sha`, `production_expval_bits_sha`, `compiler_optimize_ops_sha` |
| 14 | Each state was run twice | same file, header ("Two runs per state") |
| 15 | Scope: Apple M4, macOS 26.6.2, BinaryBackend only, 2026-10-26 | same file, header and States table; `CHANGELOG.md` (BinaryBackend-only note) |
| 16 | Evidence 2: four core providers' fixture-lane envelopes are byte-compared with snapshots | `test/nx_quantum/contracts/envelope_snapshot_test.exs`; 12 files in `test/fixtures/contracts/envelopes/` (aws_braket, azure_quantum, google_quantum_ai, ibm_runtime x job/result/error) |
| 17 | A stored envelope can be decoded and resumed | `test/nx_quantum/contracts/envelope_decode_test.exs`; `docs/api-stability.md` Envelope policy item 4-5 |
| 18 | Snapshot tree id unchanged across the Nx 1.0 upgrade | `bench/results/2026-10-26-h1.6/SUMMARY.md` ("Other artifacts", tree id 802aae3...) |
| 19 | FluxQ's tests passed against that state in a local check on 2026-10-26 | `bench/results/2026-10-26-h1.6/fluxq-consumer-check.txt` (GREEN, 0 failures, run_date_utc 2026-10-26) |
| 20 | Evidence 3: 3 fixed seed sets x 12 random circuits, up to 6 qubits | `test/property/compiler_semantic_equivalence_property_test.exs` (`@seed_sets`, `@circuits_per_seed 12`, `@max_qubits 6`) |
| 21 | Tolerance 1e-9 exact rewrites, 1e-6 resynthesis | same file (`@exact_tolerance`, `@resynthesis_tolerance`) |
| 22 | Routing equivalence and gate-identity catalogue are checked the same way (independent dense reference) | `test/property/transpiler_routing_equivalence_property_test.exs`; `test/property/gate_identity_property_test.exs`; `test/support/dense_reference.ex` |
| 23 | The suites found 2 defects, both fixed with regression tests | `docs/roadmap.md` H1.4 Evidence (defects 1 and 2); `CHANGELOG.md` Fixed |
| 24 | Envelope records carry a `v1` schema version; changes need a bump and CHANGELOG entry | `docs/api-stability.md` Envelope policy items 1-2 |
| 25 | `Serialization.from_external_map/1` decodes `v1` and returns typed errors for unknown versions, types, states, codes, operations; ships in 0.12.0 | `CHANGELOG.md` [Unreleased] Added; `docs/api-stability.md` item 4; `test/nx_quantum/contracts/envelope_decode_test.exs` |
| 26 | FluxQ is a separate project, still in development | `docs/api-stability.md` ("Known consumer: FluxQ (separate project)"); `docs/roadmap.md` line 7 (FluxQ is a separate project); development status per the H1.5 plan (FluxQ Phase 0); verify at publish |
| 27 | FluxQ reads envelopes unchanged and gates releases on snapshot files | `docs/api-stability.md` (G2 gate sentence) |
| 28 | FluxQ is not yet available | FluxQ pre-MVP per the H1.5 plan; no in-repo artifact. Verify at publish (checklist: FluxQ G2 merged) |
| 29 | Determinism covers simulator and fixture lanes; live runs are probabilistic, env-gated | `docs/provider-support-catalog.md` (fixture/live table, env-gated); `docs/testing-strategy.md` |
| 30 | Live lanes covered by typed lifecycle contracts | `docs/provider-support-catalog.md` (lifecycle column); `docs/playbooks/provider-contracts.md` |
| 31 | Simulator is single precision (`complex64`) | `docs/backend-support.md` "Numerical Precision"; `lib/nx_quantum/adapters/simulators/state_vector/state.ex` |
| 32 | Error at most 4.5e-7 vs float64 over up to 6 qubits, depth 200 | `CHANGELOG.md` Changed (precision floor); `bench/numerics_precision_floor.exs` |
| 33 | No performance claims | absence check: banned-phrase grep recorded in the PR hand-back |
| 34 | Hybrid benchmark datasets are synthetic | `docs/hybrid-quantum-ai-benchmark.md` line 7 and 39; `bench/datasets/rerank/*.manifest.json`; `test/nx_quantum/hybrid_quantum_ai_benchmark_guard_test.exs` |
| 35 | Live provider lanes are env-gated | `docs/provider-support-catalog.md` |
| 36 | A roadmap exists with no promises attached | `docs/roadmap.md` |
| 37 | Don't-claim: case-study figures are modeled | `docs/roadmap.md` KG-24 (added by H1.5 PR-1; not on origin/main until then); `lib/nx_quantum/performance.ex` (model) |
| 38 | Don't-claim: no known dependents on Hex | Hex package page fetched 2026-10-30 (0 dependents), recorded in `docs/research/kano-survey-h1.5.md` baselines |
| 39 | Don't-claim: rerank figures are placeholders (KG-5, KG-11); tools not quantum (KG-12) | `docs/roadmap.md` KG-5, KG-11, KG-12 |
| 40 | Don't-claim: OpenTelemetry adapter does not export (KG-13) | `docs/roadmap.md` KG-13 |
| 41 | Don't-claim: serialization raises on some struct values (KG-14) | `docs/roadmap.md` KG-14 |
| 42 | Don't-claim: calibration provenance not asserted (KG-15) | `docs/roadmap.md` KG-15 |
| 43 | Don't-claim: bit-identity scope is BinaryBackend, one host, OTP 28 to 29 | `CHANGELOG.md` Changed (bit-identity covers BinaryBackend only); SUMMARY.md header |
| 44 | Don't-claim: float64 (KG-10) | `docs/roadmap.md` KG-10; `docs/backend-support.md` |
| 45 | Don't-claim: distributed execution | `docs/vision.md` §10 item 3 (non-goal); §9 (announce only what is shipped and evidenced) |
| 46 | `qx_sim` also exists | Hex package page checked 2026-10-30 (1,768 all-time downloads), recorded in `docs/research/kano-survey-h1.5.md` |
| 47 | `[Unreleased]` items are not on Hex before 0.12.0 | `CHANGELOG.md` [Unreleased]; `mix.exs` `@version "0.11.0"` |
