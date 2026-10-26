# H1.6 Dependency Currency - numerics evidence

Fixed seeds throughout, default `Nx.BinaryBackend`, Apple M4, macOS 26.6.2.
Two runs per state are byte-identical (`cmp digest_run1.txt digest_run2.txt`, same for precision).

## States

| State | Directory | Run date (UTC) | Toolchain | nx / exla / torchx-lock / complex | Status |
| --- | --- | --- | --- | --- | --- |
| before | `before/` | 2026-10-26 | Elixir 1.19.5 / OTP 28.4.1 | 0.11.0 / 0.11.0 / 0.11.0 / 0.6.0 | recorded |
| after-pr-a | `after-pr-a/` | 2026-10-26 | Elixir 1.19.5 / OTP 28.4.1 | 1.0.0 / 1.0.0 / 1.0.0 / 1.0.0 | recorded |
| after-pr-b | `after-pr-b/` | pending | pending | pending | pending |

The run date of each state is the `date_utc` line of its `environment.txt`; do not assume
one date for all states.

## Digest lines (`bench/numerics_digest.exs`, run 1)

Each SHA is the first 16 hex digits of SHA-256 over a canonical encoding (gate names, integer
wires, params sorted by key, floats as float-64, tensors as type + shape + `Nx.to_binary`).
Lines without a `_sha` token show the sha256 of the whole digest line.

| Line | before | after-pr-a | Identical (y/n) | after-pr-b | Note |
| --- | --- | --- | --- | --- | --- |
| `fixture_ops_sha` | 4902308d83e6ea8e | 4902308d83e6ea8e | y | pending |  |
| `production_expval_bits_sha` | 2037cbb5885a8334 | 2037cbb5885a8334 | y | pending |  |
| `float64_reference_bits_sha` | c2b64561992b31cd | c2b64561992b31cd | y | pending |  |
| `sampler_run_ry_sha` | f650fb5b1fedf895 | f650fb5b1fedf895 | y | pending |  |
| `sampler_run_e2e_sha` | c12ff1c80a535413 | c12ff1c80a535413 | y | pending |  |
| `estimator_shots_sha` | 071d09fb48ff3f2e | 071d09fb48ff3f2e | y | pending |  |
| `compiler_optimize_ops_sha` | e204c003826cb734 | e204c003826cb734 | y | pending |  |
| `readout_mitigation_sha` | e079699b3f218434 | e079699b3f218434 | y | pending |  |
| `grad_values` | 8c314dbc7e9cdbfe (sha256 of line) | 8c314dbc7e9cdbfe (sha256 of line) | y | pending | backprop eps 1e-6 value (first of three): bit canary, not an accuracy figure |
| `grad_bits_sha` | 651300ce18dd8669 | 651300ce18dd8669 | y | pending |  |
| `kernel_bits_sha` | bc0f4c5635e84de1 | bc0f4c5635e84de1 | y | pending |  |
| `complex_prims {:c, 64}` | 60e757e174efc568 (sha256 of line) | 60e757e174efc568 (sha256 of line) | y | pending |  |
| `complex_prims {:c, 128}` | 8c19b7f43889c283 (sha256 of line) | 8c19b7f43889c283 (sha256 of line) | y | pending |  |
| `expectation_types` | [f: 32] | [f: 32] | y | pending |  |
| `max_abs_delta_vs_float64` | 4.3983212272280525e-7 | 4.3983212272280525e-7 | y | pending |  |
| `grad_abs_err_parameter_shift` | 3.692266492549834e-8 | 3.692266492549834e-8 | y | pending |  |
| `grad_abs_err_adjoint` | 6.178549205593242e-8 | 6.178549205593242e-8 | y | pending |  |
| `grad_abs_err_backprop_eps1e-3` | 1.2886202052087015e-6 | 1.2886202052087015e-6 | y | pending |  |

## Other artifacts

| Artifact | before | after-pr-a | Identical (y/n) | after-pr-b |
| --- | --- | --- | --- | --- |
| sha256 of precision_run1.txt (prefix) | a80e871246840cbd | a80e871246840cbd | y | pending |
| contract envelope fixtures, git tree id of `test/fixtures/contracts/envelopes` (12 files) | 802aae3c4410e99d4cf8cbaee832158edf0c7a77 | 802aae3c4410e99d4cf8cbaee832158edf0c7a77 | y | pending |
| `batch_obs_guard.txt` per_op_ms (timing, not compared) | 0.15455 | 0.16167 | n/a | pending |

## Commands

Run from the repository root of the state being recorded.

| What | Command |
| --- | --- |
| digest lines and environment | `MIX_ENV=test mix run bench/numerics_digest.exs --env-out <dir>/environment.txt > <dir>/digest_run1.txt` (run 2 without `--env-out`) |
| precision table | `MIX_ENV=test mix run bench/numerics_precision_floor.exs > <dir>/precision_run1.txt` |
| precision hash | `shasum -a 256 <dir>/precision_run1.txt \| cut -c1-16` |
| envelope fixture snapshot | `git rev-parse <commit>:test/fixtures/contracts/envelopes` (before: `058a388`; after-pr-a: `HEAD` at recording; baseline `a94f681` gives the same id) |
| batch observable guard | `mix bench.batch_obs_guard` |
| first compile (after-pr-a only) | see `after-pr-a/first-compile.txt` (fresh clone, empty `XLA_CACHE_DIR`, `mix deps.get && NXQ_ENABLE_EXLA=1 mix compile`) |

## Reading the results

- Identical `y` on every line means Nx 1.0 / Complex 1.0 changed no bit of the covered surfaces
  on this toolchain and backend.
- Accuracy figures: `max_abs_delta_vs_float64` against the float64 dense reference,
  `grad_abs_err_parameter_shift` and `grad_abs_err_adjoint` against the analytic -sin(theta),
  `grad_abs_err_backprop_eps1e-3` against the analytic derivative at eps 1e-3. The backprop
  eps 1e-6 value inside `grad_values` and `grad_bits_sha` is a bit canary, not an accuracy figure.
- Seeded counts are pinned by `test/nx_quantum/sampler_test.exs` and covered by
  `sampler_run_ry_sha` and `sampler_run_e2e_sha`.

## after-pr-b

Pending. PR-B fills `after-pr-b/` (Elixir 1.20 / OTP 29 lane) with the same files and the
`after-pr-b` columns above.
