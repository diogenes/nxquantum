# 2025–2026 quantum algorithm and simulation landscape (research intake)

- **Status:** intake input for `docs/vision.md` §12. Prepared 2026-11-25 from a literature review of 2025–2026 papers against the repository at `main` 69d5bfc. Not yet signed off by the physics/math seat.
- **What this is:** the sources behind the 2026-11-25 strategy review (decisions PD-1 to PD-13 in the `docs/roadmap.md` Decision Log). Each item below is a candidate; it enters the roadmap only through a milestone plan review that records the §12 checklist.
- **What this is not:** evidence about NxQuantum. No figure here was measured on NxQuantum. Speedups are each paper's own, on its own hardware.

## Verification status

The review read abstracts, HTML versions, and release notes. It did not re-derive results.

| Status tag | Meaning |
| --- | --- |
| `refereed` | Journal or conference version found by the review |
| `cited-refereed` | Later papers cite a journal version; the review did not open it |
| `preprint` | arXiv only, as of 2026-11-25 |
| `abstract-only` | The review saw only the abstract or a snippet |
| `software` | A software release, not a paper |

The physics/math seat confirms each source (title, authors, version, refereed status) in the plan review of the milestone that uses it. No source here has a Lean-compiled result.

## Repository facts the review relied on (checked 2026-11-25, `main` 69d5bfc)

| Fact | Where |
| --- | --- |
| One simulator adapter: dense state vector, `complex64` state, `{:f, 32}` expectations | `lib/nx_quantum/adapters/simulators/state_vector*`, `docs/backend-support.md` (KG-10) |
| Gates are applied one at a time through small `defn` kernels; state evolution runs on Nx's default backend even under `cpu_compiled` | `lib/nx_quantum/adapters/simulators/state_vector/state.ex`, KG-16 |
| `Ports.Simulator` returns amplitudes (`apply_gates/3`), so Heisenberg-picture and stabilizer methods do not fit it | `lib/nx_quantum/ports/simulator.ex`, `docs/vision.md` §11 Clifford row |
| The `noise:` option is a scalar transform of the final expectation | `lib/nx_quantum/estimator/stochastic.ex`, KG-30 |
| Mitigation passes: `readout`, `zne_linear` | `lib/nx_quantum/mitigation/passes/` |
| Gradients: backprop, parameter shift, adjoint | `lib/nx_quantum/grad/` |
| Observables are single-wire Paulis publicly; `SparsePauli` exists but is `@moduledoc false` | KG-19, KG-21 |
| No OpenQASM import or export | `grep -ri qasm lib/` is empty |
| Public scale evidence: 2–8 qubits; correctness suites up to 6 qubits | KG-6, H1.4 |
| Parallelism: `Task.async_stream` in batch and sampled-expectation paths; no multi-node execution | `lib/nx_quantum/application/batch_executor.ex`, H2.1 |

## Candidates, ranked

Ranking rule: impact on the positioning (reproducible simulation on BEAM), feasibility for a small team, differentiation, and strength of the research. Effort assumes one engineer fluent in Nx; double it if EXLA kernel work is new.

### 1. State-vector engine v2: fused, compiled, batched, with a precision option

Roadmap: H2.4.

- **Proposal:** fuse runs of gates into dense k-qubit blocks (k ≤ 4–5; diagonals separately), run one compiled program per plan, add a leading batch axis for sweeps, trajectories, and kernel rows, add `precision: :f32 | :f64`, and fuse the adjoint gradient so it keeps two states instead of every intermediate.
- **Sources:**
  - arXiv:2511.14664 (Nov 2025), multi-GPU simulation and network performance: gate fusion balances arithmetic intensity; across GPUs, interconnect bisection bandwidth dominates. `preprint`.
  - arXiv:2604.03816 (Apr 2026), backend selection, gate fusion, adaptive precision: a policy for choosing a backend by qubit count; large GPU speedups from about 16 qubits. `preprint`.
  - arXiv:2603.02804 (Mar 2026), forward and backward gate fusion for QML simulation: a naive adjoint stores O(M·2^n) states; fusion plus checkpointing removes most of it. `preprint`.
  - arXiv:2611.28571 (Nov 2026), repeated variational optimization on GPUs, with PennyLane Lightning's adjoint as baseline. `preprint`.
- **Who ships it:** fusion and adjoint are standard in Qiskit Aer, qsim, PennyLane Lightning, and cuQuantum-based stacks.
- **Workflow served:** every simulator user; prerequisite for all items below.
- **Falsifiable hypothesis:** on one host, fused EXLA evolution of a 20-qubit brickwork circuit is at least 5× faster than the current per-gate path on the same backend, and agrees with a float64 reference to 1e-10 in `:f64` mode.

### 2. Noise channels with deterministic batched trajectories, plus a small density-matrix oracle

Roadmap: H2.5.

- **Proposal:** a `NoiseModel` (per-gate and per-qubit Kraus channels: depolarizing, amplitude and phase damping, readout, Pauli-Lindblad), a trajectory executor that samples error patterns first, groups identical patterns, and runs each unique pattern once on the batch axis, and an exact density-matrix executor for up to about 12 qubits, used as a test oracle.
- **Sources:**
  - Patti, Nguyen, Lietz, McCaskey, Khailany, pre-trajectory sampling with batched execution (PTSBE), arXiv:2504.16297, SC '25. Splits trajectory simulation into sampling Kraus choices and batched execution of the resulting circuits; reports up to 10^6× on a 35-qubit QEC state-vector workload. Open source in CUDA-Q. `refereed`.
  - arXiv:2611.23923 (Nov 2026), extends PTSBE to general channels and mid-circuit measurement. `abstract-only`.
  - Myers et al., arXiv:2512.07304 (Dec 2025), general noise at close to Pauli-noise cost. `abstract-only`.
  - Jones, Koczor, Benjamin, arXiv:2311.01512 (2023): density matrices handled as doubled state vectors, the technique behind QuEST's distributed density matrices. Background.
- **Who ships it:** Qiskit Aer, QuEST, CUDA-Q (including PTSBE) ship noise models and trajectories.
- **Workflow served:** noisy algorithm studies; validating mitigation (item 6); H3.1 needs decoherence models.
- **Falsifiable hypothesis:** for unitary-mixture noise at p ≤ 1e-3 per gate on 16 qubits and 10^5 shots, pattern grouping executes at least 100× fewer state evolutions than per-shot trajectories, and the counts are byte-identical across 1 vs 4 workers for the same seed.
- **Why NxQuantum:** sampling error patterns before evolution turns noise into many independent, seedable units. Determinism then reduces to seed derivation and ordered reduction, which H2.1 already specifies.

### 3. Pauli-propagation estimator (Heisenberg picture)

Roadmap: H2.6, after ADR 0013.

- **Proposal:** a backend that evolves observables (as sparse Pauli sums) backwards through the circuit, truncating by coefficient, Pauli weight, or frequency, and reporting the truncated weight with the result. Noise enters as Pauli damping.
- **Sources:**
  - Rudolph, Jones, Teng, Angrisani, Holmes, *Pauli Propagation: a computational framework for simulating quantum systems*, arXiv:2505.21606 (May 2025), with the PauliPropagation.jl reference implementation. Cited by later work as PRX Quantum 7, 032001 (2026). `cited-refereed`.
  - Angrisani et al., arXiv:2501.13101, Pauli propagation under arbitrary local noise: expectation values of typical noisy circuits are classically estimable. Cited as PRX Quantum 7, 020313 (2026). `cited-refereed`.
  - Schuster, Yin, Gao, Yao, polynomial-time classical algorithm for noisy circuits, PRX 15, 041018 (2025); and classical estimation of noiseless-circuit observables, PRL 135, 170602 (2025). `refereed`.
  - Cerezo et al., *Does provable absence of barren plateaus imply classical simulability?*, Nature Communications 16, 7907 (2025): trainable variational models often live in classically simulable subspaces. `refereed`.
  - Follow-ups: differentiable Pauli propagation, arXiv:2607.15184 (2026); a GPU implementation, arXiv:2610.17755 (2026). `preprint`.
- **Who ships it:** PauliPropagation.jl (Julia); IBM's `pauli-prop` add-on for Qiskit (2025, `software`). No BEAM implementation found.
- **Workflow served:** expectation values in hybrid training loops beyond state-vector width; a "could this model be simulated classically?" check for QML users.
- **Falsifiable hypothesis:** for a 100-qubit, depth-20 kicked-Ising circuit, the estimator returns ⟨Z⟩ within its reported truncation bound of a published reference value, in under 60 s on one host; up to 20 qubits it agrees with the state vector within that bound.
- **Architecture constraint:** needs a simulation-method port that is not amplitude-based (decision PD-12, ADR 0013).

### 4. Deterministic ensemble executor across BEAM nodes (H2.1)

Roadmap: H2.1 (re-scoped).

- **Proposal:** build H2.1 as an ensemble executor: shots, trajectories, parameter-shift evaluations, kernel tiles, and Pauli-propagation partitions fan out with derived seeds and are reduced in task-index order. Sharded state vectors stay out of scope (`docs/vision.md` §10).
- **Sources:**
  - arXiv:2511.14664 (above): distributed state-vector performance is bound by interconnect bandwidth; in Qiskit, PennyLane, and Cirq, multi-GPU runs go through cuQuantum. `preprint`.
  - arXiv:2609.34369 (2026), partition geometry and rank density: data movement, not arithmetic, limits distributed simulation at scale. `preprint`.
  - Lazy qubit reordering for parallel state-vector simulation, ACM TQC 6(4), 2025: swap scheduling, relevant only if sharding is ever un-parked. `refereed`.
- **Who ships it:** throughput fan-out exists in GPU and MPI stacks. A reproducibility guarantee across workers and failures was not found as a headline feature in the review; recheck at D2.
- **Workflow served:** everything ensemble-shaped above; FluxQ distributed runs (H2.3).
- **Falsifiable hypothesis:** already stated in ADR 0012 (1 vs N nodes byte-identical; identical results after an injected node kill).

### 5. Hamiltonian simulation primitives and sample-based diagonalization (SQD, SKQD)

Roadmap: H2.9.

- **Proposal:** Pauli-evolution gates; first- and second-order Trotter formulas with error-bound reporting and a qDRIFT option; SQD (sample, recover configurations, project, diagonalize) and SKQD (sample Krylov states) workflows.
- **Sources:**
  - Robledo-Moreno et al., chemistry beyond exact diagonalization on a quantum-centric supercomputer, Science Advances 11(25), eadu9991 (2025), arXiv:2405.05068: up to 77 qubits on IBM Heron with Fugaku post-processing; open-source `qiskit-addon-sqd`. `refereed`.
  - Yu et al., sample-based Krylov quantum diagonalization, arXiv:2501.09702 (Jan 2025): convergence guarantees under ground-state sparsity; 70-qubit experiments. `preprint`.
  - QuEST v4.2.0 (Oct 2025): real, imaginary, and Lindbladian time evolution by Trotterisation. `software`.
- **Who ships it:** Qiskit add-ons (SQD), QuEST (Trotterisation).
- **Workflow served:** chemistry and materials users; a sampler-plus-heavy-classical-post-processing workflow that fits one supervised runtime.
- **Falsifiable hypothesis:** SKQD on a transverse-field Ising chain matches exact diagonalization ground energy within 1e-6 (relative) up to 16 qubits in `:f64` mode.

### 6. Error mitigation v2, checked against an exact noisy reference

Roadmap: H2.7.

- **Proposal:** Richardson and polynomial least-squares ZNE with error bars; noise scaling by gate folding and by amplifying channel rates in the noise model; seeded Pauli twirling; probabilistic error cancellation with the sampling overhead reported.
- **Sources:**
  - Direct analysis of ZNE: polynomial methods, error bounds, and joint physical-algorithmic mitigation, arXiv:2502.20673, Quantum 9, 1909 (2025). `refereed`.
  - Reduced PEC sampling overhead by Pauli error propagation, Quantum 9, 1840 (2025). `refereed`.
  - Error mitigation with stabilized noise in superconducting processors, Nature Communications 16, 8439 (2025). `refereed`.
  - Review of practical error suppression and mitigation, arXiv:2608.20453 (2026): channel-level noise amplification versus circuit folding. `preprint`.
- **Who ships it:** Qiskit (runtime options and add-ons), Mitiq, and others ship ZNE, PEC, and twirling.
- **Workflow served:** provider users who need production post-processing on BEAM; researchers who need mitigation regression tests.
- **Differentiation:** every pass regression-tested in CI against the item-2 density-matrix oracle, with stated tolerances.
- **Falsifiable hypothesis:** on a 6-qubit noisy GHZ fixture, least-squares ZNE reduces absolute error against the noiseless value by at least 3× compared with no mitigation, and its reported error bar covers the true value in at least 95% of 200 seeded repetitions.

### 7. Stabilizer and Pauli-frame sampling with detector-error-model export

Roadmap: H3.0 (demand-gated; `docs/vision.md` §11).

- **Proposal:** a tableau simulator, a Pauli-frame sampler for bulk noisy shots, detector and observable annotations, Stim-compatible detector-error-model export, and a decoder port so external decoders plug in.
- **Sources:**
  - Google Quantum AI, quantum error correction below the surface-code threshold, Nature 638, 920–926 (2025). `refereed`.
  - Relay-BP, improved belief propagation for real-time decoding, arXiv:2506.01779 (2025), open source; FPGA prototype arXiv:2510.21600; GPU version arXiv:2611.21906. `preprint`.
  - Tesseract search-based decoder, arXiv:2503.10988 (2025). `preprint`.
  - QUITS qLDPC circuit simulator, arXiv:2504.02673 (2025); GPU stabilizer simulation, arXiv:2603.14641 (2026); non-Pauli noise for fault-tolerant circuits (QuasiStim), arXiv:2610.15975 (2026). `preprint`.
  - Stim, Gidney, Quantum 5, 497 (2021). Background, `refereed`.
- **Who ships it:** Stim (dominant), Qiskit Aer (stabilizer method), CUDA-Q (`stim` target).
- **Workflow served:** QEC memory experiments; H3.1 needs decoders as supervised processes.
- **Positioning:** interop first (export to Stim's formats and external decoders), not a speed race with Stim. Real-time decoding stays a non-goal (`docs/vision.md` §10).
- **Falsifiable hypothesis:** a distance-5 surface-code memory circuit exported from NxQuantum produces a detector error model that Stim accepts, and logical error rates from the two samplers agree within statistical error at 10^6 shots.

## Also considered

| Item | Source | Why not in the top 7 |
| --- | --- | --- |
| OpenQASM 3 import and export | No paper needed | Promoted to H2.8 by the strategy review (decision PD-13): it is the cheapest way for researchers outside Elixir to try NxQuantum on their circuits, and it lets the cross-framework harness share circuits |
| Matrix-product-state backend | arXiv:2508.10096 (2025); a vendor-run benchmark, arXiv:2607.09882 (2026) | Pauli propagation gives more differentiation per week for the Estimator workload; the benchmark is run by a vendor on its own product |
| Decoded quantum interferometry demo | Jordan et al., Nature 646, 831–836 (2025), arXiv:2408.08292; limits in arXiv:2509.19966 | A good Livebook once a QFT and a classical decoder exist |
| OTOC / "Quantum Echoes" stress test | Google Quantum AI, Nature 646, 825–830 (2025), arXiv:2506.10191 | A stress test for item 3's truncation limits |
| Sparse state vectors for peaked circuits | arXiv:2607.07816 (2026) | Cheap add-on after item 1 |

## Caveats

1. Several sources are 2026 preprints. Peer-review status can change; record it when the milestone's plan review runs.
2. Quoted speedups (10^6×, 64–146×, and so on) are paper- and hardware-specific. They predict nothing about Nx or EXLA; only the in-repo harness (`bench/README.md`) produces NxQuantum evidence.
3. Competitor capabilities above come from this review, not from the dated competitor table in `docs/vision.md` §6. Recheck them at the next decision gate (`docs/vision.md` §13 item 6).
