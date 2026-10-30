# Product Positioning

Merged with the former `docs/decision-matrix.md` on 2026-10-30 (H1.5).

## 1) One Line

Deterministic quantum execution on BEAM for Elixir and Nx teams (decision D1, `docs/roadmap.md` Decision Log).

## 2) Who It Is For and Not For

For:

- BEAM/Nx teams embedding quantum workloads in services, who need seeded, reproducible results and typed contracts in the same runtime as their `Nx`/`Nx.Defn` code.
- Researchers who need reproducible runs: fixed seeds, experiment fingerprints, Livebooks.
- Teams building host applications or control planes on versioned job, result, and error envelopes.

Not for (today): teams whose top requirement is provider breadth, compiler depth, or large-scale GPU simulation (`docs/vision.md` §4).

## 3) Determinism Scope and Backend Scope

1. Deterministic means fixed inputs, seed, runtime profile/options, and toolchain on one host produce stable outputs in simulator and fixture lanes.
2. Live provider and QPU lanes are probabilistic. NxQuantum guarantees typed contracts, lifecycle semantics, and reproducible request metadata there, not identical measured outcomes.
3. Backend scope: repeat runs are bit-identical on the default `Nx.BinaryBackend`. EXLA and Torchx are checked within stated tolerances (`docs/backend-support.md`).
4. Job ids and fingerprints use OTP's term encoding, which OTP keeps stable only within a major release, so they can change across OTP majors.

## 4) What You Can Rely On

| Claim | Evidence | Date | Environment |
| --- | --- | --- | --- |
| Moving from Nx 0.11 to 1.0 and from OTP 28 to 29 changed none of the tracked numerics digest lines (seeded sampler counts, gradients, compiler output) | `bench/results/2026-10-26-h1.6/SUMMARY.md` (two runs per state) | 2026-10-26 | Apple M4, macOS 26.6.2, default `Nx.BinaryBackend`, one host |
| Job, result, and error envelopes for the 4 core providers (fixture lane) are guarded by byte snapshots and can be decoded and resumed; the fixture tree id was unchanged across the upgrade, and the FluxQ test suite passed against it (decode/resume is unreleased, 0.12.0) | `test/nx_quantum/contracts/envelope_snapshot_test.exs`, `test/nx_quantum/contracts/envelope_decode_test.exs`, `test/fixtures/contracts/envelopes/`, `docs/api-stability.md`, `bench/results/2026-10-26-h1.6/fluxq-consumer-check.txt` | 2026-10-26 | Elixir 1.19.5 / OTP 28.4.1 for the FluxQ check; digests also on Elixir 1.20.4 / OTP 29.1.2 |
| Compiler and transpiler passes are tested against an independent dense reference: 3 fixed seed sets of 12 random circuits each, up to 6 qubits, tolerance 1e-9 for exact rewrites and 1e-6 for resynthesis; the suite found 2 defects, both fixed (unreleased; see CHANGELOG `[Unreleased]`) | `test/property/compiler_semantic_equivalence_property_test.exs`, `test/property/gate_identity_property_test.exs`, `test/property/transpiler_routing_equivalence_property_test.exs`, `test/support/dense_reference.ex`, `docs/roadmap.md` H1.4 Evidence | 2026-10-25 | the test environment (not a timed benchmark); single-precision floor in `docs/backend-support.md` |

These are internal, environment-specific references, not official results. NxQuantum makes no speed claims (README Performance section).

## 5) Choosing NxQuantum vs Python-First

| Situation | Prefer NxQuantum | Prefer Python-first |
| --- | --- | --- |
| Team stack | Elixir/Nx/BEAM services | Python-heavy research and infrastructure |
| Determinism and typed contracts | High priority: seeded simulator/fixture workflows plus typed, versioned envelopes | Lower priority or handled elsewhere |
| Hardware-provider breadth needed today | The core set of 4 providers through one typed lifecycle (`docs/provider-support-catalog.md`) is enough | Immediate broad provider support required |
| Compiler depth | Basic compilation and topology-aware transpilation are enough | Advanced compiler optimization is a requirement |
| GPU-scale simulation | Circuits that fit single-machine state-vector simulation | Large-scale GPU simulation is a requirement |
| Integration model | Keep training and serving in the same BEAM runtime | Existing Python orchestration is strategic |
| Migration appetite | Moving one workflow at a time (`docs/migration-python-playbook.md`) | Continue optimizing the current Python stack |

## 6) Recommendation Pattern

1. Choose NxQuantum when integration simplicity and deterministic contracts in BEAM matter most.
2. Choose Python-first when provider breadth, compiler depth, or GPU-scale simulation is the top requirement.
3. Use both when you need both in the short term.

## 7) Where Hybrid Quantum-AI Fits

Hybrid quantum-AI (AI tool contracts with rerank and optimization handlers) is an application of the properties above, not the lead.

- The in-repo rerank datasets are synthetic and carry `provenance: synthetic` (KG-5). The real-data lane is parked (`docs/vision.md` §11).
- The hybrid benchmark scripts emit fixed placeholder figures, not measurements (KG-11).
- The bundled rerank and optimization handlers compute classically while reporting `execution.mode: :quantum` (KG-12).

No real-data quality claim is made.

## 8) Known Limits and Non-Goals

1. Live hardware results are probabilistic, and live lanes are env-gated (`docs/provider-support-catalog.md`).
2. The simulator is single precision (`docs/backend-support.md`, KG-10).
3. `:tensor_network_fallback` is a routing label only; no tensor-network engine executes it (KG-1).
4. The OpenTelemetry-named adapter records in-process; no OpenTelemetry exporter ships (KG-13).
5. Not every envelope shape serializes: snapshot-covered shapes only (KG-14).
6. Multi-node (distributed) execution is not shipped.
7. Non-goals: a provider-breadth race, a compiler-depth race, and large-scale GPU simulation (`docs/vision.md` §4 and §6).

## 9) NxQuantum and FluxQ

NxQuantum is the execution engine. FluxQ, a separate project in development, is the control plane being built on top of it. NxQuantum runs circuits, simulation, and a typed provider lifecycle (submit, poll, cancel, fetch_result) inside your BEAM application, and returns versioned job, result, and error envelopes. FluxQ is designed to own what operators need around those envelopes: workflows, queues, retries, persistence, run history, and the UI. NxQuantum never depends on FluxQ, and FluxQ consumes NxQuantum envelopes unchanged.

In 0.12.0 (unreleased), snapshot-guarded envelopes and a decode-and-resume path let a host persist an envelope and resume it later (`test/nx_quantum/contracts/envelope_snapshot_test.exs`, `test/nx_quantum/contracts/envelope_decode_test.exs`, CHANGELOG `[Unreleased]`).

## 10) Further Reading

- [docs/vision.md](vision.md)
- [docs/roadmap.md](roadmap.md)
- [docs/python-comparison-workflows.md](python-comparison-workflows.md)
- [docs/migration-python-playbook.md](migration-python-playbook.md)
- [docs/livebook-tutorials.md](livebook-tutorials.md)
- [docs/case-study-beam-integration.md](case-study-beam-integration.md) (an illustrative pattern, not a user report)
- [docs/provider-support-catalog.md](provider-support-catalog.md)
