# quantum-physics-verification

## When To Use
Use when a change makes a numerical or quantum-semantics claim: simulator paths, gate or compiler rewrites, estimator/sampler math, kernels, gradients, noise channels, or any performance claim whose correctness depends on physics. It is the acceptance owner for numerical tolerances.

## Required Reading
- `AGENTS.md`
- `docs/vision.md` (§11 parked ideas, §12 research intake rule)
- `docs/roadmap.md` (Known Gaps, KG-3)
- `docs/testing-strategy.md`

## Step-by-Step Workflow
1. State the physical quantity and its analytic reference (closed form, known identity, or exact dense result at small qubit count).
2. Fix the tolerance explicitly and justify it (floating-point bound for the qubit count and depth). No "approximately equal" without a number.
3. Fix seeds and fixtures. Sampling claims use fixed seeds and a stated statistical bound.
4. Specify the property or identity test (for example: a rewrite preserves the unitary up to global phase; QFT matches `Nx.fft` up to normalization and sign convention).
5. Record which claim the test supports, so docs-sync can cite it.

## Output Requirements
- Plan review input: reference, tolerance, seeds, and the test to write.
- Verifier evidence: test names and the tolerance used.
- Verdict: `pass`, `pass with risks`, or `fail` on the numerical claim.

## Quality Criteria
- Every numerical claim has an analytic or exact reference.
- Tolerances are explicit numbers, not prose.
- No hidden randomness: every stochastic test has a fixed seed.
- Research-derived results pass the research intake rule (`docs/vision.md` §12) before they count as evidence.
