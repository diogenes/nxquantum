# H1.5 Kano survey (instrument and recording template)

- **Status:** instrument ready; fielding waits for 0.12.0 and the launch.
- **Instrument version:** v1 (2026-10-30).
- **Purpose:** test the Kano hypotheses in `docs/vision.md` §6 for H1.5 gate 3 (n >= 10 targeted respondents).
- **Owner decides** every change that follows from the results. Nothing here changes the vision or roadmap by itself.

## Privacy

- No personal data in the repo: no names, emails, handles or employers.
- Respondents are recorded by anonymized id (R01, R02, ...).
- Contact opt-ins (the CLOSE question) are collected outside the repo and stay with the owner. The filled target list stays with the owner.
- Gate 4 names a design-partner candidate when that person has consented; without consent it uses an anonymized id.
- Consent text shown to respondents: "Answers are anonymous and may be summarized in the NxQuantum repo."

## Instrument

### Screener

- S1 Role: backend/platform engineer | ML engineer | researcher | operator/SRE | other
- S2 Do you run Elixir in production? yes | no
- S3 Top need from a quantum library (pick one): run inside my Elixir service | reproducible results | many hardware providers | advanced compiler | GPU-scale simulation | learning/teaching | other
- S4 NxQuantum use: never | tried | using

### Questions for each feature

Answer scale: 1 I like it, 2 I expect it, 3 I'm neutral, 4 I can live with it, 5 I dislike it.

- Functional: "If you <feature> with NxQuantum, how do you feel?"
- Dysfunctional: "If you did NOT <feature> with NxQuantum, how do you feel?"
- Optional: "How important is this to you?" 1-9
- Unshipped items (F9, F10), functional: "Would you value being able to <feature>? If NxQuantum offered this, how do you feel?"
- Unshipped items (F9, F10), dysfunctional: "If NxQuantum did NOT offer this, how do you feel?"

### Features

- F1 check every gate, expectation and gradient against an analytic or independent reference with a published tolerance
- F2 install from Hex (Mix.install or mix.exs) and run a first circuit without cloning the repo
- F3 have every docs and Livebook example run unchanged on the current release
- F4 keep job/result/error records in a versioned JSON shape that never changes without a version bump
- F5 run circuits up to ~8 qubits in-process fast enough to sit in a request path
- F6 run a parameter sweep over many inputs as one batched call
- F7 simulate up to ~24 qubits on one machine
- F8 attach a stable fingerprint (circuit, options, seed, versions) to every result
- F9 run your quantum model and a classical baseline on the same data in one call
- F10 were shown a Livebook of one job fanned out across BEAM nodes with the same results as one node
- F11 keep seeded results bit-identical after you upgrade Nx or Erlang/OTP (default backend)
- F12 run inside your supervised Elixir application, with no Python service to deploy

### Close

Optional contact for follow-up, collected outside the repo.

### Mapping to vision §6

| Features | Hypothesis | Status at instrument date |
| --- | --- | --- |
| F1-F4 | Must-be | F1 shipped. F2 and F3 partial. F4 in 0.12.0 |
| F5-F7 | Performance | No public claim |
| F8-F10 | Delighter | F8 shipped. F9 and F10 not built |
| F11 | New | Tests the D1 lead (`docs/roadmap.md`) |
| F12 | New | Primary-audience value; shipped |

## Channels

1. Elixir Forum launch thread.
2. EEF Machine Learning WG. Confirm the active channel first.
3. Direct 1:1 interviews.
4. FluxQ early users. This may be zero.

ElixirConf 2027 dates are unpublished as of 2026-10-30, so n >= 10 is not planned around a conference.

## Analysis rules

- Target respondents: n >= 10. S3 = many hardware providers, advanced compiler or GPU-scale simulation marks a respondent as not targeted. Report them separately; never use them to reclassify.
- Classify each answer pair with the Kano evaluation table below. Drop Q answers. If R is 30% or more of a feature's answers, flag the wording.
- Reclassify a feature only if the mode category has at least 50% of valid answers and leads the runner-up by at least 2. Otherwise record "inconclusive, hypothesis kept".
- Tie order is M > O > A > I. A tie-broken mode has margin 0, so it is recorded as "contested, hypothesis kept" and is never used to reclassify.
- Write results as "observed (n=X, dates, channels)", not "validated".

Kano evaluation table (functional row by dysfunctional column; A attractive, O one-dimensional, M must-be, I indifferent, R reverse, Q questionable):

|           | Like | Expect | Neutral | Live with | Dislike |
|-----------|------|--------|---------|-----------|---------|
| Like      | Q    | A      | A       | A         | O       |
| Expect    | R    | I      | I       | I         | M       |
| Neutral   | R    | I      | I       | I         | M       |
| Live with | R    | I      | I       | I         | M       |
| Dislike   | R    | R      | R       | R         | Q       |

## Outcome to change (owner decides)

| Observed result | Candidate change |
| --- | --- |
| F5 = M or O | Users expect speed that we cannot cite. Decide whether the next major release publishes a benchmark |
| F5 = I | Confirms dropping the speed claims |
| F11 = A or O | The D1 lead holds |
| F11 = I | Emphasize F4 and F12 |
| F9 = A with high Better | Candidate feature |
| F9 = I | Park it |
| F10 = I | Deprioritize the H2.3 demo |
| F2 or F3 = M while still partial | Pause launch activity until fixed |

## Recording template

Status: collecting | closed. Instrument: v1 (2026-10-30). Window: (empty). Channels (responses): (empty).

### Respondents

| ID | Date | Channel | S1 | S2 | S3 | S4 | Segment |
| --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |

### Raw answers (func/dysf (importance))

| ID | F1 | F2 | F3 | F4 | F5 | F6 | F7 | F8 | F9 | F10 | F11 | F12 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |  |  |  |  |  |

### Classification

| Feature | §6 hypothesis | A | O | M | I | R | Q | Mode | Margin | Better (A+O)/(A+O+M+I) | Worse -(O+M)/(A+O+M+I) | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
|  |  |  |  |  |  |  |  |  |  |  |  |  |

### Not targeted

| ID | S3 | Mode answers (report only; excluded from reclassification) |
| --- | --- | --- |
|  |  |  |

### Proposed vision §6 changes

| Feature | From | To | n | Owner decision (date) |
| --- | --- | --- | --- | --- |
|  |  |  |  |  |

## Success-metric baselines (fetched 2026-10-30)

Source: public Hex package pages, fetched 2026-10-30, before the 0.12.0 launch. These feed the `docs/vision.md` §14 metrics.

| Metric | Value |
| --- | --- |
| nx_quantum Hex downloads, all time | 432 |
| nx_quantum Hex downloads, last 7 days | 26 |
| nx_quantum Hex downloads, version 0.11.0 | 152 |
| nx_quantum Hex dependents | 0 |
| qx_sim Hex downloads, all time | 1,768 |
| qx_sim Hex downloads, recent | 447 |

A launch-day Hex-downloads baseline is added to this table when 0.12.0 ships.
