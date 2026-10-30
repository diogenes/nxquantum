# Livebook-First Tutorials

Runnable notebooks are provided under `examples/livebook/`.

## Prerequisites

1. `livebook` installed and available in your shell.
2. Repo dependencies installed (`mise install`, `mix setup`).

## Available Tutorials

| Notebook | What it shows |
| --- | --- |
| `examples/livebook/estimator_sampler_walkthrough.livemd` | Deterministic expectation and seeded sampling for one circuit. |
| `examples/livebook/kernel_and_transpiler_walkthrough.livemd` | Kernel matrix generation and topology-aware transpilation. |
| `examples/livebook/provider_bridge_side_by_side.livemd` | Provider lifecycle parity for `IBM Runtime`, `AWS Braket` and `Azure Quantum` in fixture mode: deterministic job ids, serialize and rehydrate, typed missing-config errors, and the live-lane requirements as text. |
| `examples/livebook/supervised_service.livemd` | A user-owned `GenServer` under a `Supervisor`, a kill and restart with identical results, a notebook-defined `ObservabilityEmitter`, and user-side `:telemetry` signals, each labelled by source. |
| `examples/livebook/researcher_reproducibility.livemd` | Experiment fingerprints, seeded replay, the classical closed form `cos θ`, and `portability_delta/2`. Single-qubit only. |

## How To Run

```bash
livebook server
```

Then open any notebook from the table above.

Every notebook starts with the same setup cell:

```elixir
Mix.install([{:nx_quantum, path: "../.."}])
```

The path is relative to the notebook file, so `../..` is the repository root and the notebooks run against your checkout. At the 0.12.0 release the setup cells switch to the Hex dependency.

## Checkpoints And The Notebook Test

The notebooks are checked by an extractor in the test, not by Livebook (KG-29 in `docs/roadmap.md`). The test reads the fenced cells and evaluates them in one process with `Code.eval_quoted_with_env/3`. It does not start Livebook, so it does not exercise Livebook's own setup, runtime or rendering. Treat a passing test as "the cells compute these values", not as "Livebook opens this notebook cleanly".

Nothing in a notebook is trusted until a test has run it. `test/nx_quantum/livebooks_test.exs` runs in the default `mix test`. To run it alone:

```bash
mix test.livebooks
```

What the test does for each `examples/livebook/*.livemd`:

1. Reads the fenced `elixir` cells in order. Fences with any other language tag (`text`, `bash`) are documentation and never run.
2. Requires the first cell to be exactly the setup cell above, then skips it. A different form fails the test. `Mix.install(path: "../..")`, for example, is read as a Hex package named `path`.
3. Fails if any cell calls `System.get_env`, `System.put_env` or a related function (also through `import System`, an alias of `System`, or `:os.getenv`/`:os.putenv`) on a `NXQ_PROVIDER_LIVE*` key, or on a key it cannot read statically. Show live keys as text, in a `text` fence. The test also fails if such a variable is set in the environment it runs in, before the run and after each run, so notebooks always run in the fixture lane.
4. Evaluates the remaining cells in order in one fresh process, with the bindings, aliases and imports carried from cell to cell. Afterwards the test stops the supervisors the cells left linked to the process, purges the modules the cells defined (modules loaded from `.beam` files stay loaded) and detaches the telemetry handlers they attached. A cleanup probe, `test/fixtures/livebook_probe/leftovers.livemd`, leaves a supervisor, a named `Agent` and a module behind and checks that all three are gone.
5. Runs the whole notebook a second time and requires identical checkpoint values.
6. Compares the checkpoints to the goldens in `test/fixtures/livebooks/<notebook name>.golden`.
7. Fails if a cell prints a compiler warning.

### The checkpoint convention

A cell is a checkpoint when its first line is a comment of this form:

```elixir
# checkpoint: expectation_ry_0_8
{:ok, exp} = NxQuantum.Estimator.expectation_result(circuit, observable: :pauli_z, wire: 0)
exp
```

The value of the last expression in the cell is recorded under that name. Rules:

* A checkpoint value is plain data: numbers, strings, atoms, lists, tuples and maps. An `Nx.Tensor` is recorded as a flat list of numbers. Other structs fail the test. Select the fields you want to pin.
* A name appears once per notebook, in lowercase letters, digits and underscores.
* Each notebook has at least one checkpoint, and the goldens file has the same names as the notebook.
* Cells may also end in assertions such as `true = ...` or `^expected = ...`. A failed match fails the test. Use them for properties; use a checkpoint for a value you want pinned.

### Goldens

A goldens file is a `.golden` Elixir term file: Elixir source that evaluates to a map, kept off the `.exs` extension so `mix format` and credo do not touch it. The map goes from checkpoint name to expected value. Matching rules:

* Exact for integers, strings and atoms: counts, job ids, fingerprints, states.
* An absolute tolerance of `1.0e-6` for floats. That is the `f32` accuracy floor documented in `docs/backend-support.md` ("Numerical Precision").

Where a value has an analytic form, the golden uses it (for example `:math.cos(0.8)`) and is compared within the tolerance above, not copied from the program's output. A golden may call `:math`. The test rejects a golden that calls any `NxQuantum` module, directly or through an alias, because it would then check the library against itself.

To change a notebook's output on purpose, edit the notebook and the goldens file in the same change, and say why in the change description. Do not loosen a tolerance to make a mismatch pass.

### Fingerprint goldens depend on the OTP major

`Observability.fingerprint/2` hashes `:erlang.term_to_binary/2` with `:deterministic`. OTP does not promise the same bytes across OTP majors. `researcher_reproducibility.golden` pins one fingerprint. The golden fingerprint was measured on OTP 29.1.2 (Elixir 1.20.4), and the CI floor job also runs this test on OTP 28.1. OTP keeps the deterministic term encoding stable only within a major release, so the value can differ on another OTP major and differs from 0.11.0. If it changes, re-derive the value and record it in the CHANGELOG.

### The getting-started snippet

`test/fixtures/docs/getting_started_first_result.elixir` is the first-result snippet a reader pastes. It is plain Elixir over the stable tier. The test walks its syntax tree and fails on any remote call to an `NxQuantum` module that is not in the stable list of `docs/api-stability.md`. The same test evaluates it, twice, and compares the result to `cos(1.2)` within `1.0e-6`. Docs that show this snippet copy it from that file.

## Tutorial Goals

1. Show deterministic estimator and sampler usage with fixed seeds.
2. Demonstrate kernel generation with sample tensor inputs.
3. Demonstrate topology-aware transpilation and report metadata.
4. Demonstrate side-by-side provider lifecycle parity (`IBM Runtime`, `AWS Braket`, `Azure Quantum`) in fixture mode.
5. Show a supervised BEAM service with labelled signals and a restart that does not change results.
6. Show how to make a run reproducible and checkable against a closed form.
