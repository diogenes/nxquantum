# ADR 0013: Simulation Method Port (beyond amplitudes)

- Status: Proposed (2026-11-25). Gates H2.6 in `docs/roadmap.md`; informs H2.5 and H3.0.
- Date: 2026-11-25
- Owner context: Simulation Methods (new bounded context, `docs/bounded-context-map.md` §14, planned)
- Decision record: PD-12 (`docs/roadmap.md` Decision Log)

## Context

`NxQuantum.Ports.Simulator` (`lib/nx_quantum/ports/simulator.ex`) has three callbacks:

- `expectation(Circuit.t(), keyword()) :: Nx.Tensor.t()`
- `expectations(Circuit.t(), [map()], keyword()) :: Nx.Tensor.t()` (optional)
- `apply_gates(Nx.Tensor.t(), [GateOperation.t()], keyword()) :: Nx.Tensor.t()`, which takes and returns amplitudes.

One adapter implements it: the dense state vector. The 2027 roadmap adds methods that differ in what they hold:

| Method | Milestone | Holds | Fits `apply_gates/3`? |
| --- | --- | --- | --- |
| Dense state vector (fused, batched) | H2.4 | Amplitudes, 2^n | Yes |
| Density matrix (reference, ≤12 qubits) | H2.5 | A doubled state vector, 4^n | Yes, as amplitudes of the doubled vector |
| Trajectories | H2.5 | One state vector per unique error pattern | Per trajectory only; the result is an ensemble |
| Pauli propagation | H2.6 | A sparse Pauli sum (the observable), no state | No |
| Stabilizer tableau and Pauli frames | H3.0 | A tableau and frame bit-matrices | No |

`docs/vision.md` §11 already records that the Clifford simulator needs an ADR for this reason.

The application layer (`NxQuantum.Application.ExecuteCircuit`) and the runtime-profile selection assume amplitudes. Forcing Pauli propagation or a tableau through `apply_gates/3` would either materialize 2^n amplitudes (defeating the method) or leak method-specific types into the application layer.

## Decision

1. Keep `NxQuantum.Ports.Simulator` unchanged as the amplitude port. The state-vector and density-matrix adapters implement it.
2. Add an expectation-level port that every simulation method implements (*tentative*: `NxQuantum.Ports.ExpectationEngine`):
   - `estimate(Circuit.t(), [observable_spec], keyword()) :: {:ok, estimate_result} | {:error, map()}`;
   - `capabilities() :: map()`, declaring at least: `exact?` (boolean), `max_qubits` (integer or `:unbounded`), `noise` (`:none`, `:pauli`, or `:general`), `gradients` (list of supported modes), `determinism` (`:bitwise` or `:tolerance`), and `reports_error?` (boolean).
3. A thin amplitude-to-expectation adapter wraps any `Ports.Simulator` implementation, so the state vector implements the new port with no behaviour change.
4. Method selection lives in the application layer. An explicit `method:` option wins. Otherwise the existing runtime-profile and scale selection picks the state vector, as today. No automatic switch to an approximate method: approximate methods run only when asked for.
5. `estimate_result` carries the value tensor plus method metadata: the method, its determinism level, and, for approximate methods, the reported error (for Pauli propagation, the truncated weight and thresholds).
6. Sampling methods (trajectories, the stabilizer frame sampler) get a sibling port when H2.5 or H3.0 needs it (*tentative*: `NxQuantum.Ports.SampleEngine`). This ADR fixes only the expectation port.

## Alternatives considered

| Option | Why not |
| --- | --- |
| Add optional callbacks to `Ports.Simulator` for each method | The port's meaning becomes "anything"; callers must probe callbacks; capability checks become ad hoc |
| One port per method | The application layer would branch on every method; adding a method edits the application |
| Route everything through amplitudes | Defeats Pauli propagation and stabilizer methods, whose value is avoiding 2^n state |

## Consequences

- Estimator results gain additive metadata (method, determinism level, reported error). Existing fields and envelope snapshots are unchanged.
- `:tensor_network_fallback` stays a routing label (KG-1). Pointing it at a method through this port is a later `api change` (PD-7).
- Each method's acceptance suite cross-checks against an exact method: state vector, or the density matrix for noise (`docs/roadmap.md` H2.5 and H2.6 review gates).
- `mix test.arch` gains a rule: application modules depend on the new port, never on a method adapter.

## Open questions

1. Final module names for the ports.
2. Whether `capabilities/0` is static per adapter or depends on options (for example, Pauli propagation is exact when truncation is off).
3. How gradients are requested across methods: a shared option, or per-method options in the experimental tier.
