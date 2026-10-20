# Python Alternatives vs NxQuantum Benchmark (2026-10-19)

Status: refresh of `python-alternatives-benchmark-2026-03-25.md` against current competitor releases (H1.3, deliverable 1). Supersedes the March report for competitor comparisons. The March report moves to `docs/archive/`.

## Scope and limits (read first)

1. Five existing scenarios on 2 to 8 qubits only: `baseline_2q`, `deep_6q`, `batch_obs_8q`, `state_reuse_8q_xy`, `sampled_counts_sparse_terms`.
2. **No crossover point is measured yet.** The 12 to 24 qubit scenarios (H1.3 deliverable 2) are not implemented. The claim below is limited to 2 to 8 qubits.
3. One machine, one run configuration. Numbers are not portable across hardware.
4. Competitor versions are pinned below. Do not compare against other versions without rerunning.

## Environment

| Item | Value |
| --- | --- |
| Machine | Apple M4 (arm64), 24 GiB, macOS 25.6.0 (Darwin) |
| Python | 3.13.16 (mise-managed), fresh venv |
| Qiskit | 2.6.0 |
| PennyLane | 0.45.1 |
| Cirq (cirq-core) | 1.7.0 |
| NumPy | 2.5.4 |
| NxQuantum | this repository, `mix run` via `bench/python_alternatives_benchmark.py` |
| Elixir / OTP | 1.19.5 / OTP 28 |
| Nx | 0.11.0 (from `mix.lock`) |

## Commands

```bash
PY=<venv>/bin/python   # Python 3.13 venv with the versions above
for s in baseline_2q deep_6q batch_obs_8q state_reuse_8q_xy sampled_counts_sparse_terms; do
  for r in 1 2 3; do
    $PY bench/python_alternatives_benchmark.py \
      --nx-runtime-profiles cpu_portable,cpu_compiled \
      --nx-profile-resolution-policy require_exact \
      --scenario "$s" > "bench/results/2026-10-19/${s}_run${r}.txt"
  done
done
```

Defaults: `--iterations 2000`, `--warmup 100`, `--nx-cache-mode hot`. Each row is the mean of 3 runs; `Std` is the sample standard deviation across those 3 runs.

## Results (per_op_ms, lower is better)

### baseline_2q
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.005201 | 0.000239 | 3 |
| qiskit | 0.044847 | 0.001059 | 3 |
| nxquantum[cpu_compiled] | 0.079640 | 0.000638 | 3 |
| cirq | 0.227220 | 0.004846 | 3 |
| pennylane | 0.233171 | 0.002712 | 3 |

Nx best / Qiskit ratio: 0.116x (nxquantum[cpu_portable])

### deep_6q
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.029043 | 0.000667 | 3 |
| nxquantum[cpu_compiled] | 0.098077 | 0.016602 | 3 |
| qiskit | 0.150642 | 0.002209 | 3 |
| cirq | 0.551472 | 0.001334 | 3 |
| pennylane | 0.565615 | 0.003499 | 3 |

Nx best / Qiskit ratio: 0.193x (nxquantum[cpu_portable])

### batch_obs_8q
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.154445 | 0.000869 | 3 |
| nxquantum[cpu_compiled] | 0.180824 | 0.000762 | 3 |
| qiskit | 0.478840 | 0.003323 | 3 |
| cirq | 2.574144 | 0.032643 | 3 |
| pennylane | 3.043099 | 0.033303 | 3 |

Nx best / Qiskit ratio: 0.323x (nxquantum[cpu_portable])

### state_reuse_8q_xy
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_compiled] | 0.001459 | 0.000013 | 3 |
| nxquantum[cpu_portable] | 0.001466 | 0.000026 | 3 |
| qiskit | 0.011847 | 0.000164 | 3 |
| cirq | 0.090226 | 0.000590 | 3 |
| pennylane | 0.093590 | 0.000412 | 3 |

Nx best / Qiskit ratio: 0.123x (nxquantum[cpu_compiled])

### sampled_counts_sparse_terms
| Framework lane | Mean ms/op | Std ms/op | runs |
| --- | ---: | ---: | ---: |
| nxquantum[cpu_portable] | 0.015364 | 0.002718 | 3 |
| cirq | 0.041615 | 0.000753 | 3 |
| pennylane | 0.041696 | 0.000571 | 3 |
| qiskit | 0.093971 | 0.000624 | 3 |
| nxquantum[cpu_compiled] | 0.098354 | 0.006320 | 3 |

Nx best / Qiskit ratio: 0.163x (nxquantum[cpu_portable])


## Reading the results

1. NxQuantum's best lane is fastest in all five scenarios on this machine. The ratio to Qiskit 2.6 is 0.12x to 0.32x.
2. The margin is smaller than in March. Qiskit 2.6 is about 2x faster than the March Qiskit snapshot on `baseline_2q` and `deep_6q`, and on `batch_obs_8q` the best-lane ratio moves from 0.20x to 0.32x.
3. Cirq 1.7 and PennyLane 0.45 are now close to Qiskit on `sampled_counts_sparse_terms` (about 0.04 ms/op). NxQuantum's portable lane is still about 2.7x faster there.
4. `cpu_compiled` is slower than `cpu_portable` on the small scenarios (`baseline_2q`, `deep_6q`, `batch_obs_8q`, `sampled_counts_sparse_terms`). It wins only on `state_reuse_8q_xy`, by a margin within run-to-run noise. Do not claim a compiled-lane advantage at these sizes.

## What this does and does not support

Supported:
- On 2 to 8 qubits with these five workloads, on this machine, with these competitor versions, NxQuantum's portable lane has the lowest per-operation time.

Not supported:
- Any claim beyond 8 qubits, including the crossover point. Not measured.
- Any claim about remote provider or QPU latency. This benchmark covers local simulation only.
- Any claim about other hardware or operating systems.

## Evidence artifacts

- Raw outputs: `bench/results/2026-10-19/` (15 files, 5 scenarios x 3 runs) and `summary.md` (aggregation).
- Aggregation: per-scenario mean and sample standard deviation over the 3 runs.
