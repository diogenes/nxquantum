# ADR 0012: Distributed Execution Context (within-job fan-out)

- Status: Proposed (2026-10-20). Gates H2.1 in `docs/roadmap.md`.
- Date: 2026-10-20
- Owner context: Distributed Execution (new bounded context, within-job scope only)

## Context

`docs/vision.md` §7 (H2) puts distribution inside one NxQuantum job: a sweep, a batch of shots, or a set of circuit-cut fragments fans out across BEAM nodes. Orchestration across jobs stays in FluxQ.

Measured facts that bound the design:
- Single-node throughput is already the strongest local result (`bench/results/2026-10-19/`, 2 to 8 qubits, Apple M4).
- Dense state-vector simulation is memory-bound per node. Splitting one state across nodes is not a goal (`vision.md` §10).
- Competitors use MPI, Dask, Ray, or GPU stacks for distributed numeric work. They win on raw throughput across fast interconnects. We do not claim that.

## Decision

1. The unit of distribution is a `fan_out_task`: a deterministic function of (job spec, task index). Tasks never share mutable state.
2. Each task's seed is derived from the job seed and task index with a fixed, versioned derivation. Results therefore do not depend on which node ran a task.
3. Placement and dispatch are ports (`NxQuantum.Ports.Cluster`, `NxQuantum.Ports.Clock`). Adapters: a single-node adapter and an Erlang-distribution adapter built on OTP (`:erpc`, `:pg`). No new dependency is added.
4. A task lost with its node is re-dispatched with the same seed. Re-dispatch is idempotent by construction (task result is a pure function of the spec). The job completes only when every task index has exactly one accepted result.
5. Results carry provenance: node, seed digest, attempt count.
6. Two determinism levels, reported separately:
   - result determinism: same seed gives identical results on 1 node and N nodes, and after node loss;
   - trace determinism: identical event order in virtual-time mode. Not promised for wall-clock multi-node runs.

## What BEAM buys here (and what it does not)

Buys:
- Supervision and re-dispatch on node loss with no coordinator state outside the job.
- Thousands of lightweight task processes without thread pools.
- Live observability of a running job through the existing OpenTelemetry layer.

Does not buy (do not claim):
- Throughput advantage over MPI or GPU for dense numeric kernels.
- Real-time QEC decoding latency.
- Distributed state-vector simulation.

## Measurable claims (each needs a benchmark or test before it is public)

| Claim | Test or benchmark | Pass criterion |
| --- | --- | --- |
| Same seed gives identical results on 1 vs N nodes | Property test over fixed sweeps, `:peer` nodes | byte-identical result sets |
| Job completes under injected node loss | Node-kill test with `:peer` | all task indices accepted once; results equal the no-fault run |
| Recovery time after node loss | Benchmark with fixed fault schedule | reported with median and spread over 3 runs, with the environment |
| Throughput scaling on local nodes | Benchmark, 1 to 4 local peer nodes | reported with the single-node baseline and its limits; no competitor claim without a same-workload baseline |

## Consequences

- H2.1 can ship without touching domain modules. Distribution sits in the application and adapter layers.
- Competitive claims are limited to fault-tolerant, deterministic, within-job fan-out until a same-workload comparison exists.
- Trace determinism is a separate, later promise (D2 in `vision.md` §8).

## Open questions

1. Seed derivation function: fixed hash of (job seed, index), versioned as `seed_derivation: v1`. Needs owner approval before implementation.
2. Whether to expose task-level replay (H2.3) before D2 passes.
