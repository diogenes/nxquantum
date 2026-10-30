# H1.3 Track A harness correctness evidence, 2026-10-30

Correctness evidence only; timing_published=False; the timed comparison runs at major releases (owner decision 2026-10-30).

Nothing in this directory is a performance claim. The per-row `per_op_ms` values inside `check/*/results.json` and `check.log` come from short check-mode runs, are flagged `timing=not_published`, and must not be quoted.

## Run

- Date (UTC): 2026-10-30
- Commit: `git_head` in `check/run1/environment.txt` is 18e15b2f5bc618790adfd521d0b622d887d43fed (tolerance confirmation commit), `git_dirty: false`. The output was written outside the repository during the run, then copied here.
- Machine: Apple M4, macOS 26.6.2. Elixir 1.20.4, OTP 29.1.2, Nx 1.0.0, EXLA 1.0.0. Python 3.13.16 (`.venv-bench/bin/python -I`), NumPy 2.5.4 (Accelerate BLAS), Qiskit 2.6.1, PennyLane 0.45.1, cirq-core 1.7.0. BEAM `+S 1:1`, BLAS thread variables set to 1.
- Fixture sha256: `8ea1b2927b60014ffd569fd9d0d70b1c1c700ef08644e1cf83a3b31126f6eecd` (`bench/scenarios/python_alternatives_fixture.json`)
- Scenario table sha256: `20488fb4439d3276d90feef51b485194c9e5661f2d12ce42ede5a414670a5d38` (`bench/scenarios/python_alternatives.json`, `tolerances_confirmed: true`)
- Sanitization: none. The raw outputs are copied unedited; the harness now writes the interpreter repo-relative itself (`python: 3.13.16 (.venv-bench/bin/python)`).
- Regeneration: these files were regenerated after the branch history was rewritten, with the same commands, on a clean tree at the tolerance-confirmation commit. The values, tolerances and pass counts are unchanged; `values.json` is byte-identical to the previous generation (same sha256 below). Changes in the outputs: `git_head` (new commit id), the `python:` line (now written by the harness, no hand edit), and `results.json` field names (R7: `rss_max_kb_self` is replaced by `rss_max_bytes_self`, normalized to bytes, and `rss_max_bytes_children` from `RUSAGE_CHILDREN` is added, same normalization). The NxQuantum script's `NXQ_BENCH` line now carries `library_cache_mode` (R1), read from the library result metadata on the batch path; the script raises, and so the row errors, when it disagrees with the requested cache mode. The harness consumes that line and does not echo it into `check.log`; scalar and counts paths report `unreported` (Known Gap).

## Files

| File | Command (from the repository root, `NXQ_BENCH_MIX_CMD=mix` with the pinned toolchain on PATH) | What it proves |
| --- | --- | --- |
| `pins.txt` | `.venv-bench/bin/python -I bench/python_alternatives_benchmark.py --mode pins` | qiskit 2.6.1, pennylane 0.45.1, cirq-core 1.7.0, numpy 2.5.4 are all the latest on the index on 2026-10-30 (`all=True`). |
| `selfcheck.txt` | `... --mode selfcheck --max-qubits 24` | The reference is sound: dense reference at most 6 qubits (5.6e-16 vs bound 1e-12), prefix-parity analytic identity to 24 qubits (1.4e-15 vs 1e-8), f64 consensus (1.1e-15 vs 1e-8), exact-rational sampled counts (3.2e-17 vs 1e-6), and the agreement gate rejects NaN, inf, missing, extra and short rows. `SUMMARY selfchecks=5 failures=0`. |
| `check/run1/`, `check/run2/` | `... --mode check --max-qubits 8 --cache-mode both --out-dir check/runN --values-out check/runN/values.json` | All lanes (NxQuantum portable and compiled, Qiskit, PennyLane, Cirq complex64 and its complex128 equivalence) agree with the NumPy complex128 reference at the table tolerances on every scenario up to 8 qubits, hot and cold. `SUMMARY rows=100 failures=0 errors=0 timing_published=False` in both runs. Cirq complex64 is `ungated` by design (23 CHECK lines); the other 128 CHECK lines are `pass`. |
| `check/run*/values.json` | same | Byte-identical across the two runs, sha256 `3f60d44a6e76a1c783d25c5d9b2e93e84b2483ffb9c945b1b8890dc89d70d6c7` (69984 bytes; confirmed with `--compare-values`). The run is deterministic. |
| `cirq_c64_20q_error.txt` | `... --mode check --scenario real_zbatch_20q --lanes cirq_c64 --check-warmup 0 --check-iterations 1` | Disclosure evidence (RF6): at 20 qubits `cirq.Simulator()` complex64 raises `ValueError: State_vector is not normalized instead had norm 1.0004842281341553`. The harness records `status=error` (ungated lane, not a failure) and finishes with a normal SUMMARY (`rows=2 failures=0 errors=1`); the complex128 equivalence lane passes on the same circuit (max_err 1.2e-14). This is the measured basis for the Cirq disclosure placeholder; the sentence is not yet filled and no Cirq row is publishable until the timed campaign fills it from measured rows. |
| `consensus.txt` | `... --mode consensus --results check/run1/results.json` | Per-width f64 consensus across Qiskit, PennyLane and Cirq complex128 (max 1.4e-15 vs bound 1e-8). `SUMMARY consensus_files=1 rows=100 failures=0`. |

## Limits

- Widths above 8 qubits are exercised only by `selfcheck` (reference identities) and the single Cirq 20-qubit error check. Agreement of the compute lanes at 12 to 24 qubits is checked when the campaign runs.
- Tolerances are the confirmed table values, `tol = max(1e-6, B)` (owner-delegated Lead reading, 2026-10-30).
- Agreement is a numerical check at the stated tolerances, not a claim of bitwise equality across frameworks.
