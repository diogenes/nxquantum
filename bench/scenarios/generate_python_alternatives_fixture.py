#!/usr/bin/env python3
"""
Deterministic angle fixture for the H1.3 cross-framework benchmark.

Reads bench/scenarios/python_alternatives.json and writes
bench/scenarios/python_alternatives_fixture.json plus its .sha256.

Spec:
- numpy.random.Generator(PCG64(seed)), seed = 20261026 + 100 * family_index + qubits
  (family_index: real = 0, complex = 1);
- every angle is k / 1024 with k drawn from [1, 6433] (exactly representable in
  float32 and float64);
- one angle set per timed-loop iteration (warmup + iterations), in the order the
  timed loop uses them, so cold mode never repeats an input (R1);
- ZZ pairs (0, 1) and (n/2 - 1, n/2);
- prefix-parity analytic circuits with seed 20261026 + 10000 + 100 * family_index + qubits.

Run as:  .venv-bench/bin/python -I bench/scenarios/generate_python_alternatives_fixture.py
Output is byte-identical across runs for the pinned NumPy.
"""

from __future__ import annotations

import hashlib
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
TABLE = ROOT / "bench" / "scenarios" / "python_alternatives.json"
FAMILY_INDEX = {"real": 0, "complex": 1}
BASE_SEED = 20261026
K_MIN, K_MAX = 1, 6433
LAYERS = 8
DENOMINATOR = 1024
PREFIX_PARITY_WIDTHS = (4, 8, 12, 16, 20, 24)


def angles_per_set(family: str, qubits: int) -> int:
    return LAYERS * qubits * (1 if family == "real" else 2)


def draw(seed: int, rows: int, cols: int):
    rng = np.random.Generator(np.random.PCG64(seed))
    return rng.integers(K_MIN, K_MAX + 1, size=(rows, cols)).tolist()


def zz_pairs(qubits: int):
    return [[0, 1], [qubits // 2 - 1, qubits // 2]]


def inline(obj, indent=0):
    """Deterministic JSON with one row of numbers per line."""
    pad = " " * indent
    if isinstance(obj, dict):
        items = [f'{pad}  {json.dumps(k)}: {inline(v, indent + 2)}' for k, v in sorted(obj.items())]
        return "{\n" + ",\n".join(items) + "\n" + pad + "}"
    if isinstance(obj, list) and obj and isinstance(obj[0], list) and all(isinstance(x, int) for x in obj[0]):
        rows = [f"{pad}  {json.dumps(r, separators=(',', ':'))}" for r in obj]
        return "[\n" + ",\n".join(rows) + "\n" + pad + "]"
    return json.dumps(obj, separators=(",", ":"))


def build(table: dict) -> dict:
    scenarios = table["scenarios"]
    families: dict = {"real": {"index": 0, "widths": {}}, "complex": {"index": 1, "widths": {}}}

    for scenario_id in sorted(scenarios):
        scenario = scenarios[scenario_id]
        if scenario["kind"] != "family":
            continue
        family, qubits = scenario["family"], scenario["qubits"]
        sets = scenario["warmup"] + scenario["iterations"]
        seed = BASE_SEED + 100 * FAMILY_INDEX[family] + qubits
        families[family]["widths"][str(qubits)] = {
            "scenario_id": scenario_id,
            "seed": seed,
            "sets": sets,
            "angles_per_set": angles_per_set(family, qubits),
            "selfcheck_only": False,
            "zz_pairs": zz_pairs(qubits),
            "k": draw(seed, sets, angles_per_set(family, qubits)),
        }

    for family in FAMILY_INDEX:
        for qubits in table["fixture_spec"]["selfcheck_only_widths"]:
            seed = BASE_SEED + 100 * FAMILY_INDEX[family] + qubits
            families[family]["widths"][str(qubits)] = {
                "scenario_id": None,
                "seed": seed,
                "sets": 1,
                "angles_per_set": angles_per_set(family, qubits),
                "selfcheck_only": True,
                "zz_pairs": zz_pairs(qubits),
                "k": draw(seed, 1, angles_per_set(family, qubits)),
            }

    prefix = {"real": {}, "complex": {}}
    for family in FAMILY_INDEX:
        for qubits in PREFIX_PARITY_WIDTHS:
            seed = BASE_SEED + 10000 + 100 * FAMILY_INDEX[family] + qubits
            rows = 1 if family == "real" else 2
            drawn = draw(seed, rows, qubits)
            entry = {"seed": seed, "theta_k": drawn[0]}
            if family == "complex":
                entry["phi_k"] = drawn[1]
            prefix[family][str(qubits)] = entry

    return {
        "schema_version": 1,
        "generator": "bench/scenarios/generate_python_alternatives_fixture.py",
        "rng": "numpy.random.Generator(PCG64(seed))",
        "angle_denominator": DENOMINATOR,
        "k_range": [K_MIN, K_MAX],
        "layers": LAYERS,
        "families": families,
        "prefix_parity": prefix,
    }


def main() -> int:
    table = json.loads(TABLE.read_text())
    fixture = build(table)
    text = inline(fixture) + "\n"
    out = ROOT / table["fixture"]["path"]
    sha_out = ROOT / table["fixture"]["sha256_path"]
    out.write_text(text)
    digest = hashlib.sha256(text.encode()).hexdigest()
    sha_out.write_text(f"{digest}  {out.name}\n")
    print(f"wrote {out.relative_to(ROOT)} sha256={digest}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
