# kernel-performance

## When To Use
Use for simulator kernels, Nx.Defn execution paths, hot loops, tensor/state-vector performance, and benchmark-driven optimization.

## Required Reading
- `AGENTS.md`
- `docs/v0.9-high-value-performance-matrix.md`
- `docs/python-alternatives-benchmark-2026-03-25.md`
- `docs/axon-integration.md`

## Step-by-Step Workflow
1. Define target metric (latency, throughput, memory) and workload shape.
2. Capture baseline with reproducible benchmark settings in `bench/`.
3. Builder: implement minimal optimization without changing semantics.
4. Add or update failing correctness/property tests before finalizing optimization.
5. Critic: review numeric stability, backend portability, and architecture boundaries.
6. Verifier: run targeted unit/property tests and benchmark reruns.
7. Document benchmark delta and constraints.

## Output Requirements
- Benchmark script or updated benchmark entry with fixed seed/settings.
- Before/after benchmark numbers and interpretation.
- Correctness evidence for unchanged semantics.

## Quality Criteria
- Performance claim is reproducible.
- Numerical correctness and tolerance behavior are preserved.
- No optimization introduces provider leakage or API drift.
