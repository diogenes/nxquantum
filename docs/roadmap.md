# NxQuantum Roadmap

This is the execution source of truth: milestones, gates, and status.

- Long-horizon direction, positioning, parked ideas, and non-goals live in [docs/vision.md](vision.md).
- Release history lives in [CHANGELOG.md](../CHANGELOG.md).
- NxQuantum is the execution engine. FluxQ, a separate project, is the control plane that consumes NxQuantum envelopes unchanged (see `docs/vision.md` §2).

Restructured on 2026-10-18. The full pre-restructure phase text (Phases 0–23 and D1–D4) is preserved in git history (`git log -- docs/roadmap.md`, before this change).

## Versioning Policy

1. Releases continue on `0.x` while preserving stable-contract discipline. The latest published version is `0.11.0`.
2. Filenames containing `v1.0` are artifact names, not version commitments. They are renamed in H1.1.
3. `v1.0` promotion requires all of:
   - at least one documented production user (direct or through FluxQ);
   - envelope compatibility guarded by H1.2 and proven across two consecutive minor releases;
   - release gates green (`mix quality`, `mix dialyzer`, `mix ci`, provider smoke lanes);
   - every experimental public API either promoted to stable or explicitly excluded from the `v1.0` contract.

## Roadmap Scope Policy (Near-Term Execution Only)

1. Detailed milestones cover Horizons 1 and 2 only. Each has a clear implementation path.
2. Horizon 3 and parked ideas live in `docs/vision.md`. They enter this roadmap only through a decision gate or the research intake rule (`docs/vision.md` §12).
3. Control-plane features (workflow state, queues, retries, persistence, scheduling or promotion policy, UI) are out of scope; they belong to FluxQ.

## Milestone Template Policy (Required for All Unfinished Milestones)

Every unfinished milestone (`### H<horizon>.<n> - <name>`) must include:

1. Header fields: `Status`, `Intent` (from the AGENTS.md routing matrix), `Seats`, `Depends on`, `Target release`.
2. `Goal:` section, with an explicit user or engineering outcome.
3. `Implementation deliverables:` section, with concrete modules, files, tests, and docs. Paths marked *tentative* are fixed in the milestone's plan review or ADR.
4. `Review gate:` section, with deterministic evidence criteria.

Status values: `planned`, `in progress`, `done`.
- `done` requires every deliverable to name its module, test, or CHANGELOG entry.
- Seats refer to the agent-team roles in the process update of H1.1.

## Current State (0.11.0)

Strengths:
- deterministic local simulation, fastest on 2–8 qubit workloads;
- typed provider lifecycle across IBM Runtime, AWS Braket, Azure Quantum, and Google Quantum AI (fixture, `live_smoke`, and `live` lanes);
- OpenTelemetry observability;
- AI tool contracts;
- TurboQuant rerank.

Known gaps:

| ID | Gap | Addressed by |
| --- | --- | --- |
| KG-1 | `:tensor_network_fallback` is a routing label; no tensor-network engine executes it | Closed in H1.1: documented as routing-only (`docs/backend-support.md`, `Runtime` type comment); engine parked |
| KG-2 | Phases 14–16 were never checked off | Closed in H1.1: audit recorded in Shipped History; partial items listed there |
| KG-3 | No property tests prove compiler passes preserve semantics (Phase 15 deliverable 6); `compiler_test.exs` is example-based | Open: H1.4 |
| KG-4 | Phase 17 Migration Assurance Toolkit not delivered | Closed in H1.1: ADR 0007 Deferred; parked (`docs/vision.md` §11) |
| KG-5 | Rerank datasets (`bench/datasets/rerank/*`) appear synthetic; manifests lack provenance | H1.3 |
| KG-6 | Cross-framework benchmarks cover 2–8 qubits against March 2026 competitor versions | H1.3 |
| KG-7 | `ProviderBridge.Serialization` serializes envelopes, but no decode/rehydrate path was found for resuming persisted jobs (needed by FluxQ) | H1.2 |
| KG-8 | Doc sprawl: about 60 docs, version-named living docs, pointer-only duplicates | Closed in H1.1: 34 living docs in `docs/`, 24 history docs in `docs/archive/` |
| KG-9 | No git tags for published versions | H1.1 (owner action) |

---

## Horizon 1 - Honest, Evidenced, Embeddable (Q4 2026 – Q1 2027)

Order: H1.1 first. H1.2, H1.3, and H1.4 then run in parallel. H1.5 comes after H1.3, because decision D1 shapes the messaging.

### H1.1 - Status Truth and Docs Consolidation

- Status: in progress (PR open; see Decision Log)
- Intent: refactor (docs and process)
- Seats: Lead, Docs sync (claims audit), Verifier
- Depends on: owner approval of `docs/vision.md` and this roadmap
- Target release: none

Goal:

1. Every status claim in the repo matches the code.
2. Living docs are findable without version-name archaeology.
3. The agent team and quality gates are codified where contributors read them.

Implementation deliverables:

1. Audit Phase 14–16 deliverables against the code. Record shipped items and gaps in the Shipped History table below and add gaps to Known Gaps.
2. Document `:tensor_network_fallback` as routing-only (`docs/backend-support.md`; `NxQuantum.Runtime` type docs).
3. Set ADR 0007 status to `Deferred`, with a pointer to `docs/vision.md` §11.
4. Execute the Docs Consolidation Plan (below), updating every reference:
   - `README.md`, `CHANGELOG.md` links, `mix.exs` extras;
   - `AGENTS.md` required reading, `skills/*/SKILL.md`, `bench/README.md`;
   - `test/features/steps/provider_cross_platform_rollout_steps.ex`;
   - FluxQ `docs/architecture/fluxq-control-plane-monorepo-proposal.md`.
5. Process update (owner approval required, because `AGENTS.md` changes):
   - add activation-by-intent seats and the veto table to the `AGENTS.md` Plan → Producer → Critic → Verifier loop;
   - add `skills/quantum-physics-verification/SKILL.md`;
   - add the research-intake checklist to `skills/principal-architect-product-strategy/SKILL.md`;
   - add the claims-audit checklist to `skills/docs-sync/SKILL.md`;
   - Elixir code quality stays advisory (owner decision, 2026-10-18).
6. Owner action (outward-facing): create git tags for published Hex versions.

Review gate:

1. Every `done` row in Shipped History names a module, test, or CHANGELOG entry.
2. `mix docs.build`, `mix test.features`, and `mix test test/nx_quantum/roadmap_structure_test.exs` are green.
3. Manual link check passes for changed docs, including FluxQ's links into NxQuantum.

### H1.2 - FluxQ Integration Contract Guard

- Status: planned
- Intent: api change (additive), provider integration
- Seats: Lead, DX, Quantum engineering, Critic, Verifier
- Depends on: H1.1
- Target release: 0.12.0

Goal:

1. FluxQ can persist and later resume NxQuantum jobs from stored envelopes.
2. Any envelope shape change is caught in NxQuantum CI before it reaches FluxQ.

Implementation deliverables:

1. Deterministic golden snapshots of serialized job, result, and error envelopes for every core provider in the fixture lane (*tentative*: `test/fixtures/contracts/envelopes/`).
2. A snapshot test that fails on any shape change unless `schema_version` is bumped (*tentative*: `test/nx_quantum/contracts/envelope_snapshot_test.exs`).
3. A rehydration path: decode a serialized job envelope and resume it through `ProviderBridge` `poll`/`fetch_result`. This is an additive decode function if none exists (KG-7).
4. An envelope compatibility policy in `docs/api-stability.md`:
   - `schema_version` semantics and deprecation window;
   - the snapshot location that FluxQ's G2 gate consumes.

Review gate:

1. Snapshots are byte-identical across 3 runs.
2. The serialize → decode → poll → fetch round-trip contract test is green for all core providers (fixture lane).
3. `mix test.release_evidence` and `mix dialyzer` are green.
4. FluxQ's G2 gate references the snapshot path; that change is tracked in the FluxQ roadmap.

### H1.3 - Evidence Refresh

- Status: planned
- Intent: performance (evidence only)
- Seats: Lead, Quantum physics/math, Verifier, Product marketing (claims audit)
- Depends on: H1.1
- Target release: none (bench and docs)

Goal:

1. Public speed and quality claims rest on current, version-pinned evidence with stated limits.
2. Hybrid quantum-AI reranking gets a real-data verdict, which feeds D1.

Implementation deliverables:

1. Rerun `bench/python_alternatives_benchmark.py` against current pinned Qiskit 2.x, PennyLane, and Cirq releases (versions recorded in the report), using 3-run means.
2. Add 12, 16, 20, and 24 qubit scenarios, and state the crossover point where NxQuantum stops winning.
3. Publish `docs/python-alternatives-benchmark-<date>.md` and archive the 2026-03-25 report.
4. Add a real-data rerank lane, BEIR SciFact first and NFCorpus second:
   - verify licenses before use;
   - commit a fetch script plus a provenance manifest (source URL, license, embedding model and version, dimensionality-reduction method, seed, `sha256`); raw data is not committed;
   - decide the embedding-generation path in plan review. Bumblebee would be a dev-only dependency that needs architecture justification; the alternative is offline generation with a pinned model.
5. Publish nDCG@10 against the classical baseline in the hybrid benchmark doc, regardless of outcome.
6. Record decision D1 in the Decision Log.

Review gate:

1. Reports are version-pinned, 3-run, and caveat-labeled.
2. README speed claims cite the new report, including the crossover.
3. The rerank result and its classical baseline are published.
4. D1 is recorded with its rationale.

### H1.4 - Compiler Correctness Suite

- Status: planned
- Intent: feature (verification)
- Seats: Quantum physics/math (acceptance owner), Critic, Verifier
- Depends on: H1.1
- Target release: 0.12.0 (only if fixes land)

Goal:

1. Every compiler and transpiler rewrite is proven semantics-preserving by deterministic property tests against analytic references. This closes KG-3.

Implementation deliverables:

1. A gate-identity catalog as test support, with each identity tagged with the pass it justifies: `simplify`, `fuse`, `cancel`, `resynthesize_1q`, swap insertion (*tentative*: `test/support/gate_identities.ex`).
2. A property test over random circuits of up to 6 qubits, with fixed seeds (*tentative*: `test/property/compiler_semantic_equivalence_property_test.exs`). Each pass and the full pipeline must preserve the unitary up to global phase.
3. Routing equivalence: a routed circuit equals the original up to the reported qubit permutation.
4. A QFT reference test: QFT built from gates matches `Nx.fft` on the state vector, up to normalization and sign convention.

Review gate:

1. The suites are green across 3 fixed seed sets.
2. Every defect found is fixed together with a regression test.
3. `mix test.domain_coverage` stays at 100%.

### H1.5 - Adoption Launch

- Status: planned
- Intent: feature (DX and docs)
- Seats: Product marketing (owner), DX, Product strategy, Docs sync
- Depends on: H1.3 (D1)
- Target release: none (docs)

Goal:

1. Target users know NxQuantum exists and reach a first result within 10 minutes.
2. The team learns which features users actually value.

Implementation deliverables:

1. Refresh positioning according to D1:
   - update `README.md` and `docs/getting-started.md`;
   - merge `docs/decision-matrix.md` into `docs/product-positioning.md`, updating `AGENTS.md` and skill references.
2. Three Livebooks:
   - embedding NxQuantum in a supervised BEAM service;
   - researcher reproducibility (fingerprints, seeded replay, classical-baseline comparison);
   - hybrid rerank on real data if D1 keeps it as the lead message, otherwise provider lifecycle across lanes.
3. A launch write-up and Elixir Forum post based on H1.3 evidence (owner publishes).
4. A Kano survey of at least 10 target users (Elixir Forum, ElixirConf, FluxQ early users). Its results reclassify the hypotheses in `docs/vision.md` §6.
5. A joint "FluxQ powered by NxQuantum" narrative, aligned with FluxQ's positioning docs.

Review gate:

1. The claims audit passes.
2. Time-to-first-result of 10 minutes or less is measured on a clean machine (the same KPI FluxQ uses).
3. Survey results are recorded.
4. At least one external user candidate is named.

---

## Horizon 2 - Distributed Execution Engine (2027)

Entry: H1.1 and H1.2 done. Distribution here is within a single job. Orchestration across jobs stays in FluxQ.

### H2.1 - Distributed Execution Core

- Status: planned
- Intent: feature, api change (additive, experimental)
- Seats: Lead, Critic (DDD/hexagonal), DX, Quantum physics/math (seed semantics), Verifier
- Depends on: H1.1, H1.2
- Target release: 0.13.0

Goal:

1. One NxQuantum job (parameter sweep, batched estimation, shot partitioning) fans out across BEAM nodes.
2. It returns results identical to single-node execution for the same seed, and survives node loss.

Implementation deliverables:

1. ADR 0012, "Distributed execution context". It defines:
   - bounded-context ownership and within-job scope;
   - the ports;
   - the determinism model: per-task seeds derived from the job seed and task index, plus a virtual-time mode for trace determinism.
2. Ports for cluster membership, placement, and dispatch, and for virtual vs wall-clock time (*tentative*: `NxQuantum.Ports.Cluster`, `NxQuantum.Ports.Clock`).
3. Adapters: single-node, and Erlang distribution (`:erpc`, `:pg`). Both are OTP built-ins, so no new dependency is needed.
4. An experimental facade for distributed sweep and batch execution. Results carry per-task provenance: node, seed, attempt.
5. Within-job fault handling: a lost task is re-dispatched with the same seed. There is no job-level persistence (FluxQ owns that).
6. Fan-out telemetry spans with correlation ids, consumable by FluxQ.
7. Tests:
   - a feature file;
   - a property test that the same seed gives identical results on 1 vs N nodes;
   - a virtual-time test for identical event traces;
   - a node-kill test using `:peer` nodes with identical results;
   - `mix test.arch` boundary checks;
   - a `docs/bounded-context-map.md` update.
8. A throughput benchmark from 1 to 4 local peer nodes, with fixed seeds.

Review gate:

1. All deterministic tests above are green in CI.
2. The benchmark delta is published.
3. Decision D2 is recorded.

### H2.2 - Distributed Circuit Cutting

- Status: planned
- Intent: feature
- Seats: Quantum physics/math (owner), Quantum engineering, Critic, Verifier
- Depends on: H2.1 (D2 passed)
- Target release: 0.14.0

Goal:

1. Circuits larger than one simulator or device budget run as fragments across nodes and providers.
2. Results are reconstructed with a stated sampling overhead.

Implementation deliverables:

1. A physics-owned acceptance spec covering:
   - supported cut types (wire cuts first);
   - quasi-probability reconstruction;
   - the sampling-overhead formula.
2. A deterministic cut planner for a restricted circuit class, fragment execution through H2.1, and reconstruction.
3. Diagnostics: cut count, sampling overhead, per-fragment provenance.
4. Docs that state that overhead grows exponentially with the number of cuts.

Review gate:

1. Reconstructed expectations match uncut dense results within analytic tolerance on fixed fixtures of up to 12 qubits.
2. The physics seat has verified the overhead formula.
3. A benchmark against single-node execution is published.

### H2.3 - Distributed Runs in FluxQ and Launch

- Status: planned
- Intent: feature (DX and docs)
- Seats: Lead, DX, Product marketing, Verifier
- Depends on: H2.1; H2.2 for fragment views
- Target release: 0.15.0

Goal:

1. Operators run and inspect distributed NxQuantum jobs through FluxQ.
2. The first external team adopts distributed execution.

Implementation deliverables:

1. Fan-out task and fragment fields added to the H1.2 envelope snapshots, with a `schema_version` bump.
2. A multi-node Livebook demo and `docs/distributed-execution-guide.md`.
3. An external-user case study, with permission.
4. FluxQ run-detail views for fan-out, tracked in the FluxQ roadmap.

Review gate:

1. FluxQ's G2 gate is green against the new snapshots.
2. At least one external team runs distributed jobs.
3. The claims audit passes.
4. Decision D3 is recorded.

---

## Later - Horizon 3 (gated; see `docs/vision.md` §7)

| Milestone | Owner | Entry gate |
| --- | --- | --- |
| H3.1 Systems twin alpha | NxQuantum | D3 |
| H3.2 Policy testing on the twin | FluxQ | H3.1 exit |
| H3.3 Twin to live | NxQuantum | H3.1 exit, plus vendor control hooks |
| H3.4 Network control-plane exploration | FluxQ | Partner or testbed interest |

## Decision Log

| Gate | Question (see `docs/vision.md` §8) | Status | Decision and rationale |
| --- | --- | --- | --- |
| D1 | Hybrid quantum-AI stays the lead message? | pending (after H1.3) | — |
| D2 | Determinism holds under distribution? | pending (after H2.1) | — |
| D3 | Enter Horizon 3? | pending (after H2.3) | — |

Decisions already taken (2026-10-18):
- Elixir code quality is advisory, not a merge blocker.
- v0.8 is published; the repo code is the final state.
- The Qiskit C API adapter is opt-in only, and parked.
- The Clifford simulator is demand-driven, and parked.
- The control plane is FluxQ.

## Docs Consolidation Plan (executed in H1.1, 2026-10-19)

Every action requires updating references in the same change.

**Delete** (redundant):

| File | Reason |
| --- | --- |
| `docs/quantum-llm-vision.md` | Replaced by `docs/vision.md` |
| `docs/roadmap-review-2026-10-18.md`, `docs/strategy-distributed-beam-2026-10-18.md` | Proposals absorbed into `docs/vision.md` and this roadmap |
| `docs/v0.9-quantum-ai-tool-contracts.md`, `docs/v0.9-hybrid-quantum-ai-benchmark.md` | Pointer-only files (13–14 lines) |

**Rename** (living docs carrying misleading version names):

| From | To |
| --- | --- |
| `docs/v1.0-quantum-ai-tool-contracts.md` | `docs/quantum-ai-tool-contracts.md` |
| `docs/v1.0-hybrid-quantum-ai-benchmark.md` | `docs/hybrid-quantum-ai-benchmark.md` |
| `docs/v1.0-hybrid-quantum-ai-integration-guide.md` | `docs/hybrid-quantum-ai-integration-guide.md` |
| `docs/v0.9-high-value-performance-matrix.md` | `docs/performance-matrix.md` |
| `docs/v0.5-migration-packs.md` | `docs/migration-packs.md` |
| `docs/v0.5-benchmark-matrix.md` | `docs/provider-benchmark-matrix.md` |
| `docs/v0.9-quantum-ai-rollout-playbook.md` | `docs/playbooks/quantum-ai-rollout.md` |

**Merge:**

| From | Into |
| --- | --- |
| `docs/v0.5-provider-support-tiers.md`, `docs/v0.8-provider-capability-matrix.md` | `docs/provider-support-catalog.md` (name kept; FluxQ links to it) |
| `docs/decision-matrix.md` | `docs/product-positioning.md` (in H1.5, after D1) |

**Archive** to `docs/archive/` (history only). Deviation from plan: archived files stay in the HexDocs extras under their new paths, because CHANGELOG links to them would otherwise fail `mix docs.build`.
- Feature specs and plans:
  - `v0.2-feature-spec`, `v0.2-improvement-plan`, `v0.3-feature-spec`, `v0.4-feature-spec`;
  - `v0.5-feature-spec`, `v0.5-acceptance-criteria`, `v0.5-provider-implementation-plan`;
  - `v0.6-feature-spec`, `v0.6-acceptance-criteria`, `v0.6-feature-to-step-mapping`;
  - `v0.7-feature-spec`, `v0.7-acceptance-criteria`, `v0.7-feature-to-step-mapping`;
  - `v0.8-feature-spec`, `v0.8-provider-live-execution-plan`, `v0.8-compiler-implementation-plan`, `v0.8-compiler-agent-prompts`;
  - `v0.9-phase-a-sampled-scalar-plan`, `v0.9-phase-b-fused-kernel-runtime-plan`, `v0.9-phase-c-batch-gap-closure-plan`.
- Design notes and old benchmark runs:
  - `kernel-optimization-design-2026-03-23`;
  - `python-alternatives-benchmark-2026-03-21`, `-2026-03-23`, `-2026-03-23-rerun`.

Outcome: about 60 docs become about 25 living docs, plus ADRs, playbooks, and the archive. HexDocs for already-published versions keep their old URLs.

## Shipped History (condensed)

Full phase text is in git history. Status per row is pending the H1.1 audit where noted.

| Phases | Release | Theme | Status |
| --- | --- | --- | --- |
| 0–4 | pre-0.5.0 (no CHANGELOG entries) | Foundation, state-vector correctness, gradients, noise, kernels, Axon, API stabilization, CI | done |
| 5–8 | pre-0.5.0 | Estimator/Sampler primitives, batching, mitigation, transpilation, dynamic IR, Python-alternative positioning | done, except Phase 7's tensor-network path (KG-1) |
| 9–11 | 0.5.0 | Provider bridges (IBM, AWS, Azure), cross-provider normalization, OpenTelemetry, migration packs | done |
| 12 | `v0.6` label (no CHANGELOG entry) | Contract completion, adapter hardening | done |
| 13 | 0.7.0 | Versioned external contracts, observability schema governance | done |
| 14 | 0.8.0 | Live provider transport (`:fixture`/`:live_smoke`/`:live`), replay fixture capture, lifecycle envelope parity | shipped (code audited 2026-10-19); live credentialed evidence not in repo |
| 15 | 0.8.0 | Compiler `compile/2` diagnostics, routing strategies (`shortest_path`, `sabre_like`), calibration profiles, scheduling reports | partial: provider-aware transpilation adapters and side-by-side compiler narrative not found; semantic property tests missing (KG-3) |
| 16 | 0.8.0 | Custom observability metadata validation (allowlist, cardinality, redaction), correlation metadata, troubleshooting bundles, dashboards | partial: `docs/playbooks/observability.md` is 26 lines; live-provider incident playbooks not yet written |
| 17 | — | Migration Assurance Toolkit (ADR 0007) | not delivered; ADR set to Deferred; scoped `Migration.AI*` slice shipped (0.9.0) |
| 18 | 0.8.0–0.9.0 | High-value performance matrix and guards | done |
| 19–21 | 0.9.0 | AI tool contracts, hybrid benchmark pack, AI rollout gates | done (synthetic data, KG-5) |
| D1–D4 | 0.9.1 | Runtime auto-selection, fused-kernel cost, cache policy, CI guards | done |
| 22–23 | 0.11.0 (`v0.10` + `v0.11` labels) | TurboQuant rerank compression, dataset onboarding, KPI gates | done |
