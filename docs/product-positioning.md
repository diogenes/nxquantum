# Product Positioning

Owns: the one line, the positioning statement, audience tiers, what users can rely on today (with evidence), the choose-NxQuantum-or-not guidance, and the messaging rules. Does not own: long-horizon strategy, ERRC, strategy canvas, and competitors (`docs/vision.md`); milestones, known gaps, and decisions (`docs/roadmap.md`).

Merged with the former `docs/decision-matrix.md` on 2026-10-30 (H1.5; the pointer stub was removed on 2026-11-25). Revised in the 2026-11-25 strategy review: proposals PD-1 to PD-13 are in the `docs/roadmap.md` Decision Log, and the research inputs are in `docs/research/algorithm-landscape-2025-2026.md`.

## 1) One Line

**Deterministic quantum simulation and execution on BEAM.** Proof line: *same seed, same result, across repeat runs and Nx/OTP upgrades today, and across nodes once H2.1 passes gate D2.*

Decision PD-1 (2026-11-25) refines D1 (2026-10-26), whose wording was "Deterministic quantum execution on BEAM for Elixir and Nx teams" (`docs/roadmap.md` Decision Log). Why it was refined:

1. "Execution" alone hides what most users run, which is the simulator.
2. "For Elixir and Nx teams" names the runtime, not the job the user needs done. The audience tiers (§3) carry the "who".
3. The proof line names evidence the project already holds (`bench/results/2026-10-26-h1.6/SUMMARY.md`), and it grows with each milestone instead of being rewritten.

Retired tagline (PD-1): "the standard parallel quantum computing simulation library". "Standard" is unearned: no external user is documented yet (`docs/roadmap.md` H1.5 review gate 4). Unqualified "parallel simulation" invites a race on distributed state-vector throughput, which `docs/vision.md` §10 rules out. In NxQuantum, "parallel" means deterministic ensemble parallelism (PD-2, §11 below).

## 2) Positioning Statement

> **For** BEAM/Nx teams, and for quantum researchers who need regression-grade reproducibility,
> **who** need quantum results they can re-run, diff, and gate in CI,
> **NxQuantum is** a pure-Elixir quantum simulation and execution library
> **that** returns seeded, reproducible simulator results with stated numerical limits, and runs cloud-provider jobs through one typed, versioned lifecycle.
> **Unlike** Python-first stacks, which compete on breadth and raw throughput, NxQuantum makes reproducibility the product: deterministic by default, every claim backed by in-repo evidence, and (planned) the same guarantee under noise, sampling, and distribution.

Each clause, checked against the code on 2026-11-25:

| Clause | Today | Evidence, or the milestone that delivers it |
| --- | --- | --- |
| Seeded, reproducible simulator results | Yes. Bit-identical on `Nx.BinaryBackend`; EXLA and Torchx within stated tolerances | `bench/results/2026-10-26-h1.6/SUMMARY.md`, `docs/backend-support.md` |
| Stated numerical limits | Yes. Single-precision floor about 5e-7, measured up to 6 qubits | `docs/backend-support.md` "Numerical Precision" (KG-10) |
| One typed, versioned lifecycle | Yes, for 4 core providers in the fixture lane; live lanes are env-gated | `docs/provider-support-catalog.md`, `test/nx_quantum/contracts/` |
| The same guarantee under sampling | Partly. Seeded Sampler and Estimator shots | `features/noise_and_shots.feature` |
| The same guarantee under noise | No. The `noise:` option is a scalar model (KG-30) | channel-based noise (PD-5) |
| The same guarantee under distribution | No | H2.1, gate D2 |
| Researchers can bring circuits from other stacks | No. There is no OpenQASM import | OpenQASM 3 interop (PD-13) |

The statement is a target. Public copy uses only the rows marked "Yes" (AGENTS.md messaging invariant; §11).

## 3) Who It Is For and Not For

| Tier | Who | The job they need done | What NxQuantum gives today | What is missing |
| --- | --- | --- | --- | --- |
| 1. Beachhead (primary) | BEAM/Nx teams embedding quantum workloads in services | Run circuits next to their `Nx`/`Nx.Defn` code, with typed contracts and reproducible CI | In-runtime Estimator, Sampler, kernels, gradients, and transpiler; typed provider lifecycle; envelope snapshots | Speed beyond small circuits (KG-6, KG-16); multi-qubit observables (KG-19) |
| 2. Adjacent (secondary; grows with H2) | Quantum software and algorithm researchers who need regression-grade reproducibility, for example checking an error-mitigation or noisy-algorithm result in CI | Re-run a noisy, sampled, or mitigated experiment bit-for-bit and compare it with an exact reference | Seeded sampling, experiment fingerprints, Livebooks, language-neutral envelopes | Channel-based noise (PD-5), float64 (PD-4), OpenQASM 3 import (PD-13), mitigation checked against a noisy reference |
| 3. Through FluxQ | Operators running hybrid workloads | Governance, run history, UI | Versioned envelopes; decode and resume (0.12.0, unreleased) | FluxQ itself (separate project) |
| Not targeted | Users whose top need is maximum exact qubit count on multi-node or HPC clusters, provider breadth, compiler depth, or real-time QEC decoding | — | — | Out of scope (`docs/vision.md` §10) |

Beachhead logic:

1. Win tier 1 first. It is the only audience for whom in-runtime execution is a must-be rather than a nice-to-have.
2. Reach tier 2 through things a Python user can try without moving their stack: OpenQASM 3 in, versioned JSON envelopes out, and Livebook.
3. Target tier 2 only with capabilities that have shipped. Until channel-based noise and float64 ship, tier 2 messaging is limited to seeded sampling and reproducibility evidence.

## 4) Determinism Scope and Backend Scope

1. Deterministic means fixed inputs, seed, runtime profile/options, and toolchain on one host produce stable outputs in simulator and fixture lanes.
2. Live provider and QPU lanes are probabilistic. NxQuantum guarantees typed contracts, lifecycle semantics, and reproducible request metadata there, not identical measured outcomes.
3. Backend scope: repeat runs are bit-identical on the default `Nx.BinaryBackend`. EXLA and Torchx are checked within stated tolerances (`docs/backend-support.md`).
4. Job ids and fingerprints use OTP's term encoding, which OTP keeps stable only within a major release, so they can change across OTP majors.

## 5) Choosing NxQuantum vs Python-First

| Situation | Prefer NxQuantum | Prefer Python-first |
| --- | --- | --- |
| Team stack | Elixir/Nx/BEAM services | Python-heavy research and infrastructure |
| Determinism and typed contracts | High priority: seeded simulator/fixture workflows plus typed, versioned envelopes | Lower priority or handled elsewhere |
| Reproducibility evidence in CI | You want bit-identical seeded reruns and fingerprints across Nx/OTP upgrades | Statistical agreement is enough |
| Hardware-provider breadth needed today | The core set of 4 providers through one typed lifecycle (`docs/provider-support-catalog.md`) is enough | Immediate broad provider support required |
| Compiler depth | Basic compilation and topology-aware transpilation are enough | Advanced compiler optimization is a requirement |
| Simulation scale | Circuits that fit single-machine state-vector simulation; published evidence covers 2–8 qubits (KG-6) | Large circuits, GPU throughput, or multi-node simulation are requirements |
| Noise simulation | Not yet: the `noise:` option is a scalar model (KG-30) | You need gate-level noise channels or trajectories today |
| Integration model | Keep training and serving in the same BEAM runtime | Existing Python orchestration is strategic |
| Migration appetite | Moving one workflow at a time (`docs/migration-python-playbook.md`) | Continue optimizing the current Python stack |

## 6) Recommendation Pattern

1. Choose NxQuantum when integration simplicity and deterministic contracts in BEAM matter most.
2. Choose Python-first when provider breadth, compiler depth, noise simulation, or GPU-scale simulation is the top requirement today.
3. Use both when you need both in the short term.

## 7) What You Can Rely On

| Claim | Evidence | Date | Environment |
| --- | --- | --- | --- |
| Moving from Nx 0.11 to 1.0 and from OTP 28 to 29 changed none of the tracked numerics digest lines (seeded sampler counts, gradients, compiler output) | `bench/results/2026-10-26-h1.6/SUMMARY.md` (two runs per state) | 2026-10-26 | Apple M4, macOS 26.6.2, default `Nx.BinaryBackend`, one host |
| Job, result, and error envelopes for the 4 core providers (fixture lane) are guarded by byte snapshots and can be decoded and resumed; the fixture tree id was unchanged across the upgrade, and the FluxQ test suite passed against it (decode/resume is unreleased, 0.12.0) | `test/nx_quantum/contracts/envelope_snapshot_test.exs`, `test/nx_quantum/contracts/envelope_decode_test.exs`, `test/fixtures/contracts/envelopes/`, `docs/api-stability.md`, `bench/results/2026-10-26-h1.6/fluxq-consumer-check.txt` | 2026-10-26 | Elixir 1.19.5 / OTP 28.4.1 for the FluxQ check; digests also on Elixir 1.20.4 / OTP 29.1.2 |
| Compiler and transpiler passes are tested against an independent dense reference: 3 fixed seed sets of 12 random circuits each, up to 6 qubits, tolerance 1e-9 for exact rewrites and 1e-6 for resynthesis; the suite found 2 defects, both fixed (unreleased; see CHANGELOG `[Unreleased]`) | `test/property/compiler_semantic_equivalence_property_test.exs`, `test/property/gate_identity_property_test.exs`, `test/property/transpiler_routing_equivalence_property_test.exs`, `test/support/dense_reference.ex`, `docs/roadmap.md` H1.4 Evidence | 2026-10-25 | the test environment (not a timed benchmark); single-precision floor in `docs/backend-support.md` |

These are internal, environment-specific references, not official results. NxQuantum makes no speed claims (README Performance section).

## 8) Where Hybrid Quantum-AI Fits

Hybrid quantum-AI (AI tool contracts with rerank and optimization handlers) is an application of the properties above, not the lead.

- The in-repo rerank datasets are synthetic and carry `provenance: synthetic` (KG-5). The real-data lane is parked (`docs/vision.md` §11).
- The hybrid benchmark scripts emit fixed placeholder figures, not measurements (KG-11).
- The bundled rerank and optimization handlers compute classically and report `execution.mode: :classical` (KG-12, PD-6). They make no simulator or provider call, so they are not quantum computations.

No real-data quality claim is made.

## 9) Known Limits and Non-Goals

1. Live hardware results are probabilistic, and live lanes are env-gated (`docs/provider-support-catalog.md`).
2. The simulator is single precision (`docs/backend-support.md`, KG-10). Decision PD-4 proposes an opt-in float64 mode.
3. The `noise:` option is a scalar model, not a noise channel (KG-30).
4. `cpu_compiled` runs only the expectation step on EXLA; state evolution stays on the default backend (KG-16).
5. `:tensor_network_fallback` is a routing label only; no tensor-network engine executes it (KG-1).
6. The OpenTelemetry-named adapter records in-process; no OpenTelemetry exporter ships (KG-13).
7. Not every envelope shape serializes: snapshot-covered shapes only (KG-14).
8. Multi-node (distributed) execution is not shipped.
9. Non-goals: a provider-breadth race, a compiler-depth race, multi-node exact state-vector simulation, and real-time QEC decoding (`docs/vision.md` §10). Single-device acceleration through EXLA is in scope (PD-3).

## 10) NxQuantum and FluxQ

NxQuantum is the execution engine. FluxQ, a separate project in development, is the control plane being built on top of it. NxQuantum runs circuits, simulation, and a typed provider lifecycle (submit, poll, cancel, fetch_result) inside your BEAM application, and returns versioned job, result, and error envelopes. FluxQ is designed to own what operators need around those envelopes: workflows, queues, retries, persistence, run history, and the UI. NxQuantum never depends on FluxQ, and FluxQ consumes NxQuantum envelopes unchanged.

In 0.12.0 (unreleased), snapshot-guarded envelopes and a decode-and-resume path let a host persist an envelope and resume it later (`test/nx_quantum/contracts/envelope_snapshot_test.exs`, `test/nx_quantum/contracts/envelope_decode_test.exs`, CHANGELOG `[Unreleased]`).

## 11) Messaging Rules

Used by the docs-sync claims audit (`skills/docs-sync/SKILL.md`) for README, docs, launch posts, and package descriptions.

| Say | Do not say | Why |
| --- | --- | --- |
| "deterministic in simulator and fixture lanes" | "deterministic quantum computing", "deterministic results on hardware" | Live QPU results are probabilistic (§4) |
| "deterministic ensemble parallelism" (shots, trajectories, sweeps), once H2.1 ships | "parallel quantum simulation" without the qualifier; "the standard" | PD-2; no external user is documented yet |
| "bit-identical on the default backend; within stated tolerances on EXLA and Torchx" | "bit-identical on every backend" | §4 item 3 |
| "the `noise:` option is a scalar model" | "noise channels", "realistic noise" (until channel-based noise ships) | KG-30 |
| "internal, environment-specific benchmark reference" | any cross-framework speed claim | README Performance section; owner decision 2026-10-30 |
| "4 core providers through one typed lifecycle" | "every provider", "provider-neutral" without the supported list | AGENTS.md invariant |
| "classical computation behind a quantum tool contract", with `execution.mode: :classical` | "quantum rerank" or "quantum optimization" for the bundled handlers | KG-12 |

## 12) Further Reading

- [docs/vision.md](vision.md)
- [docs/roadmap.md](roadmap.md)
- `docs/research/algorithm-landscape-2025-2026.md` (research intake; not in HexDocs)
- [docs/python-comparison-workflows.md](python-comparison-workflows.md)
- [docs/migration-python-playbook.md](migration-python-playbook.md)
- [docs/livebook-tutorials.md](livebook-tutorials.md)
- [docs/case-study-beam-integration.md](case-study-beam-integration.md) (an illustrative pattern, not a user report)
- [docs/provider-support-catalog.md](provider-support-catalog.md)
