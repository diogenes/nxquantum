# H1.5 TTFR rehearsal (2026-10-30)

**This is a rehearsal, not the gate evidence.** It runs the consumer flow
against `mix hex.build --unpack` of main (version 0.11.0 in `mix.exs`, built
with `NXQ_ENABLE_EXLA=0 NXQ_ENABLE_TORCHX=0`) as a path dependency, with a
stable-API snippet (RY(1.2) on one qubit, `Estimator.expectation/2` on Z wire 0;
see `bench/ttfr/rehearsal_snippet.exs`). Gate 2 closes only on a published
0.12.0 with the exact getting-started snippet.

Human reading time is not measured. Toolchain installation is not measured.
The numbers are an internal, environment-specific reference, not a general
performance claim.

Harness: `bench/ttfr/run.sh` at commit 09ad60d. Environment: `environment.txt`.
Each run used fresh empty `MIX_HOME`, `HEX_HOME`, `HEX_CACHE_DIR` and XDG dirs;
`mix local.hex` and `mix local.rebar` ran inside the timed flow.

## Runs (seconds)

| Step | run1 | run2 | run3 | median | max |
| --- | --- | --- | --- | --- | --- |
| mix local.hex | 0.7 | 0.5 | 0.7 | 0.7 | 0.7 |
| mix local.rebar | 0.5 | 0.7 | 0.6 | 0.6 | 0.7 |
| mix new demo | 0.2 | 0.2 | 0.2 | 0.2 | 0.2 |
| write deps line | 0.0 | 0.0 | 0.0 | 0.0 | 0.0 |
| mix deps.get | 0.6 | 0.5 | 0.6 | 0.6 | 0.6 |
| mix compile | 8.0 | 7.3 | 7.4 | 7.4 | 8.0 |
| mix run snippet | 0.4 | 0.4 | 0.4 | 0.4 | 0.4 |
| **total** | 10.4 | 9.6 | 9.9 | 9.9 | **10.4** |

Printed value in all three runs: `0.3623577356338501` (cos(1.2) = 0.362357754...
in f32, widened to f64 on print). Success was exit 0 plus an exact match.
Gate check (max <= 600 s): 10.4 s, pass for the rehearsal only.

## Pre-release baseline row (does not close the gate)

`{:nx_quantum, "~> 0.11.0"}` from Hex, resolved to Nx 0.13.1 (pre-release
baseline, Nx 0.x), one run (`hex-0.11.0.log`): total 7.1 s, same printed value.

## After 0.12.0 is published

Rerun against `{:nx_quantum, "~> 0.12.0"}` from Hex with the exact
getting-started snippet (`--expect` set from the docs) and commit the logs here
as the gate evidence. See `bench/README.md`.
