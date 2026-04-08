#!/usr/bin/env python3
"""Phase 11 Plan 11-05 — Krippendorff α report runner (VOICE-05/06).

Loads tester rating blobs against the 50 frozen voice-cursor phrases, computes
weighted-ordinal Krippendorff α with a 1000-bootstrap 95% CI per CONTEXT D-04,
and emits ``docs/VOICE_CURSOR_TEST.md`` with the four ship-gate verdicts.

Tester output JSON format
=========================
Either::

    { "<tester_id>": { "<phrase_id>": "N3", ... }, ... }

or the wrapped form used by ``tools/krippendorff/krippendorff_alpha.py``::

    { "levels": ["N1","N2","N3","N4","N5"],
      "ratings": { "<tester_id>": { "<phrase_id>": "N3", ... } } }

Ship gates
==========
1. overall α ≥ 0.67 (point) AND 95% CI lower bound ≥ 0.60
2. per-level N4 α ≥ 0.67
3. per-level N5 α ≥ 0.67

Exit non-zero if any gate fails (so CI red-builds the ship gate).
"""

from __future__ import annotations

import argparse
import json
import random
import sys
from pathlib import Path
from typing import Dict, List, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(REPO_ROOT))

from tools.krippendorff.krippendorff_alpha import compute_alpha  # noqa: E402

LEVELS = ["N1", "N2", "N3", "N4", "N5"]
GATE_OVERALL_POINT = 0.67
GATE_OVERALL_CI_LOW = 0.60
GATE_PER_LEVEL = 0.67
BOOTSTRAP_N = 1000
BOOTSTRAP_SEED = 42


def load_tester_output(path: Path) -> Dict[str, Dict[str, str]]:
    """Return ``{tester_id: {phrase_id: level}}`` from either format."""
    raw = json.loads(path.read_text(encoding="utf-8"))
    if isinstance(raw, dict) and "ratings" in raw and isinstance(raw["ratings"], dict):
        return raw["ratings"]
    if not isinstance(raw, dict):
        raise ValueError(f"{path}: expected object at top level")
    # Heuristic: each value should itself be a dict.
    if any(not isinstance(v, dict) for v in raw.values()):
        raise ValueError(f"{path}: tester values must be dicts of phrase_id->level")
    return raw  # type: ignore[return-value]


def load_frozen_phrases(path: Path) -> List[dict]:
    raw = json.loads(path.read_text(encoding="utf-8"))
    return raw["phrases"]


def _alpha(ratings: Dict[str, Dict[str, str]]) -> dict:
    return compute_alpha({"levels": LEVELS, "ratings": ratings})


def bootstrap_alpha(
    ratings: Dict[str, Dict[str, str]],
    n: int = BOOTSTRAP_N,
    seed: int = BOOTSTRAP_SEED,
) -> Tuple[float, float, float]:
    """Resample raters with replacement, return (point, ci_low, ci_high)."""
    point = _alpha(ratings)["alpha_overall"]
    rater_ids = list(ratings.keys())
    if len(rater_ids) < 2:
        return (point, float("nan"), float("nan"))
    rng = random.Random(seed)
    samples: List[float] = []
    for _ in range(n):
        picks = [rng.choice(rater_ids) for _ in range(len(rater_ids))]
        # rebuild ratings with synthetic rater ids so duplicates are kept
        resampled = {f"r{i}": dict(ratings[r]) for i, r in enumerate(picks)}
        a = _alpha(resampled)["alpha_overall"]
        if a == a:  # not NaN
            samples.append(a)
    if not samples:
        return (point, float("nan"), float("nan"))
    samples.sort()
    lo = samples[int(0.025 * (len(samples) - 1))]
    hi = samples[int(0.975 * (len(samples) - 1))]
    return (point, lo, hi)


def per_level_alpha(
    ratings: Dict[str, Dict[str, str]],
    phrases: List[dict],
    level: str,
) -> float:
    """α restricted to the high-tone slice {N4, N5}.

    Per Plan 11-05 D-04: per-level N4/N5 α is computed on the *combined* slice
    of items whose ground-truth ∈ {N4, N5}. That gives the matrix at least two
    true labels of variance so the ordinal α is well defined; raters who fail
    to distinguish the two high-tone bands collapse the score.
    """
    if level not in ("N4", "N5"):
        item_ids = {p["id"] for p in phrases if p.get("level") == level}
    else:
        item_ids = {p["id"] for p in phrases if p.get("level") in ("N4", "N5")}
    if not item_ids:
        return float("nan")
    sliced = {
        rid: {iid: lvl for iid, lvl in items.items() if iid in item_ids}
        for rid, items in ratings.items()
    }
    return _alpha(sliced)["alpha_overall"]


def evaluate_gates(
    ratings: Dict[str, Dict[str, str]],
    phrases: List[dict],
) -> dict:
    point, ci_low, ci_high = bootstrap_alpha(ratings)
    n4 = per_level_alpha(ratings, phrases, "N4")
    n5 = per_level_alpha(ratings, phrases, "N5")
    g_overall = (point >= GATE_OVERALL_POINT) and (ci_low >= GATE_OVERALL_CI_LOW)
    g_n4 = n4 >= GATE_PER_LEVEL
    g_n5 = n5 >= GATE_PER_LEVEL
    return {
        "alpha_overall": point,
        "ci_low": ci_low,
        "ci_high": ci_high,
        "alpha_n4": n4,
        "alpha_n5": n5,
        "gate_overall": g_overall,
        "gate_n4": g_n4,
        "gate_n5": g_n5,
        "all_pass": g_overall and g_n4 and g_n5,
        "n_raters": len(ratings),
        "n_phrases": len({iid for r in ratings.values() for iid in r}),
    }


def render_markdown(result: dict, tester_path: Path, frozen_path: Path) -> str:
    def fmt(x: float) -> str:
        return "n/a" if x != x else f"{x:.4f}"

    def mark(b: bool) -> str:
        return "PASS" if b else "FAIL"

    verdict = "PASS" if result["all_pass"] else "FAIL"
    return f"""# Voice Cursor Test — Krippendorff α Report

**Phase:** 11 — l1.6b phrase rewrite + Krippendorff
**Plan:** 11-05 (ship gate)
**Generator:** `tools/voice_corpus/krippendorff_runner.py`
**Tester output:** `{tester_path.relative_to(REPO_ROOT) if tester_path.is_absolute() and REPO_ROOT in tester_path.parents else tester_path}`
**Frozen phrases:** `{frozen_path.relative_to(REPO_ROOT) if frozen_path.is_absolute() and REPO_ROOT in frozen_path.parents else frozen_path}`

## Methodology

- 50 frozen voice-cursor phrases (`tools/voice_corpus/frozen_phrases_v1.json`)
- 5-point ordinal scale: N1 (murmure) … N5 (tonnerre)
- Weighted-ordinal Krippendorff α (Krippendorff 2011 §5.4)
- 1000-iteration bootstrap over raters (with replacement, seed 42)
- 95% CI from 2.5 / 97.5 percentiles

## Sample

| metric | value |
| --- | --- |
| raters | {result["n_raters"]} |
| phrases rated | {result["n_phrases"]} |

## Results

| metric | value | gate | verdict |
| --- | --- | --- | --- |
| α overall | {fmt(result["alpha_overall"])} | ≥ {GATE_OVERALL_POINT:.2f} | {mark(result["alpha_overall"] >= GATE_OVERALL_POINT)} |
| α 95% CI low | {fmt(result["ci_low"])} | ≥ {GATE_OVERALL_CI_LOW:.2f} | {mark(result["ci_low"] >= GATE_OVERALL_CI_LOW)} |
| α 95% CI high | {fmt(result["ci_high"])} | — | — |
| α per-level N4 | {fmt(result["alpha_n4"])} | ≥ {GATE_PER_LEVEL:.2f} | {mark(result["gate_n4"])} |
| α per-level N5 | {fmt(result["alpha_n5"])} | ≥ {GATE_PER_LEVEL:.2f} | {mark(result["gate_n5"])} |

## Ship-gate verdict: **{verdict}**

- Gate 1 (overall α + CI low): {mark(result["gate_overall"])}
- Gate 2 (per-level N4): {mark(result["gate_n4"])}
- Gate 3 (per-level N5): {mark(result["gate_n5"])}

If FAIL: revise the few-shot prompts in `claude_coach_service.py` (Plan 11-03)
or rework the offending phrases in `tools/voice_corpus/frozen_phrases_v1.json`,
then re-rate via the cursor test app and re-run this runner.
"""


def main(argv: List[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("tester_output", type=Path, help="JSON tester output")
    ap.add_argument(
        "--frozen-phrases",
        type=Path,
        default=REPO_ROOT / "tools/voice_corpus/frozen_phrases_v1.json",
    )
    ap.add_argument(
        "--output-md",
        type=Path,
        default=REPO_ROOT / "docs/VOICE_CURSOR_TEST.md",
    )
    ap.add_argument(
        "--no-write",
        action="store_true",
        help="compute and print verdict but do not overwrite the markdown report",
    )
    args = ap.parse_args(argv)

    ratings = load_tester_output(args.tester_output)
    phrases = load_frozen_phrases(args.frozen_phrases)
    result = evaluate_gates(ratings, phrases)
    md = render_markdown(result, args.tester_output, args.frozen_phrases)
    if not args.no_write:
        args.output_md.parent.mkdir(parents=True, exist_ok=True)
        args.output_md.write_text(md, encoding="utf-8")
        print(f"krippendorff_runner: wrote {args.output_md}")
    print(
        "krippendorff_runner: alpha={:.4f} ci=[{:.4f},{:.4f}] N4={:.4f} N5={:.4f} -> {}".format(
            result["alpha_overall"],
            result["ci_low"],
            result["ci_high"],
            result["alpha_n4"],
            result["alpha_n5"],
            "PASS" if result["all_pass"] else "FAIL",
        )
    )
    return 0 if result["all_pass"] else 1


if __name__ == "__main__":
    sys.exit(main())
