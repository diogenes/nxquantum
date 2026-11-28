# Research intake: Google Research Cogentic papers (2026-11-25)

- **Status:** recorded; no item enters the roadmap.
- **Rule applied:** `docs/vision.md` §12 (Research Intake Rule), enforced through the `principal-architect-product-strategy` plan review.
- **Seat:** Quantum physics/math (`quantum-physics-verifier`).
- **Source set:** `google-research/google-research`, directory `cogentic_research_papers/`, 10 papers, read at the state of 2026-11-25 (index README lists entries dated 2026-10-30 to 2026-11-25). The papers were produced by the Cogentic agentic harness (arXiv:2609.40324).
- **Owner decides** whether any trigger below is ever pulled. Nothing here changes the vision or roadmap by itself.

## Summary

None of the 10 papers concerns quantum computation, quantum simulation, quantum algorithms, or quantum machine learning. A full-text scan of all 10 PDFs (`pdftotext`, case-insensitive `quantum|shor`) found no quantum-computing content; every hit was the substring of "short" or a bibliography title. The papers cover classical computational number theory, algorithmic game theory, communication complexity, graph reconstruction, and learning theory.

Result: no paper-derived proposal is accepted. Nothing in this record supports a public NxQuantum claim, and no NxQuantum doc should cite these papers as evidence for NxQuantum behaviour (AGENTS.md: "claim lacks in-repo evidence" veto).

## Criterion 1: verified source, refereed and Lean-compiled status

All 10 are unrefereed preprints published in a repository directory, not in a journal or conference proceedings (checked 2026-11-25).

| Paper (directory) | Area | Lean status stated in its README |
| --- | --- | --- |
| `integer_factorization` | Number theory | Formalization "completed", to be released in a companion submission; not available |
| `deterministic_factoring_l34` | Number theory | Same as above |
| `discrete_logarithm` | Number theory | Same as above |
| `bimatrix_nash_equilibrium` | Game theory | Same as above |
| `logrank_conjecture` | Communication complexity | Same as above |
| `edge_reconstruction` | Graph theory | Same as above |
| `subadditive_prophet_inequalities` | Mechanism design | No Lean claim |
| `fictitious_play_convergence` | Game theory | No Lean claim |
| `ce_convex_games` | Game theory | No Lean claim |
| `vc_sample_compression` | Learning theory | No Lean claim |

None is Lean-compiled in a form this repo can check. Re-check at any un-park.

## Criteria 2-4 per paper

Column key: **Competitor** = does a quantum framework NxQuantum is compared against (`docs/vision.md` §6) ship it; **Workflow** = the NxQuantum user workflow (`docs/vision.md` §4) it would serve; **Hypothesis** = a falsifiable correctness or benchmark hypothesis inside NxQuantum's scope.

| Paper | Competitor | Workflow | Hypothesis | Verdict |
| --- | --- | --- | --- | --- |
| Integer factorization in L_N[1/3, O(1)], unconditional | No | None. Classical algorithm, no circuit or simulator content | None in scope | Not accepted. Context note for the parked FTQC row (below) |
| Deterministic factoring in L_N[3/4, o(1)]; quadratic non-residues | No | None | None in scope | Not accepted. Context note for FTQC row |
| Discrete log in F_{p^n}^×, fixed characteristic, (pn)^{o(log n)} | No | None | None in scope | Not accepted. Context note for FTQC row |
| 1/5-approximate Nash equilibria in poly time | No | None. NxQuantum ships no game solver | None in scope | Not accepted |
| Fictitious play, Ω(T^{-1/(d+1)}) on Θ(d²)-size games | No | None | None in scope | Not accepted |
| Correlated equilibria in convex games, no FPTAS | No | None | None in scope | Not accepted |
| Prophet inequalities, subadditive auctions | No | None. Job pricing and allocation are control-plane concerns owned by FluxQ (`docs/vision.md` §10) | None in scope | Not accepted |
| Log-rank conjecture below √r | No | None | None in scope | Not accepted |
| Edge reconstruction for m ≥ 1000·n | No | None. See the transpiler note below | None in scope | Not accepted |
| Sample compression of size O(d² log² d) | No | Closest is the quantum kernel classifier example (`examples/quantum_kernel_classifier.exs`); see the kernel note below | None in scope | Not accepted |

## Notes on the nearest contact points

These are the only places a reviewer might expect a link. Each was checked and rejected.

1. **Factoring and discrete log versus Shor's algorithm.** These results tighten *proven* classical bounds; they do not change the quantum-versus-classical comparison that FTQC resource estimates rely on.
   - `integer_factorization` proves, without unproven hypotheses, an L_N[1/3] bound. The number field sieve already runs heuristically in L_N[1/3, (64/9)^{1/3}]; the proven constant here is 105, far larger. Practical classical baselines do not move.
   - `discrete_logarithm` applies only to fields of small, fixed characteristic, which are not used for deployed public-key cryptography. Shor-relevant DLP targets (prime fields, elliptic curves) are out of its scope.
   - `deterministic_factoring_l34` is slower than the randomized results and matters for derandomization theory, not for baselines.
2. **Edge reconstruction versus the transpiler's coupling graphs.** `NxQuantum.Transpiler` topologies (`{:heavy_hex, map}`, `{:coupling_map, map}`, `:all_to_all`; `lib/nx_quantum/transpiler/topology.ex`) are labelled edge lists, so reconstructing a graph from unlabelled edge-deleted subgraphs is not a problem the router has. The theorem's hypothesis (m ≥ 1000·n edges) also does not hold for hardware coupling maps, which are sparse (line, ring, grid and heavy-hex maps all have m < 2n); `:all_to_all` carries no edge list.
3. **Sample compression versus quantum kernels.** The result is an existence bound on compression size in terms of VC dimension. Kernel-SVM support vectors already form a compression scheme with a classical (Littlestone–Warmuth) generalization bound, and the paper adds nothing NxQuantum can compute or test. Generalization claims for quantum kernels are outside NxQuantum's evidence base.
4. **Lean-verified gate identities (`docs/vision.md` §11, research only).** The Cogentic Lean formalizations, when released, contain no quantum or linear-algebra-over-ℂ content relevant to gate identities. H1.4's property tests remain the evidence for compiler correctness.

## Un-park triggers (pointers only)

| Parked idea (`docs/vision.md` §11) | When this record matters |
| --- | --- |
| FTQC resource estimation | If adoption interviews un-park it and a resource-estimate report includes a "classical baseline" column for factoring or DLP: cite the practical algorithms (number field sieve), not the proven L_N[1/3, 105] bound, and note that the small-characteristic DLP result does not cover cryptographic targets. Re-check refereed and Lean status first. |

No other parked idea has a trigger tied to these papers.

## Re-intake

Re-run this intake if the Cogentic directory gains a paper on quantum algorithms, quantum simulation, quantum error correction, or quantum learning theory.
