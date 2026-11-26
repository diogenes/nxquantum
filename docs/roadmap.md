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
- Seat names map to agent files in `.claude/agents/` (see its README):

| Roadmap seat | Agent |
| --- | --- |
| Lead | `engineering-manager` |
| Product strategy | `product-strategist` |
| Principal architect (plan review) | `principal-architect` |
| DX | `api-dx` |
| Critic, Critic (DDD/hexagonal) | `architecture-critic` |
| Verifier | `verifier` |
| Docs sync (claims audit), Docs sync | `docs-sync` |
| Quantum physics/math | `quantum-physics-verifier` |
| Quantum engineering | `quantum-engineering` |
| Release readiness | `release-readiness` |
| Product marketing | owner (no agent) |

## Current State (0.11.0)

Strengths:
- deterministic local simulation covering 2–8 qubit workloads;
- typed provider lifecycle across IBM Runtime, AWS Braket, Azure Quantum, and Google Quantum AI (fixture, `live_smoke`, and `live` lanes);
- telemetry with OpenTelemetry-style names behind a pluggable emitter (in-process adapter only; KG-13);
- AI tool contracts;
- TurboQuant rerank.

Known gaps:

| ID | Gap | Addressed by |
| --- | --- | --- |
| KG-1 | `:tensor_network_fallback` is a routing label; no tensor-network engine executes it | Closed in H1.1: documented as routing-only (`docs/backend-support.md`, `Runtime` type comment); engine parked. PD-7 (2026-11-25): the beyond-state-vector method becomes H2.6 |
| KG-2 | Phases 14–16 were never checked off | Closed in H1.1: audit recorded in Shipped History; partial items listed there |
| KG-3 | No property tests prove compiler passes preserve semantics (Phase 15 deliverable 6); `compiler_test.exs` is example-based | Closed in H1.4: property suites and dense reference (see H1.4 Evidence) |
| KG-4 | Phase 17 Migration Assurance Toolkit not delivered | Closed in H1.1: ADR 0007 Deferred; parked (`docs/vision.md` §11) |
| KG-5 | Rerank datasets (`bench/datasets/rerank/*`) appear synthetic; manifests lack provenance | Closed 2026-10-26 by D1. Manifests carry `provenance: synthetic`, the guard test (`test/nx_quantum/hybrid_quantum_ai_benchmark_guard_test.exs`) checks provenance and CSV sha256 on both, and the docs are labeled |
| KG-6 | Cross-framework benchmarks cover 2–8 qubits against March 2026 competitor versions | first major-release timed campaign (`bench/README.md` runbook) |
| KG-7 | `ProviderBridge.Serialization` serializes envelopes, but no decode/rehydrate path was found for resuming persisted jobs (needed by FluxQ) | H1.2 |
| KG-8 | Doc sprawl: about 60 docs, version-named living docs, pointer-only duplicates | Closed in H1.1: 34 living docs in `docs/`, 24 history docs in `docs/archive/` |
| KG-9 | No git tags for published versions | H1.1 (owner action) |
| KG-10 | Simulator gate matrices and state are `complex64`. Expectation outputs are `{:f, 32}`. The precision was undocumented, and `resynthesize_1q` angles carry ~1e-7 error | Closed by decision 2026-10-25, option A (keep single precision and document the floor). Evidence: `docs/backend-support.md` "Numerical Precision", `bench/numerics_precision_floor.exs`. Reopen with an `api change` intent if an external user needs float64 agreement. Reopen proposed 2026-11-25 (PD-4): opt-in `:f64` in H2.4, default unchanged |
| KG-11 | Hybrid benchmark scripts emit fixed figures, not measurements: quality (`ndcg_at_10`, `map_at_10`, `objective_gap_to_known_best`), the TurboQuant KPIs in `bench/hybrid_quantum_ai_benchmark.exs` (`quality_drop`, `memory_bytes_per_vector`, `compression_ratio_vs_fp32`), and every `latency_fallback_impact` metric. Lanes report dataset ids they do not load: both rerank lanes report `rq_small_v1` (inline scores, or generated sin/cos embeddings unless `--dataset-path` is given), and `constrained_optimization_assistant` reports the nonexistent `co_knapsack_v1`. `bench/turboquant_rerank_benchmark.exs` computes memory and compression from the tool result | Labeled placeholder (2026-10-26); fix or remove when the real-data lane un-parks (`docs/vision.md` §11) |
| KG-12 | AI tool handlers compute classically but report `execution.mode: :quantum`: `NxQuantum.AI.run_tool/2` rerank (`lib/nx_quantum/ai/tools/kernel_rerank.ex`, sorts caller scores or TurboQuant dot products) and constrained optimization (`lib/nx_quantum/ai/tool_runner.ex`, picks the lowest-cost feasible candidate). `docs/quantum-ai-tool-contracts.md` names `constrained_optimize.v1` / `constrained_optimize.ex`, which do not exist. Changing the reported mode is an `api change` | H1.7 (PD-6). Owner: user. Status: landed on branch `feat/h1.7-kg12-execution-mode` (CI pending) |
| KG-13 | The OpenTelemetry-named observability adapter (`lib/nx_quantum/adapters/observability/open_telemetry.ex`) records spans, metrics, and logs in the process dictionary; there is no OpenTelemetry dependency or exporter, and `docs/observability.md` calls it the production emitter adapter | unassigned (owner decision) |
| KG-14 | `ProviderBridge.Serialization` raises on struct values (`Nx.Tensor`, `DateTime`, `MapSet`) in envelope payload, metadata, reason, or response (`lib/nx_quantum/provider_bridge/serialization.ex`, `stringify_value/1` → `stringify_keys/1`), contrary to `serialize/1`'s `{:ok, String.t()}` spec. A fix needs a v1 encoding decision under the Envelope Compatibility Policy | unassigned (owner decision) |
| KG-15 | The acceptance scenario 'Calibration payload provenance is normalized' (`features/provider_mitigation_calibration_contracts.feature`) asserts a constant its own step injects; `CalibrationPayload.validate/1` drops provenance | unassigned (owner decision) |
| KG-16 | `cpu_compiled` does not speed up state evolution. Both profiles build and evolve the state on Nx's default backend (`lib/nx_quantum/adapters/simulators/state_vector/state.ex`), and `cpu_compiled` then transfers the evolved state to EXLA (`lib/nx_quantum/adapters/simulators/state_vector.ex`), so only the expectation step runs on EXLA | H2.4 (PD-3) |
| KG-17 | The state-vector structure cache is capped at 4096 entries, not by bytes (`lib/nx_quantum/adapters/simulators/state_vector/cache.ex`). Each CNOT permutation is an s64 tensor of 2^n entries (`lib/nx_quantum/adapters/simulators/state_vector/matrix_library.ex`), which is 134 MB at 24 qubits, and runs of consecutive CNOTs add a composed permutation each (`lib/nx_quantum/adapters/simulators/state_vector/compiled_plan.ex`). By code reading (not measured), a 24-qubit brickwork family keeps about 25 such tensors resident, roughly 3.4 GB. The evolved-state cache has a byte cap (`lib/nx_quantum/adapters/simulators/state_vector/evolved_state_cache.ex`); this cache does not | H2.4 |
| KG-18 | In batch estimation, the first observable picks the evolution path: `Deterministic.run/3` sets `measurement: hd(observable_specs)` (`lib/nx_quantum/estimator/batch/strategies/deterministic.ex`), and `RealPauliZ` applies only to `:pauli_z` (`lib/nx_quantum/adapters/simulators/state_vector/evolution_strategy/real_pauli_z.ex`). A batch of real gates that starts with X or Y therefore takes the complex path | unassigned (owner decision) |
| KG-19 | There is no public multi-qubit Pauli observable. Observables are `:pauli_x \| :pauli_y \| :pauli_z` on a single `wire` (`lib/nx_quantum/observables.ex`, `lib/nx_quantum/estimator/observable_specs.ex`). ⟨Z_a Z_b⟩ is reachable only through the circuit identity: apply CNOT(a,b), then measure Z_b | H2.6 deliverable 2 |
| KG-20 | No public facade reports the evolution path (RealPauliZ or Complex). `Estimator.Result.metadata` has no path field (`lib/nx_quantum/estimator/result_builder.ex`), and `EvolutionStrategy` is `@moduledoc false` (`lib/nx_quantum/adapters/simulators/state_vector/evolution_strategy.ex`). The H1.3 path evidence therefore lives in a test that calls the internal selector and mirrors KG-18's rule (`test/nx_quantum/bench_evolution_path_test.exs`, merged by the bench PR) | H2.4 (evolution path in result metadata) |
| KG-21 | Sparse Z-mask observables over counts cannot be built through a documented API. `Estimator.sampled_expectation_from_counts/2` accepts `sparse_pauli: %SparsePauli{}`, but the `SparsePauli` module is `@moduledoc false` (`lib/nx_quantum/observables/sparse_pauli.ex`). For that reason the H1.3 `sampled_counts_sparse_terms` NxQuantum lane is not run | H2.6 deliverable 2 |
| KG-22 | The cache and concurrency options are undocumented, and the cache options fail open. `cache_evolved_state`, `cache_parsed_counts`, and `cache_mask_lookup_plan` are read with `Keyword.get(opts, key, true)`, so a misspelled key silently leaves the cache on. `parallel_observables`, `max_concurrency`, and `sampled_parallel_mode` are also undocumented. H1.3 cold mode depends on these options; the bench guards it with the library-reported `strategy_observability.cache_mode` on the batch path. Keeping them internal is deliberate, because documenting them is an `api change` | unassigned (owner decision) |
| KG-23 | Pre-existing boundary breach. `lib/nx_quantum/ai/tools/kernel_rerank/dataset_csv.ex` references `bench/datasets` from `lib/`, contrary to `docs/bounded-context-map.md` (bench must never be referenced from `lib/`). Fixing it needs a refactor-intent change | unassigned (owner decision; refactor) |
| KG-24 | `NxQuantum.Performance.benchmark_matrix/2` and `compare_batched_workflows/3` return modeled latency and throughput (a formula in `lib/nx_quantum/performance/model.ex`), not measurements, under "benchmark" names (`lib/nx_quantum/performance.ex`, whose moduledoc calls them "Deterministic scale/performance helpers for benchmark evidence and CI gates"). Docs must not cite them as measured. Renaming or removing them is an `api change`. H1.5 PR-1 removed the modeled figures from `docs/case-study-beam-integration.md` | unassigned (owner decision) |
| KG-25 | Unknown or misspelled options are silently ignored. For example, `Sampler.run(c, seeed: 1)` runs with the default seed (0), and `Estimator.run/2` accepts `obsrvable:` and falls back to `:pauli_z` (checked 2026-10-30). Options are not validated at the boundary, and `docs/api-stability.md` states no option-validation rule (checked 2026-10-30, after H1.5 PR-2 added the experimental tier). Fixing it is an `api change` | H1.7, phase 1 (warning), then a typed error in a later minor |
| KG-26 | `config :nx_quantum, :observability` is documented in `docs/observability.md`, but no code reads it (no `Application.get_env(:nx_quantum, :observability)` call in `lib/`) | unassigned (owner decision) |
| KG-27 | Estimator and Sampler emit no observability signals. Neither calls the `ObservabilityEmitter` port, and `lib/` has no `:telemetry` call. Only `ProviderBridge` lifecycle operations emit, through the port, when `observability: [enabled: true]` is set (`lib/nx_quantum/observability.ex`, `lib/nx_quantum/observability/profile.ex`). Users who want per-call signals wrap the calls themselves (`examples/livebook/supervised_service.livemd`) | unassigned (owner decision) |
| KG-28 | `ObservabilityEmitter` callback specs are wider than what `NxQuantum.Observability` needs. `span_start/3` is specced to return `map()` but must return `:trace_id` and `:span_id` (`lib/nx_quantum/ports/observability_emitter.ex`, `lib/nx_quantum/observability.ex`). An emitter that matches the specs and returns `%{}`, or any emitter that raises, makes `ProviderBridge.run_lifecycle/3` raise instead of returning a typed error (the `rescue` in `lib/nx_quantum/application/provider_lifecycle/dispatcher.ex` wraps only the provider call). Fixing it is an `api change` | unassigned (owner decision) |
| KG-29 | Notebooks are checked by an extractor in the test VM (`test/nx_quantum/livebooks_test.exs`), not by Livebook itself. Livebook-specific behaviour is untested: resolving the setup-cell path against the runtime working directory, and `Mix.install` resolution | unassigned (owner decision) |
| KG-30 | The Estimator `noise:` option is a scalar transform of the final expectation, not a noise channel. `Stochastic.apply_noise` (`lib/nx_quantum/estimator/stochastic.ex`, `@moduledoc false`) computes `E·(1−p_dep)·(1−γ) + γ` on the ideal value, so the result does not depend on circuit depth, gate count, or which qubits the gates touch. The `+γ` shift is the ⟨Z⟩ formula for amplitude damping, and it is applied to every observable. Checked 2026-11-25 on `main` (69d5bfc), default backend: with `noise: [depolarizing: 0.1, amplitude_damping: 0.2]`, ⟨Z⟩ is 0.92 after 1 gate and after 100 gates; after H, ⟨X⟩ with `amplitude_damping: 0.2` is 1.0, where an amplitude-damping channel gives √0.8 ≈ 0.894. `features/noise_and_shots.feature` names these "noise channels" but only checks the direction of the change. Changing the option's semantics is an `api change` | docs relabeled 2026-11-25 (`docs/model-recipes.md`); channel-based noise in H2.5 (PD-5) |

---

## Horizon 1 - Honest, Evidenced, Embeddable (Q4 2026 – Q1 2027)

Order: H1.1 first. H1.2, H1.3, and H1.4 then run in parallel. H1.5 comes after H1.3, because decision D1 shapes the messaging. H1.6 merges before any H1.3 benchmark run, so H1.3 evidence describes the upgraded stack. H1.7 (added 2026-11-25) follows H1.5 deliverable 1 and must finish before the H1.5 launch post, or the post leaves the bundled AI handlers out (PD-6).

### H1.1 - Status Truth and Docs Consolidation

- Status: done (PR #4)
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

- Status: done (merged as PR #9; FluxQ G2 wiring tracked in the FluxQ roadmap)
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

- Status: done
- Intent: performance (evidence only)
- Seats: Lead, Quantum physics/math, Verifier, Product marketing (claims audit)
- Depends on: H1.1, H1.6
- Target release: none (bench and docs)

Goal:

1. Internal speed and quality evidence rests on current, version-pinned runs with stated limits; the README makes no cross-framework speed claims (owner decision 2026-10-30).
2. The in-repo hybrid rerank evidence is labeled synthetic, and D1 is recorded.

Implementation deliverables:

1. Cross-framework harness rebuilt: pinned Python environment (`bench/requirements-python-alternatives.txt`), one scenario table, correctness gates (agreement, references, byte identity), and a defined cold mode (`bench/README.md`). Correctness evidence: `bench/results/2026-10-30-h1.3/`. The timed 3-run campaign runs at major releases (owner decision 2026-10-30) and was not run in H1.3.
2. Scenarios at 4-24 qubits (real and complex families) and a falsifiable crossover rule are defined in the scenario table; the crossover is first measured by the major-release campaign.
3. The 2026-03-25 report is kept and labeled a historical internal reference (methodology superseded); the next report comes from the major-release campaign.
4. Parked 2026-10-26 (D1); see `docs/vision.md` §11.
5. Parked 2026-10-26 (D1); see `docs/vision.md` §11.
6. Record decision D1 in the Decision Log (done 2026-10-26; see the D1 row).

Review gate:

1. Re-scoped 2026-10-30: the harness is version-pinned and correctness-gated; 3-run timed reports come from the major-release campaign.
2. The README makes no cross-framework speed claims; benchmark reports are labeled internal, environment-specific references.
3. Parked 2026-10-26 (D1); rerank datasets and hybrid figures carry the synthetic/placeholder label instead.
4. D1 is recorded with its rationale.
5. Done 2026-10-30 (`docs/vision.md` §6, §11, §13).

### H1.4 - Compiler Correctness Suite

- Status: done (fixes landed; see CHANGELOG `[Unreleased]`)
- Intent: feature (verification)
- Seats: Quantum physics/math (acceptance owner), Critic, Verifier
- Depends on: H1.1
- Target release: 0.12.0

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

Evidence (2026-10-25):

- Acceptance suites: `test/property/gate_identity_property_test.exs`, `test/property/compiler_semantic_equivalence_property_test.exs`, `test/property/transpiler_routing_equivalence_property_test.exs`, `test/nx_quantum/qft_reference_test.exs`.
- Gate-identity catalogue (deliverable 1): `test/support/gate_identities.ex`, one entry per pass.
- Oracle: `test/support/dense_reference.ex`, a dense unitary reference that does not reuse the production matrix library. It is validated by the identity catalogue and by the QFT test.
- Three fixed seed sets per suite (`test/support/random_circuits.ex`). Circuits have up to 6 qubits.
- Defects found and fixed, each with a regression test:
  1. `insert_swaps` left a non-native CNOT on an uncoupled edge and did not rewrite later gates through the qubit layout. Routing now rewrites the CNOT onto the routed edge and reports `logical_to_physical_map` (`lib/nx_quantum/transpiler/router.ex`; `test/nx_quantum/transpiler_test.exs`).
  2. `simplify` raised on batched (non-scalar) rotation angles (`lib/nx_quantum/compiler/theta.ex`; `test/nx_quantum/compiler_test.exs`).
  3. The routing feature steps asserted only key presence or accepted `nil`. They now check the routed CNOT wires and the routing path (`test/features/steps/topology_transpilation_steps.ex`).
- Gates: `mix quality`, `mix dialyzer`, `mix test.domain_coverage` (100.00%), and `mix test` (350 tests, 0 failures) were green.
- Precision limit found: `resynthesize_1q` is held to its documented `resynthesis_tolerance` (1e-6), not 1e-9. See KG-10.

### H1.5 - Adoption Launch

- Status: in progress
- Intent: feature (DX and docs)
- Seats: Product marketing (owner), DX, Product strategy, Docs sync
- Depends on: H1.3 (D1)
- Target release: none (docs)

Goal:

1. Target users know NxQuantum exists and reach a first result within 10 minutes.
2. The team learns which features users actually value.

Implementation deliverables:

1. Refresh positioning according to D1:
   - update `README.md` and `docs/getting-started.md` (the `README.md` and `docs/product-positioning.md` lead were updated in the D1 slice, 2026-10-26; `docs/getting-started.md` and the decision-matrix merge stay open here);
   - merge `docs/decision-matrix.md` into `docs/product-positioning.md`, updating `AGENTS.md` and skill references.
   - Done in PR-1 (2026-10-30): `docs/getting-started.md` and the README Quick Start lead with the Hex path; the decision matrix is merged into `docs/product-positioning.md`, with `docs/decision-matrix.md` kept as a pointer stub; skill and agent references are updated. The `AGENTS.md` reading row was updated and the stub removed on 2026-11-25, with PD-1.
2. Three Livebooks:
   - embedding NxQuantum in a supervised BEAM service;
   - researcher reproducibility (fingerprints, seeded replay, classical-baseline comparison);
   - provider lifecycle across lanes (fixture lane; live lanes stay env-gated).
3. A launch write-up and Elixir Forum post based on H1.2/H1.4/H1.6 evidence (owner publishes).
4. A Kano survey of at least 10 target users (Elixir Forum, ElixirConf, FluxQ early users). Its results reclassify the hypotheses in `docs/vision.md` §6.
5. A joint "FluxQ powered by NxQuantum" narrative, aligned with FluxQ's positioning docs.

Review gate:

1. The claims audit passes.
2. Time-to-first-result of 10 minutes or less is measured on a clean machine (the same KPI FluxQ uses).
3. Survey results are recorded.
4. At least one external user candidate is named.

### H1.6 - Dependency Currency

- Status: done
- Intent: api change (PR-A: dependency floor `nx ~> 1.0`; no function, type, or envelope change intended), refactor (PR-B: toolchain)
- Seats: Lead, Principal architect (plan review), DX, Critic, Verifier, Docs sync, Quantum physics/math
- Depends on: H1.1
- Target release: 0.12.0 (together with the H1.2 and H1.4 changes in `[Unreleased]`)

Goal:

1. NxQuantum builds, tests, and releases against the latest stable Nx ecosystem and Elixir/OTP toolchain.
2. Numerics, determinism, and envelope contracts are unchanged within the tolerances in the review gate.

Implementation deliverables:

1. PR-A, dependencies, on the current toolchain (Elixir 1.19 / OTP 28):
   - first commit, before the bump: make the backprop finite-difference check in `test/nx_quantum/grad_test.exs` compare against the analytic derivative (−sin θ) with a well-conditioned step; the physics seat confirms step and tolerance from an error measurement on the current lock (proposed: ε = 1e-3, tolerance 1e-4; the physics seat set ε = 3e-3, tolerance 1e-4);
   - `mix.exs`: `nx ~> 1.0`; optional `axon` removed (no call site; critic R3), optional `exla ~> 1.0`, `torchx ~> 1.0`; dev and test dependencies at latest stable; `mix.lock` regenerated;
   - Styler reformatting in its own commit (not needed: no reformatting was required, so no such commit exists);
   - `bench/numerics_digest.exs`: bit digests of optimized ops, expectations, the float64 reference, sampler counts, gradients, and the kernel.
2. PR-B, toolchain: `mise.toml`, `.github/workflows/ci.yml`, and `.github/workflows/release.yml` move to Elixir 1.20.4 / OTP 29.1.2; fix new compiler and type-checker warnings; keep a CI floor leg on Elixir 1.19 / OTP 28 (compile with warnings as errors, `mix test`) while `mix.exs` declares `elixir: "~> 1.19"`.
3. Evidence: `bench/results/<run-date>-h1.6/` holds digests and precision-floor outputs for three states (before, after PR-A, after PR-B), two runs each, plus a summary table (artifact, reference, pre SHA, post SHA, identical, max abs Δ, tolerance). Rerun the `docs/backend-support.md` "Numerical Precision" table with the new date and versions.
4. Docs: a CHANGELOG `[Unreleased]` "Changed" entry with a migration note for consumers on Nx 0.x; a "Dependency Policy" section in `docs/api-stability.md`; a "Requirements" line in `README.md`; a release-cut check in `docs/release-process.md` (`mix hex.outdated` shows no runtime dependency behind latest stable).
5. FluxQ: `mix test` green against PR-A, run on a scratch copy of FluxQ with its path dependency pointed at PR-A. The FluxQ lock update (Nx 1.0, complex 1.x) is tracked in the FluxQ roadmap.

Review gate:

1. For both PRs: `mix quality`, `mix dialyzer`, `mix test`, `NXQ_ENABLE_EXLA=1 mix test`, `mix test.property`, `mix test.features`, `mix test.domain_coverage` (100%), `mix test.provider_smoke`, `mix test.release_evidence`, `mix docs.build`, and `mix hex.build` are green. The `mix bench.batch_obs_guard` before/after delta is recorded.
2. Envelope snapshots pass unchanged, without regeneration. Ids are hashed from `:erlang.term_to_binary(_, [:deterministic])`, which OTP keeps stable only within a major release; any id or envelope byte change stops the work as an envelope contract change.
3. BinaryBackend numerics: digests and the precision table are byte-identical. If bits move, the cause is named, and every row stays at or below 1e-6 absolute against the float64 reference; a row above 5.0e-7 updates the documented floor. Parameter-shift and adjoint gradients stay within 1e-6 of the analytic value. `expectation/2` output stays `{:f, 32}`. Two runs per state are byte-identical.
4. Seeded sampling counts are byte-identical. A change needs a named OTP cause and a documented D2 re-baseline.
5. A diff audit shows no loosened test tolerance, no changed seed, and no regenerated snapshot.
6. Fresh-clone first-compile time with EXLA 1.0 is recorded (input to the H1.5 time-to-first-result target).

### H1.7 - Claims and Option Hygiene

- Status: planned
- Intent: api change
- Seats: Lead, DX, Critic, Verifier, Docs sync (claims audit)
- Depends on: H1.5 deliverable 1
- Target release: 0.12.0 if the owner decides PD-6 before the release cut; otherwise 0.13.0, and the launch post leaves the bundled AI handlers out (PD-6)

Goal:

1. No result reports a quantum execution mode for a classical computation (KG-12).
2. A misspelled option can no longer silently change a seeded result (KG-25). This starts with the options that decide reproducibility: `seed`, `shots`, `observable`, `wire`, `runtime_profile`, and `noise`.

Implementation deliverables:

1. KG-12: the bundled rerank and constrained-optimization handlers report `execution.mode: :classical` (`lib/nx_quantum/ai/tools/kernel_rerank.ex`, `lib/nx_quantum/ai/tool_runner.ex`). The change follows the versioning rule in `docs/quantum-ai-tool-contracts.md`, and that document's references to the nonexistent `constrained_optimize.v1` / `constrained_optimize.ex` are corrected.
2. KG-25, phase 1: `Estimator.run/2`, `Estimator.expectation_result/2`, and `Sampler.run/2` validate option keys at the boundary against a declared schema that includes the internal cache and concurrency keys (KG-22). An unknown key adds a typed warning to result metadata and logs once (*tentative*: `lib/nx_quantum/options.ex`). Phase 2, a typed error, is a later minor release with a CHANGELOG migration note.
3. Docs: an option-validation rule in `docs/api-stability.md`; `docs/product-positioning.md` §8 and §11 updated; the launch draft checklist gains the PD-6 item.

Review gate:

1. A contract test fails if any bundled AI handler reports `:quantum` without a simulator or provider call (*tentative*: `test/nx_quantum/ai/execution_mode_truth_test.exs`).
2. A property test over generated misspellings of `seed`, `shots`, and `observable` shows every call returns the warning and none silently runs with the default seed.
3. `mix quality`, `mix dialyzer`, and `mix test.domain_coverage` (100%) are green. Provider envelope snapshots are unchanged.

---

## Horizon 2 - Credible Engine and Deterministic Scale-Out (2027)

Entry: H1.1 and H1.2 done. Distribution here is within a single job. Orchestration across jobs stays in FluxQ.

Restructured on 2026-11-25 by the strategy review (decisions PD-2 to PD-13). H2 used to be distribution only. It now has two tracks, because a reproducibility guarantee only matters on an engine that can run the circuit and model its noise:

1. **Engine track:** H2.4 (engine v2 and the float64 option), H2.8 (OpenQASM 3), H2.5 (noise channels and deterministic trajectories).
2. **Differentiator track:** H2.1 (deterministic ensemble executor), H2.7 (mitigation checked against a noisy reference), H2.6 (Pauli-propagation estimator), H2.9 (Hamiltonian simulation, SQD, SKQD). H2.3 closes the horizon with FluxQ and a launch.

H2.2 (distributed circuit cutting) moved to Parked (PD-8; `docs/vision.md` §11). Its id is retired.

Planned sequence (one engineer fluent in Nx; the dates are a plan, not a commitment):

| Window | Milestones | Target release | Exit evidence |
| --- | --- | --- | --- |
| Q1 2027 | H1.7, H2.4, H2.8 | 0.13.0 | 24-qubit internal evidence with tolerances; float64 mode; OpenQASM round trip |
| Q2 2027 | H2.5, H2.1 | 0.14.0 | Noisy counts byte-identical across workers; D2 recorded |
| Q3 2027 | H2.7, H2.6 | 0.15.0 | Mitigation green against the density-matrix reference; Pauli propagation within its reported error |
| Q4 2027 | H2.9, H2.3 | 0.16.0 | SKQD matches exact diagonalization; one external team on distributed jobs; D3 recorded |

Where each milestone builds an edge (the factors are the rows of the strategy canvas in `docs/vision.md` §6):

| Milestone | Edge it builds | Proof artifact |
| --- | --- | --- |
| H2.4 | Single-device scale and precision reach "credible" | `bench/results/<date>-h2.4/`, float64 cross-check |
| H2.8 | Tier-2 reach; one circuit source for the cross-framework harness | Imported-corpus agreement test |
| H2.5 | Noise fidelity; reproducibility under noise | Channel closed-form tests; byte-identical counts across batch sizes and workers |
| H2.1 | Deterministic, fault-tolerant fan-out | 1 vs N nodes and node-kill tests; D2 |
| H2.7 | Mitigation checked against an exact noisy reference | CI suite against the H2.5 density-matrix executor |
| H2.6 | Simulability diagnostics with a reported error | Agreement within reported truncated weight; 100-qubit fixture |
| H2.9 | Sampling plus heavy classical post-processing in one supervised runtime | SKQD vs exact diagonalization; Livebook |
| H2.3 | Adoption | One external team; D3 |

Every milestone below that starts from a paper records the research-intake checklist (`docs/vision.md` §12) in its plan review. The candidates and their falsifiable hypotheses are in `docs/research/algorithm-landscape-2025-2026.md`.

### H2.4 - State-Vector Engine v2

- Status: planned
- Intent: performance, api change (additive, experimental `precision` option)
- Seats: Lead, Quantum physics/math, Critic, DX, Verifier (benchmark), Docs
- Depends on: H1.6
- Target release: 0.13.0

Goal:

1. State evolution runs as compiled, fused programs on the selected backend, including EXLA on host CPU or one GPU. This closes KG-16 (PD-3).
2. Users can opt into float64 (`precision: :f64`) with documented accuracy, while the `{:f, 32}` default is unchanged (PD-4).
3. Internal, tolerance-checked evidence reaches 24 qubits on one device (baseline 8; `docs/vision.md` §14).

Implementation deliverables:

1. A fusion pass over the compiled plan: greedy fusion into dense k-qubit blocks (k configurable, default 4), with diagonal runs fused separately. It reuses the `CompiledPlan` and `KeyEncoder` cache keys (*tentative*: `lib/nx_quantum/adapters/simulators/state_vector/fusion.ex`).
2. One `defn` program per compiled plan, compiled with the runtime profile's compiler, with the state created on that profile's backend (closes KG-16).
3. A leading batch axis (`Nx.vectorize`) for parameter sweeps and kernel rows, used by the Estimator batch strategies and later by H2.5 trajectories.
4. `precision: :f32 | :f64` (experimental tier in `docs/api-stability.md`): `complex64` and `{:f, 32}` by default, `complex128` and `{:f, 64}` on request.
5. A fused adjoint gradient that keeps two states, so memory is O(2^n) instead of one state per gate (`lib/nx_quantum/grad/adjoint.ex`).
6. A byte cap on the structure cache (closes KG-17), and the evolution path reported in result metadata (additive; closes KG-20).
7. A benchmark of 12–24-qubit brickwork and QAOA families, before and after, on `cpu_portable`, `cpu_compiled`, and `nvidia_gpu_compiled` when available, with fixed seeds and 3 runs (*tentative*: `bench/engine_v2.exs`).
8. Docs: the `docs/backend-support.md` precision table rerun in both modes, plus a 20-qubit float64 cross-check against the pinned Python harness, labeled an internal reference.

Review gate:

1. On the default path (BinaryBackend, `:f32`), all existing suites pass unchanged. Numerics digests are byte-identical, or every moved bit is explained under the H1.6 rule. Envelope snapshots are unchanged.
2. A property test shows fused and unfused evolution agree within 1e-6 (`:f32`) and 1e-12 (`:f64`) on random circuits up to 10 qubits, over 3 fixed seed sets (*tentative*: `test/property/fusion_equivalence_property_test.exs`).
3. The fused adjoint matches parameter-shift gradients within 1e-10 in `:f64` mode on the gradient fixtures.
4. The benchmark delta is published under `bench/results/<date>-h2.4/` with its environment, and the item-1 hypothesis in the research intake is recorded as passed or failed.

### H2.8 - OpenQASM 3 Interop (Subset)

- Status: planned
- Intent: feature, api change (additive, experimental)
- Seats: Lead, DX, Quantum engineering, Critic, Verifier, Docs
- Depends on: H1.4 (dense reference)
- Target release: 0.13.0

Goal:

1. A researcher can import an OpenQASM 3 circuit written for another framework, run it in NxQuantum, and export it back (tier-2 reach, PD-13).
2. The cross-framework harness reads one OpenQASM file per scenario instead of re-encoding each circuit per framework.

Implementation deliverables:

1. A documented OpenQASM 3 subset: qubit and bit declarations, the `stdgates.inc` gates that NxQuantum supports, angle parameters, and measurement. Everything else returns a typed error naming the construct; nothing is dropped silently (*tentative*: `lib/nx_quantum/interop/open_qasm3.ex`).
2. `Circuit.from_qasm/2` and `Circuit.to_qasm/2` in the experimental tier.
3. A parser in pure Elixir with no new dependency; any dependency needs architecture ownership and a justification (AGENTS.md stop rule).
4. A fixture corpus exported from Qiskit, Cirq, and PennyLane by the pinned harness (`bench/requirements-python-alternatives.txt`), checked in with provenance.

Review gate:

1. Round trip: `to_qasm` then `from_qasm` gives a circuit equal to the original up to global phase (dense reference), on random circuits up to 6 qubits over 3 seed sets.
2. Each imported corpus circuit matches the exporting framework's state vector within 1e-6 (`:f32`), or 1e-10 (`:f64`) once H2.4 ships.
3. Every unsupported construct in the corpus returns a typed error that names it.

### H2.5 - Noise Channels and Deterministic Trajectories

- Status: planned
- Intent: feature, api change (additive; deprecates the scalar `noise:` option)
- Seats: Lead, Quantum physics/math (acceptance owner), Critic, DX, Verifier, Docs
- Depends on: H2.4 (batch axis and `:f64`)
- Target release: 0.14.0

Goal:

1. Gate-level noise behaves like the channels it names, checked against an exact density-matrix reference. This closes KG-30 (PD-5).
2. Noisy shot counts are byte-identical for the same seed, whatever the batch size and worker count.

Implementation deliverables:

1. A `NoiseModel` with per-gate and per-qubit channels: depolarizing, amplitude damping, phase damping, Pauli channel, and readout. Channels are checked for Kraus completeness when built (*tentative*: `lib/nx_quantum/noise/`).
2. A density-matrix executor for up to about 12 qubits in `:f64`, run as a doubled state vector on the H2.4 kernels. It is documented as a reference, not a scale path (*tentative*: `lib/nx_quantum/adapters/simulators/density_matrix.ex`).
3. A trajectory executor (*tentative*: `lib/nx_quantum/adapters/simulators/trajectories.ex`):
   - for Pauli and other unitary-mixture channels, error patterns are sampled per shot before evolution, with seeds derived from the job seed and shot index; identical patterns are grouped and each unique pattern runs once on the batch axis, weighted by its count (the PTSBE approach);
   - for general channels, a per-trajectory fallback samples Kraus operators during evolution.
4. A `noise_model:` option on the Estimator and Sampler (experimental tier). The scalar `noise:` option keeps working, warns that it is deprecated, and stays documented as scalar; removing it is a later `api change`.
5. The seed derivation is shared with ADR 0012 (`seed_derivation: v1`), so H2.1 can distribute trajectories without changing results.
6. `features/noise_channels.feature`, and the "noise channels" wording in `features/noise_and_shots.feature` corrected to "scalar noise model".

Review gate:

1. Single-qubit channels match closed forms within 1e-12 in `:f64`. For example, amplitude damping with rate γ on |+⟩ gives ⟨X⟩ = √(1−γ).
2. Trajectory estimates match the density-matrix result within a stated 3σ statistical bound on fixed 4–10-qubit fixtures (GHZ, one QAOA layer), with fixed seeds.
3. Counts are byte-identical across batch sizes 1, 64, and 1024, and across `max_concurrency` 1 and 8, for the same seed.
4. The item-2 hypothesis in the research intake (unique patterns vs shots at p ≤ 1e-3) is recorded as passed or failed.
5. The physics seat signs off the channel definitions and tolerances.

### H2.1 - Distributed Execution Core

- Status: planned
- Intent: feature, api change (additive, experimental)
- Seats: Lead, Critic (DDD/hexagonal), DX, Quantum physics/math (seed semantics), Verifier
- Depends on: H1.1, H1.2; H2.4 (batch axis) for batched tasks
- Target release: 0.14.0

Goal:

1. One NxQuantum job's ensemble work fans out across BEAM nodes: parameter sweeps, batched estimation, and shot partitions first, then noisy trajectories (H2.5) and Pauli-propagation partitions (H2.6) through the same task contract (PD-2).
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
7. Ordered reduction: partial results are reduced in task-index order, because floating-point sums are not associative.
8. Tests:
   - a feature file;
   - a property test that the same seed gives identical results on 1 vs N nodes;
   - a virtual-time test for identical event traces;
   - a node-kill test using `:peer` nodes with identical results;
   - `mix test.arch` boundary checks;
   - a `docs/bounded-context-map.md` update.
9. A throughput benchmark from 1 to 4 local peer nodes, with fixed seeds.

Review gate:

1. All deterministic tests above are green in CI.
2. The benchmark delta is published.
3. Decision D2 is recorded.

### H2.7 - Error Mitigation v2, Checked Against a Noisy Reference

- Status: planned
- Intent: feature, api change (additive)
- Seats: Lead, Quantum physics/math (acceptance owner), Quantum engineering, Critic, Verifier, Docs
- Depends on: H2.5
- Target release: 0.15.0

Goal:

1. Mitigation goes beyond linear ZNE, and every pass reports error bars and its overhead.
2. Every pass is regression-tested in CI against the H2.5 density-matrix reference (PD-5).

Implementation deliverables:

1. Richardson and polynomial least-squares extrapolators with propagated error bars (*tentative*: `lib/nx_quantum/mitigation/passes/zne_richardson.ex`, `lib/nx_quantum/mitigation/passes/zne_poly_ls.ex`).
2. Noise scaling by gate folding (global and local) and, in simulator lanes, by amplifying channel rates in the `NoiseModel`.
3. Seeded Pauli twirling as a compiler pass, with a seed derived per circuit instance (*tentative*: `lib/nx_quantum/compiler/passes/pauli_twirl.ex`).
4. Probabilistic error cancellation for Pauli channels, with the sampling overhead γ reported in results.
5. A mitigation validation playbook in `docs/playbooks/`. Provider lanes apply the same passes to live results, with no determinism claim.

Review gate:

1. On fixed noisy fixtures of up to 8 qubits, each pass reduces the absolute error against the noiseless value by its stated factor, and its error bar covers the true value in at least 95% of 200 seeded repetitions (item-6 hypothesis in the research intake).
2. Twirled circuits equal the original up to global phase (property test against the dense reference).
3. The reported PEC overhead matches the analytic γ for the fixture channel within 1e-9.

### H2.6 - Pauli-Propagation Estimator

- Status: planned
- Intent: feature, api change (additive, experimental)
- Seats: Lead, Quantum physics/math (acceptance owner), Critic (DDD/hexagonal), DX, Verifier, Docs
- Depends on: ADR 0013 accepted; H2.4 for state-vector cross-checks; H2.5 for the noisy mode
- Target release: 0.15.0

Goal:

1. Estimator users can compute expectation values beyond state-vector width for shallow or noisy circuits, with a reported truncation error (PD-7).
2. Users can check whether a model's expectation values are classically simulable at a chosen error: a simulability diagnostic.

Implementation deliverables:

1. ADR 0013 accepted: an expectation-level simulation-method port with declared capabilities. The state-vector adapter implements it without behaviour change.
2. Public multi-qubit Pauli observables: `SparsePauli` becomes a documented type (closes KG-19 and KG-21).
3. The engine: Pauli strings packed as x and z bitmasks; Clifford conjugation by bit operations; branching on Pauli rotations; merging duplicates by sort and segment sum; truncation by coefficient magnitude and Pauli weight (*tentative*: `lib/nx_quantum/adapters/simulators/pauli_propagation.ex`).
4. Noise as Pauli damping for the depolarizing and dephasing channels of the H2.5 `NoiseModel`.
5. Result metadata: truncated weight, peak live terms, and the truncation thresholds used.
6. Method selection through `Estimator.run/2` options; partitions exposed as fan-out tasks for H2.1.
7. Parameter-shift gradients on this backend. Reverse mode is a follow-up.

Review gate:

1. Without truncation, results agree with the state vector within 1e-10 (`:f64`) on random Clifford-plus-rotation circuits up to 12 qubits, over 3 seed sets.
2. With truncation, the error against the state vector stays within the reported truncated weight on fixtures up to 20 qubits.
3. The item-3 hypothesis in the research intake (100-qubit kicked Ising) is recorded as passed or failed.
4. The same circuit and options give byte-identical term lists across runs and across partition counts.

### H2.9 - Hamiltonian Simulation and Sample-Based Diagonalization

- Status: planned
- Intent: feature, api change (additive, experimental)
- Seats: Lead, Quantum physics/math (acceptance owner), Critic, DX, Verifier, Docs
- Depends on: H2.4 (`:f64`, batching); H2.6 deliverable 2 (public `SparsePauli`)
- Target release: 0.16.0

Goal:

1. Users can build time-evolution circuits from a Pauli Hamiltonian, with a reported Trotter error bound (PD-7).
2. Users can run SQD and SKQD workflows end to end: seeded sampling, configuration recovery, projection, and diagonalization, on the simulator or through the provider lifecycle.

Implementation deliverables:

1. A Pauli-evolution gate, first- and second-order Trotter product formulas with commutator-based error bounds, and qDRIFT with seeded sampling (*tentative*: `lib/nx_quantum/hamiltonian/`).
2. An SQD workflow: bitstring deduplication on packed integers, configuration recovery for particle-number-conserving problems, the projected Hamiltonian as a sparse matrix, `Nx.LinAlg.eigh` for small subspaces, and Lanczos for larger ones (*tentative*: `lib/nx_quantum/algorithms/sqd.ex`).
3. An SKQD workflow that samples Krylov states U^k|ψ0⟩ (*tentative*: `lib/nx_quantum/algorithms/skqd.ex`).
4. Batches exposed as fan-out tasks for H2.1.
5. A Livebook: the transverse-field Ising ground state by SKQD, compared with exact diagonalization.

Review gate:

1. Trotter evolution matches exact matrix exponentiation within the reported bound on fixtures up to 10 qubits (`:f64`).
2. SKQD on the transverse-field Ising chain matches the exact ground energy within 1e-6 (relative) up to 16 qubits (item-5 hypothesis in the research intake).
3. SQD results are byte-identical for the same seed across batch partitionings.

### H2.3 - Distributed Runs in FluxQ and Launch

- Status: planned
- Intent: feature (DX and docs)
- Seats: Lead, DX, Product marketing, Verifier
- Depends on: H2.1; H2.5 for the noisy-trajectory demo
- Target release: 0.16.0

Goal:

1. Operators run and inspect distributed NxQuantum jobs through FluxQ.
2. The first external team adopts distributed execution.

Implementation deliverables:

1. Fan-out task fields added to the H1.2 envelope snapshots, with a `schema_version` bump.
2. A multi-node Livebook demo: one seeded noisy-trajectory job across local peer nodes, with counts identical to a single-node run, that survives a node kill. Plus `docs/distributed-execution-guide.md`.
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
| H3.0 Stabilizer and Pauli-frame sampling with detector-error-model export (added 2026-11-25, PD-7; interop first, real-time decoding stays a non-goal) | NxQuantum | A named QEC user, or H3.1 planning after D3; H2.5 done |
| H3.1 Systems twin alpha | NxQuantum | D3; H2.5 (decoherence models) and H3.0 (decoders as processes) |
| H3.2 Policy testing on the twin | FluxQ | H3.1 exit |
| H3.3 Twin to live | NxQuantum | H3.1 exit, plus vendor control hooks |
| H3.4 Network control-plane exploration | FluxQ | Partner or testbed interest |

## Decision Log

| Gate | Question (see `docs/vision.md` §8) | Status | Decision and rationale |
| --- | --- | --- | --- |
| D1 | Hybrid quantum-AI stays the lead message? | decided 2026-10-26 (owner): no | Hybrid quantum-AI becomes an application of the pillars and the lead becomes "deterministic quantum execution on BEAM", because the primary audience is BEAM/Nx teams embedding quantum workloads in their services (`docs/vision.md` §4), whom the Trust and Contracts pillars (§5) serve directly. Decided before H1.3 finished: no real-data evaluation was run, and "no" is the branch taken without that evidence. The in-repo rerank datasets are synthetic (KG-5), benchmarks are internal performance references rather than official results (owner, 2026-10-26), and the real-data rerank lane is parked (`docs/vision.md` §11); D1 reopens on that row's trigger. FluxQ needs no change: its `AGENTS.md` has no hybrid quantum-AI invariant (checked 2026-10-26). The vision §13 item 6 competitor recheck moves to the H1.3 benchmark refresh. The AGENTS.md messaging invariant was updated with owner approval on 2026-10-30. |
| D2 | Determinism holds under distribution? | pending (after H2.1) | — |
| D3 | Enter Horizon 3? | pending (after H2.3) | — |

Decisions already taken (2026-10-18):
- Elixir code quality is advisory, not a merge blocker.
- v0.8 is published; the repo code is the final state.
- The Qiskit C API adapter is opt-in only, and parked.
- The Clifford simulator is demand-driven, and parked.
- The control plane is FluxQ.

Decisions already taken (2026-10-25):
- Dependency policy: track the latest stable Nx ecosystem and Elixir/OTP releases, checked at each minor release cut (H1.6; `docs/api-stability.md`).

Decisions already taken (2026-10-30, owner):
- The README makes no cross-framework speed claims; benchmark reports are internal, environment-specific references ("Drop them.").
- The timed cross-framework comparison runs at major releases only ("Performance runs I consider necessary only on major releases, to ensure we're not breaking stuff."). This does not relax the AGENTS.md rule that non-trivial performance changes include reproducible benchmark evidence. What counts as a major release while on 0.x is an open owner question.
- The AGENTS.md messaging invariant (line 12) is approved as worded ("Approved.").
- H1.3 closes without a timed run; KG-6 stays open until the first major-release campaign.

### Proposed decisions (strategy review 2026-11-25; owner decides)

Inputs: `docs/research/algorithm-landscape-2025-2026.md` and the claims audit that found KG-30. Each row becomes `decided` only with the owner's approval, recorded with its date. Milestone ids marked *(roadmap update)* were created by the roadmap update of the same date (H1.7, H2.4 to H2.9, H3.0, ADR 0013).

| Id | Proposal | Rationale | Creates or changes | Status |
| --- | --- | --- | --- | --- |
| PD-1 | Refine D1's lead to "Deterministic quantum simulation and execution on BEAM", with the proof line "same seed, same result, across repeat runs and Nx/OTP upgrades today; across nodes after D2". Retire "the standard parallel quantum computing simulation library" everywhere, including external descriptions (GitHub About, Hex description, project pages). Widen the secondary audience to researchers who need regression-grade reproducibility | "Execution" hides the simulator, which is what most users run. "For Elixir and Nx teams" names the runtime, not the job. "Standard" is unearned (no documented external user). The widened audience is reachable once noise, float64, and OpenQASM ship | `docs/product-positioning.md` §1–§3, `docs/vision.md` §1 and §4, README lead, `mix.exs` description, AGENTS.md messaging invariant (owner approval required) | applied by the separable "PD-1" commit of the 2026-11-25 review; decided when the owner merges it |
| PD-2 | "Parallel" means deterministic ensemble parallelism: shots, trajectories, sweeps, parameter-shift terms, observable partitions. Multi-node exact state-vector simulation stays a non-goal | Interconnect bandwidth, not arithmetic, bounds distributed state vectors (arXiv:2511.14664, arXiv:2609.34369), which favours MPI and NCCL stacks. Ensemble work moves results, not amplitudes, which suits Erlang distribution and supervision | `docs/vision.md` §1, §5, §10 item 3; `docs/product-positioning.md` §11 | proposed |
| PD-3 | Single-device acceleration through EXLA (host CPU or one GPU) is in scope; only multi-node and HPC-scale exact simulation stay out | "Not targeted: GPU-scale simulation" grouped two different things. With KG-16, `cpu_compiled` does not accelerate state evolution at all, so no scale claim is credible yet | `docs/vision.md` §4 and §10; engine v2 milestone H2.4 *(roadmap update)* closes KG-16 | proposed |
| PD-4 | Reopen KG-10: add an opt-in `precision: :f32 \| :f64` option (additive, experimental). Keep `:f32` the default until a benchmark sets the cost of float64; changing the default is a later `api change` | Richardson and least-squares extrapolation amplify input error; eigen-solvers in SQD need float64; cross-framework checks need 1e-6 tolerances today. Opt-in keeps the `{:f, 32}` contract intact | KG-10 reopened; H2.4 *(roadmap update)* | proposed |
| PD-5 | Replace the scalar `noise:` model with channel-based noise: a `NoiseModel` of Kraus and Pauli channels, a deterministic batched-trajectory executor (sample error patterns first, group identical ones), and a density-matrix executor of up to about 12 qubits used as a test oracle. Keep `noise:` working until the new API ships, then deprecate it (`api change`). Check mitigation passes against the oracle in CI | KG-30. PTSBE (arXiv:2504.16297, SC '25) shows pattern-first sampling is both fast and naturally seedable. Mitigation cannot be validated without simulated noise | KG-30 closed by H2.5; mitigation v2 H2.7 *(roadmap update)* | proposed |
| PD-6 | Resolve KG-12 before the H1.5 launch post: report the real execution mode of the bundled AI handlers (`api change`), or keep them out of launch messaging. Recommended: report the real mode | For a product whose value is trust, a result labelled `:quantum` that was computed classically undercuts every other claim | H1.7 claims hygiene *(roadmap update)*; H1.5 deliverable 3 waits for it | proposed |
| PD-7 | Parked list (`docs/vision.md` §11): un-park Krylov/Lanczos time evolution as Hamiltonian primitives plus SQD/SKQD workflows. Keep the tensor-network engine parked; a Pauli-propagation estimator becomes the beyond-state-vector method (and the eventual target of `:tensor_network_fallback` routing, an `api change`). Keep the Clifford/stabilizer simulator demand-gated, scoped interop-first (detector-error-model export, decoder port), and listed as an H3.1 prerequisite | SQD/SKQD are among the most visible pre-fault-tolerant workflows of 2025–2026 (Science Advances 11, eadu9991; arXiv:2501.09702). Pauli propagation reuses `SparsePauli`, is deterministic by construction, and partitions cleanly (arXiv:2505.21606). Stim already owns stabilizer speed | H2.6 and H2.9 *(roadmap update)*; `docs/vision.md` §7 and §11 | proposed |
| PD-8 | Move H2.2 (distributed circuit cutting) to Parked. Trigger to un-park: a named user with circuits beyond one device, and D2 passed. H2 capacity goes to ensemble workloads | Cutting has sampling overhead that grows exponentially with the number of cuts, no user has asked for it, and the ensemble workloads above serve both audience tiers | H2.2 removed from the roadmap; `docs/vision.md` §11 row | proposed |
| PD-9 | 2027 investment allocation: 15% H1 completion, 45% engine credibility, 30% differentiators, 10% H3 spikes | H1 is nearly done (only H1.5 is open). Without engine credibility the differentiators have nothing to run on | `docs/vision.md` §9 | proposed |
| PD-10 | Accept `docs/research/algorithm-landscape-2025-2026.md` as research-intake input. Each milestone that uses it records the §12 checklist in its plan review, and the physics/math seat confirms each source then | `docs/vision.md` §12 requires a verified source, competitor status, workflow, and a falsifiable hypothesis for every paper-derived item | `docs/research/` | proposed |
| PD-11 | Kano instrument v1.1: add F13–F16 (seed-reproducible noisy trajectories, float64 agreement, classical-simulability check, OpenQASM 3 round trip) before fielding | The survey has not been fielded, so adding items is cheap, and it tests the roadmap before it is built | `docs/research/kano-survey-h1.5.md`, `docs/vision.md` §6 | proposed |
| PD-12 | Add ADR 0013, a simulation-method port that is not amplitude-based, before any non-state-vector method | `Ports.Simulator.apply_gates/3` returns amplitudes; Heisenberg-picture and stabilizer methods cannot implement it (`docs/vision.md` §11 Clifford row already notes this) | ADR 0013 (proposed) *(roadmap update)* | proposed |
| PD-13 | Promote OpenQASM 3 import and export (a documented subset) from an idea to a milestone | It is the cheapest way for tier-2 researchers to try NxQuantum on circuits written elsewhere, and it lets the cross-framework harness share circuits instead of re-encoding them per framework | H2.8 *(roadmap update)* | proposed |

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
| `docs/decision-matrix.md` | `docs/product-positioning.md` (done in H1.5 PR-1, 2026-10-30; the pointer stub was removed on 2026-11-25, with PD-1) |

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
| 0–4 | pre-0.5.0 (no CHANGELOG entries) | Foundation, state-vector correctness, gradients, noise, kernels, Axon, API stabilization, CI | done, except channel-level noise: the `noise:` option is a scalar model (KG-30) |
| 5–8 | pre-0.5.0 | Estimator/Sampler primitives, batching, mitigation, transpilation, dynamic IR, Python-alternative positioning | done, except Phase 7's tensor-network path (KG-1) |
| 9–11 | 0.5.0 | Provider bridges (IBM, AWS, Azure), cross-provider normalization, OpenTelemetry, migration packs | done |
| 12 | `v0.6` label (no CHANGELOG entry) | Contract completion, adapter hardening | done |
| 13 | 0.7.0 | Versioned external contracts, observability schema governance | done |
| 14 | 0.8.0 | Live provider transport (`:fixture`/`:live_smoke`/`:live`), replay fixture capture, lifecycle envelope parity | shipped (code audited 2026-10-19); live credentialed evidence not in repo |
| 15 | 0.8.0 | Compiler `compile/2` diagnostics, routing strategies (`shortest_path`, `sabre_like`), calibration profiles, scheduling reports | partial: provider-aware transpilation adapters and side-by-side compiler narrative not found; semantic property tests added in H1.4 (KG-3 closed) |
| 16 | 0.8.0 | Custom observability metadata validation (allowlist, cardinality, redaction), correlation metadata, troubleshooting bundles, dashboards | partial: `docs/playbooks/observability.md` is 26 lines; live-provider incident playbooks not yet written |
| 17 | — | Migration Assurance Toolkit (ADR 0007) | not delivered; ADR set to Deferred; scoped `Migration.AI*` slice shipped (0.9.0) |
| 18 | 0.8.0–0.9.0 | High-value performance matrix and guards | done |
| 19–21 | 0.9.0 | AI tool contracts, hybrid benchmark pack, AI rollout gates | done (synthetic data, KG-5) |
| D1–D4 | 0.9.1 | Runtime auto-selection, fused-kernel cost, cache policy, CI guards | done |
| 22–23 | 0.11.0 (`v0.10` + `v0.11` labels) | TurboQuant rerank compression, dataset onboarding, KPI gates | done |
