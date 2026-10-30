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

As quantum hardware scales, the quantum computer becomes a distributed system. IBM's published roadmap moves from a single chip to coupled modules (Kookaburra 2026, Cockatoo 2027, Starling 2029). Above the physical link layer, the hard problems are distributed-systems problems:
- partial failure;
- scheduling perishable resources;
- heterogeneous workers;
- reproducible testing.

BEAM was built for this class of problem. Each project takes one side of the bet:
- **NxQuantum:** distributed execution primitives, plus a deterministic simulator of distributed quantum systems in which failures are reproducible.
- **FluxQ:** the operations layer, meaning policies, state, and UI.

The joint value is a control plane whose policies are tested against a deterministic simulated quantum system before they touch hardware. Whether any competitor offers this is unverified; it is rechecked at each decision gate (§13 item 6).

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

**Positioning: complement, don't compete**

| Player | Owns |
| --- | --- |
| Qiskit | IBM hardware, compiler, fault-tolerance compilation |
| PennyLane | Differentiable programming, FTQC algorithm design and resource estimation |
| Cirq | Google hardware research |
| CUDA-Q | GPU simulation, QPU–GPU datacenter integration, decoding. CUDA-Q Logical (announced) overlaps orchestration inside the datacenter. |
| memQ | Distributed compilation across linked QPUs |
| **NxQuantum** | Provider-neutral execution engine on BEAM, deterministic in simulator and fixture lanes; planned: within-job distributed execution (H2), distributed-systems simulation (H3) |
| **FluxQ** | QROps control plane over NxQuantum |

One line: *NxQuantum runs quantum workloads on BEAM, deterministically in simulator and fixture lanes; multi-node execution is the Horizon 2 goal. FluxQ operates them.*

## 7. Horizons

Execution detail for H1 and H2 lives in `docs/roadmap.md`. H3 is detailed here because it is gated on H2 results.

**H1: Honest, evidenced, embeddable (Q4 2026 – Q1 2027)**
- Goal: today's engine is honest, evidenced, contract-guarded for FluxQ, and in front of its audience.
- Exit:
  - docs match code;
  - envelope snapshots guard FluxQ compatibility;
  - benchmarks refreshed with crossover points;
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
| Clifford/stabilizer simulator | A named user needs QEC simulation | Commodity (Stim, Qiskit Aer, CUDA-Q). Needs an ADR: `Ports.Simulator.apply_gates/3` returns amplitudes. |
| Tensor-network contraction engine | Benchmark win over dense at ≤20 qubits | `:tensor_network_fallback` is routing-only today |
| Krylov/Lanczos time evolution | Hamiltonian-dynamics user | — |
| Qiskit C API compiler adapter | Distributed compile-farm demand | Opt-in adapter only; the native compiler stays the default |
| FTQC resource estimation | Adoption interviews ask for it | PennyLane and Qiskit lead here |
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

1. **Customer identity for H3.** Multi-QPU control stacks are built in-house today. Mitigation: H2 must pay off on its own, and FluxQ provides the operator-facing value.
2. **Timing.** Modular hardware may slip. Mitigation: staged gates, 70/20/10 allocation.
3. **Determinism vs distribution.** The hardest technical risk; gated by D2.
4. **Boundary drift with FluxQ.** Mitigation: envelope snapshot guard (H1.2) and the non-goal rule above.
5. **Physics fidelity of the twin.** The physics/math seat owns H3.1 acceptance.
6. **Competitor drift.** Recheck competitor facts at every decision gate.

## 14. Success Metrics

- **Adoption:** external users (direct and through FluxQ), Hex downloads trend, external issue and PR authors.
- **Trust:** deterministic replay rate; claims with in-repo evidence (target: 100%).
- **Contracts:** envelope-breaking changes without a `schema_version` bump (target: 0).
- **Scale-out:** distributed jobs completing with identical results under injected node loss (target: 100% in fixture lanes).
