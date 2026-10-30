# NxQuantum Vision

Status (2026-10-19): approved. Replaces the former `quantum-llm-vision.md` and the two 2026-10-18 proposal drafts, which were absorbed here and removed in H1.1.

This document owns the long-horizon direction. `docs/roadmap.md` owns execution: milestones, gates, and status.

## 1. North Star

NxQuantum aims to be the provider-neutral quantum execution engine for BEAM, deterministic in simulator and fixture lanes. Teams can embed it directly in Elixir applications, or operate it through FluxQ, the control plane ("FluxQ powered by NxQuantum").

## 2. Product Line Boundary

| NxQuantum (engine, library) | FluxQ (control plane, separate project) |
| --- | --- |
| Circuits, simulation, `Estimator`/`Sampler`, compiler/transpiler | Workflows, run/step state, queues |
| Provider adapters, typed lifecycle (`submit`/`poll`/`cancel`/`fetch_result`), versioned envelopes | Retries, timeouts, cancellation policy, persistence, run history |
| Runtime profiles and lanes (`fixture`, `live_smoke`, `live`) | Scheduling and routing policy; promotion policy-as-code |
| Telemetry emission; evidence primitives (fingerprints, portability deltas, troubleshooting bundle content, replay fixtures) | Evidence graph, replay studio, incident UX, claim-integrity console |
| Distributed execution *within* a job (fan-out of tasks or fragments across nodes) | Orchestration *across* jobs; operator UI; tenancy and RBAC |
| Deterministic simulation of distributed quantum systems (H3) | Policy testing against that simulation (H3) |

Rules:
1. FluxQ consumes NxQuantum envelopes unchanged.
2. NxQuantum never depends on FluxQ.
3. Control-plane features are not added to NxQuantum. This reaffirms the v0.8 non-goal.

Source: FluxQ `docs/product/positioning-and-principles.md` and `docs/plan/master-plan.md`.

## 3. Thesis

As quantum hardware scales, the quantum computer becomes a distributed system. IBM's published roadmap moves from a single chip to coupled modules: Kookaburra (2026, one module with a logical processing unit and quantum memory), Cockatoo (2027, two Kookaburra modules linked by L-couplers), and Starling (2029, 200 logical qubits). Checked 2026-10-30: [IBM Quantum roadmap](https://www.ibm.com/roadmaps/quantum/) for Kookaburra and Starling's 2029 date; [IBM newsroom, 2025-06-10](https://newsroom.ibm.com/2025-06-10-IBM-Sets-the-Course-to-Build-Worlds-First-Large-Scale,-Fault-Tolerant-Quantum-Computer-at-New-IBM-Quantum-Data-Center) for Cockatoo and Starling's 200 logical qubits. Cockatoo (2027) rests on the 2025 release; the current roadmap page lists multi-module demonstration under 2028 — recheck at D2. An IBM newsroom search on 2026-10-30 found no Kookaburra delivery announcement. Above the physical link layer, the hard problems are distributed-systems problems:
- partial failure;
- scheduling perishable resources;
- heterogeneous workers;
- reproducible testing.

BEAM was built for this class of problem. Each project takes one side of the bet:
- **NxQuantum:** distributed execution primitives, plus a deterministic simulator of distributed quantum systems in which failures are reproducible.
- **FluxQ:** the operations layer, meaning policies, state, and UI.

The joint value is a control plane whose policies are tested against a seeded, deterministic simulation of a distributed quantum system before they touch hardware. Adjacent work exists (checked 2026-10-30):
- NetSquid simulates quantum networks with discrete events, including the control plane of a quantum switch ([Coopmans et al., Commun. Phys. 4, 164, 2021](https://arxiv.org/abs/2010.12535)).
- ORNL's digital twin of quantum clouds models job lifecycle and job scheduling ([ACM SIGSIM PADS 2025](https://impact.ornl.gov/en/publications/a-digital-twin-of-scalable-quantum-clouds/)).
- memQ's CUDA-Q simulator is a digital twin of a distributed processor and lists runtime orchestration as future work ([memQ](https://memq.tech/memq_full_stack_simulation_cudaq/)).

None of these sources documents seeded replay of a control plane's routing or promotion policies. One that does falsifies this paragraph. Recheck at D2 (§13 item 6).

## 4. Audience

- **Primary:** BEAM/Nx teams embedding quantum workloads in their services.
- **Through FluxQ:** operators and teams running hybrid workloads who need governance and UI.
- **Secondary:** quantum researchers who need reproducibility, reached through Livebook and language-neutral contracts (MCP JSON-RPC, CloudEvents, versioned JSON envelopes).
- **Not targeted:** users whose top need is compiler depth, provider breadth, or GPU-scale simulation.

## 5. Pillars

1. **Trust.** Deterministic by default in simulator and fixture lanes, verified physics, evidence-backed claims with explicit limits.
2. **Contracts.** Stable, versioned, typed envelopes that hosts (FluxQ and user apps) can build on without breakage.
3. **Scale-out.** Distributed execution within a job, then deterministic simulation of distributed quantum systems.

Hybrid quantum-AI (kernel rerank, optimization helpers, AI tool contracts) is an application of these pillars, not the lead message. Decision D1 (2026-10-26, `docs/roadmap.md` Decision Log) set the lead to "deterministic quantum execution on BEAM". The in-repo rerank datasets are synthetic (KG-5), so no real-data quality claim is made, and the real-data rerank lane is parked (§11).

## 6. Strategy Frame

**Blue ocean (ERRC)**

| Eliminate | Reduce | Raise | Create |
| --- | --- | --- | --- |
| Provider-breadth race; compiler-breadth race | Provider surface beyond the core set | Determinism, contract stability, reproducible evidence | Within-job distributed execution on BEAM; deterministic simulation testing of distributed quantum systems (paired with FluxQ policies) |

**Kano hypotheses** (to be validated by the H1.5 survey)

| Category | Features |
| --- | --- |
| Must-be | Correct physics, working Hex install, runnable docs, stable envelopes |
| Performance | Small-circuit speed, batch throughput, qubit range |
| Delighter | Experiment fingerprints, one-call classical-baseline comparison, multi-node Livebook demo |

**Positioning: complement, don't compete** (competitor facts checked 2026-10-30; next recheck at D2)

| Player | Owns | Source (checked 2026-10-30) |
| --- | --- | --- |
| Qiskit | IBM hardware, compiler, fault-tolerance compilation (Pauli-based computation and Clifford+T preset pass managers since v2.5) | [Qiskit v2.5, 2026-07-14](https://www.ibm.com/quantum/blog/qiskit-2-5-release-summary) |
| PennyLane | Differentiable programming and quantum ML; FTQC algorithm design and resource estimation (`qp.estimator`) | [PennyLane v0.45, 2026-05-13](https://pennylane.ai/blog/2026/05/pennylane-release-0.45) |
| Cirq | NISQ circuit research; Google Quantum AI's framework, with vendor modules (AQT, IonQ, Pasqal) | [quantumlib/Cirq](https://github.com/quantumlib/Cirq) |
| CUDA-Q | GPU simulation, QPU–GPU integration (NVQLink), QEC decoding. CUDA-Q Logical (released 2026-09-14 as a preview) compiles fault-tolerant programs down to QEC microcode, physical gate schedules, and real-time control plans, and derives resource estimates from those artifacts. | [NVIDIA, 2026-09-14](https://nvidianews.nvidia.com/news/nvidia-expands-open-source-cuda-q-platform-for-fault-tolerant-quantum-computing); [arXiv:2609.13388](https://arxiv.org/abs/2609.13388); [CUDA-Q](https://developer.nvidia.com/cuda-q) |
| memQ | Distributed compilation across linked QPUs: open-source DQC (Apache-2.0, beta) released 2026-09-24; CUDA-Q-based simulator of distributed processors | [memQ news](https://memq.tech/news/); [memQGit/dqc](https://github.com/memQGit/dqc) |
| **NxQuantum** | Provider-neutral execution engine on BEAM, deterministic in simulator and fixture lanes; planned: within-job distributed execution (H2), distributed-systems simulation (H3) | `docs/roadmap.md` |
| **FluxQ** | Control plane over NxQuantum (in development) | FluxQ `docs/product/positioning-and-principles.md` |

BEAM ecosystem (checked 2026-10-30, [hex.pm](https://hex.pm/packages/qx_sim), [README](https://github.com/richarc/qx), [kino_qx](https://hex.pm/packages/kino_qx)): qx_sim 0.11.0 is an Nx-based Elixir statevector simulator (up to 20 qubits) with IBM Quantum hardware execution; kino_qx, a companion package by the same author, adds Livebook Smart Cells. The qx_sim README does not document multi-provider execution, versioned envelopes, or distributed execution.

One line: *NxQuantum runs quantum workloads on BEAM, deterministically in simulator and fixture lanes; multi-node execution is the Horizon 2 goal. FluxQ operates them.*

## 7. Horizons

Execution detail for H1 and H2 lives in `docs/roadmap.md`. H3 is detailed here because it is gated on H2 results.

**H1: Honest, evidenced, embeddable (Q4 2026 – Q1 2027)**
- Goal: today's engine is honest, evidenced, contract-guarded for FluxQ, and in front of its audience.
- Exit:
  - docs match code;
  - envelope snapshots guard FluxQ compatibility;
  - cross-framework harness refreshed (version-pinned, correctness-gated); timed comparison and crossover points at major releases (owner 2026-10-30);
  - D1 recorded; rerank datasets labeled synthetic;
  - compiler equivalence suite green;
  - Kano survey done.

**H2: Distributed execution engine (2027)**
- Goal: a single NxQuantum job fans out across BEAM nodes with seed-reproducible results and survives node loss; cut circuits execute across nodes and providers; FluxQ surfaces distributed runs.
- Exit: decision gate D2 passed; one external team runs distributed jobs, directly or through FluxQ.

**H3: Deterministic distributed quantum systems (2028+, aligned with modular hardware)**

| Milestone | Owner | Entry gate | Scope | Exit evidence |
| --- | --- | --- | --- | --- |
| H3.1 Systems twin alpha | NxQuantum | D3 passed | QPU modules, links, and decoders as processes; entanglement and decoherence models; fault injection; virtual-time replay | An external group reproduces a published distributed-QC result |
| H3.2 Policy testing on the twin | FluxQ, with NxQuantum contracts | H3.1 exit | FluxQ routing and promotion policies run against twin failure scenarios | Policy decisions are reproducible against seeded twin scenarios |
| H3.3 Twin to live | NxQuantum | H3.1 exit; vendors expose multi-module or multi-QPU control hooks | Swap twin adapters for real targets | Live and twin traces are contract-identical |
| H3.4 Network control-plane exploration | FluxQ | Partner or testbed interest | Spike only: entanglement and resource scheduling across sites; possibly QKD key management, after market and standards are verified | Go/no-go memo |

## 8. Decision Gates

| Gate | When | Question | If no |
| --- | --- | --- | --- |
| D1 | After H1.3 | Does real-data evidence support hybrid quantum-AI as the lead message? | Demote it to an application and lead with "deterministic quantum execution on BEAM". The NxQuantum AGENTS.md messaging invariant changes only with owner approval (FluxQ's AGENTS.md has none). Decided 2026-10-26 (owner): no, before H1.3 finished; see the `docs/roadmap.md` Decision Log (NxQuantum AGENTS.md invariant updated with owner approval, 2026-10-30). |
| D2 | After H2.1 | Does the same seed give identical results on 1 vs N nodes, and identical traces in virtual-time mode? | Keep result-determinism only. Cancel H3.1, which depends on trace determinism. |
| D3 | After H2.3 | Do D2 pass, one external distributed-run user, and visible multi-QPU hardware signals all hold? | Stay in H2. Revisit yearly. |

## 9. Investment Allocation (NxQuantum)

- **70%:** H1 and core usefulness.
- **20%:** H2.
- **10%:** H3 research spikes.

Rebalance only after a decision gate passes. Announce only what is shipped and evidenced; H3 stays internal until D2 passes.

## 10. Non-Goals

1. Control-plane responsibilities: workflow state, queues, retries, persistence, scheduling or promotion policy, UI, tenancy. FluxQ owns these.
2. Real-time QEC decoding. Microsecond budgets belong to FPGA/GPU; NxQuantum supervises decoders through ports.
3. Distributed state-vector simulation competing with MPI or HPC interconnects.
4. Compiler-breadth or provider-breadth parity with Python-first stacks.
5. Quantum-native LLM claims, or deterministic live-QPU outcome claims.

## 11. Parked (demand-triggered; not on the roadmap)

| Idea | Trigger to un-park | Notes |
| --- | --- | --- |
| Clifford/stabilizer simulator | A named user needs QEC simulation | Commodity: Stim, Qiskit Aer (`stabilizer` method), CUDA-Q (`stim` target) (checked 2026-10-30: [Aer 0.18.2 docs](https://qiskit.github.io/qiskit-aer/stubs/qiskit_aer.AerSimulator.html), [CUDA-Q backends](https://nvidia.github.io/cuda-quantum/latest/using/backends/simulators.html)). Needs an ADR: `Ports.Simulator.apply_gates/3` returns amplitudes. |
| FTQC resource estimation | Adoption interviews ask for it | PennyLane (`qp.estimator`) and CUDA-Q Logical ship it; Qiskit ships fault-tolerant compilation passes (checked 2026-10-30: [PennyLane v0.45](https://pennylane.ai/blog/2026/05/pennylane-release-0.45), [arXiv:2609.13388](https://arxiv.org/abs/2609.13388), [Qiskit v2.5](https://www.ibm.com/quantum/blog/qiskit-2-5-release-summary)) |
| Tensor-network contraction engine | Benchmark win over dense at ≤20 qubits | `:tensor_network_fallback` is routing-only today |
| Krylov/Lanczos time evolution | Hamiltonian-dynamics user | — |
| Qiskit C API compiler adapter | Distributed compile-farm demand | Opt-in adapter only; the native compiler stays the default |
| Migration assurance toolkit (ADR 0007) | Teams migrating Python workflows ask for it | Scoped `Migration.AI*` slice already shipped |
| New promotion-gate features in `Migration.AIGates` | — | Frozen: keep the API stable; promotion policy grows in FluxQ (P3) |
| Analog/non-gate-model provider workflows | Provider demand | — |
| Real-data hybrid rerank lane (BEIR SciFact; NFCorpus dropped) | A named user needs hybrid rerank quality evidence on real data, or D1 is reopened | Parked by D1 (2026-10-26). In-repo datasets are synthetic (KG-5). License notes from the 2026-10-25 intake (SciFact upstream LICENSE.md: CC BY 4.0 claims, ODC-By 1.0 abstracts, fetch-only and aggregates-only; NFCorpus: academic use only) and the Bumblebee path (0.8 needs nx ~> 1.0, axon ~> 0.9) are unverified in-repo; recheck at un-park. Bumblebee needs dependency justification and an architecture owner. |
| Lean-verified gate identities | Research only | H1.4 covers identities with property tests |

## 12. Research Intake Rule

Any paper-derived proposal (including the 2026 OpenAI math-repository review) enters the roadmap only after the physics/math seat records:
1. the verified source, with refereed and Lean-compiled status;
2. whether a competitor already ships it;
3. the user workflow it serves;
4. a falsifiable correctness or benchmark hypothesis.

Enforced through the `principal-architect-product-strategy` plan review.

## 13. Risks

1. **Customer identity for H3.** Multi-QPU control stacks are built in-house today: a search on 2026-10-30 found no third-party multi-QPU control stack for sale. The nearest offerings are memQ's network control and interface hardware plus its beta open-source distributed compiler ([memQ](https://memq.tech/), [memQGit/dqc](https://github.com/memQGit/dqc); beta status is stated only on GitHub), and NVQLink, which couples QPUs to GPU supercomputers rather than to each other ([NVIDIA, 2026-09-14](https://nvidianews.nvidia.com/news/nvidia-expands-open-source-cuda-q-platform-for-fault-tolerant-quantum-computing)). Cisco's distributed-QC software stack and network-aware compiler are free research prototypes ([Cisco, 2025-09-25](https://blogs.cisco.com/news/cisco-quantum-labs-announces-software-that-networks-quantum-computers-together-and-enables-new-classical-applications)). Mitigation: H2 must pay off on its own, and FluxQ provides the operator-facing value.
2. **Timing.** Modular hardware may slip. Mitigation: staged gates, 70/20/10 allocation.
3. **Determinism vs distribution.** The hardest technical risk; gated by D2.
4. **Boundary drift with FluxQ.** Mitigation: envelope snapshot guard (H1.2) and the non-goal rule above.
5. **Physics fidelity of the twin.** The physics/math seat owns H3.1 acceptance.
6. **Competitor drift.** Recheck competitor facts at every decision gate. Last recheck: 2026-10-30 (H1.3 review gate 5). Next: D2.

## 14. Success Metrics

- **Adoption:** external users (direct and through FluxQ), Hex downloads trend, external issue and PR authors.
- **Trust:** deterministic replay rate; claims with in-repo evidence (target: 100%).
- **Contracts:** envelope-breaking changes without a `schema_version` bump (target: 0).
- **Scale-out:** distributed jobs completing with identical results under injected node loss (target: 100% in fixture lanes).
