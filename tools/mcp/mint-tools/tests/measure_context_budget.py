#!/usr/bin/env python3
"""Measure CLAUDE.md size pre/post Phase 30.7 trim.

Invocations:
  # Wave 0: capture baseline (writes .claude_md_baseline.json alongside this script)
  python3.11 measure_context_budget.py --capture-baseline

  # Wave 3: assert post-trim delta is at least N%
  python3.11 measure_context_budget.py --assert-delta 30

  # Any wave: print numbers for the commit message / SUMMARY.md
  python3.11 measure_context_budget.py

Exit codes:
  0 — OK / delta satisfied
  1 — delta below threshold (assert mode)
  2 — baseline missing (assert mode)
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# File layout: tools/mcp/mint-tools/tests/measure_context_budget.py
# parents[0] = tests
# parents[1] = mint-tools
# parents[2] = mcp
# parents[3] = tools
# parents[4] = repo root
REPO_ROOT = Path(__file__).resolve().parents[4]
CLAUDE_MD = REPO_ROOT / "CLAUDE.md"
BASELINE = Path(__file__).resolve().parent / ".claude_md_baseline.json"


def measure(path: Path) -> dict[str, int]:
    text = path.read_text(encoding="utf-8")
    lines = text.count("\n")
    bytes_ = len(text.encode("utf-8"))
    # ~4 chars/token heuristic for mixed FR/EN. Per RESEARCH.md Pitfall 8 (A1).
    est_tokens = bytes_ // 4
    return {"lines": lines, "bytes": bytes_, "est_tokens": est_tokens}


def _fmt(m: dict[str, int], label: str) -> str:
    return f"  {label:10s}: {m['lines']:>4} lines | {m['bytes']:>6} bytes | ~{m['est_tokens']:>5} tokens"


def _print_current(m: dict[str, int]) -> None:
    targets_30 = {k: int(v * 0.7) for k, v in m.items()}
    targets_20 = {k: int(v * 0.8) for k, v in m.items()}
    print("CLAUDE.md size:")
    print(_fmt(m, "current"))
    print(_fmt(targets_30, "-30% tgt"))
    print(_fmt(targets_20, "-20% floor"))


def capture_baseline() -> int:
    m = measure(CLAUDE_MD)
    BASELINE.write_text(json.dumps(m, indent=2) + "\n", encoding="utf-8")
    print(f"Baseline captured to {BASELINE.relative_to(REPO_ROOT)}:")
    _print_current(m)
    return 0


def assert_delta(threshold_pct: int) -> int:
    if not BASELINE.exists():
        print(f"ERROR: baseline missing at {BASELINE}. Run --capture-baseline first.", file=sys.stderr)
        return 2
    baseline = json.loads(BASELINE.read_text(encoding="utf-8"))
    current = measure(CLAUDE_MD)
    fraction = threshold_pct / 100.0

    passes = 0
    print(f"Asserting -{threshold_pct}% on 2-of-3 dimensions (lines, bytes, est_tokens):")
    for key in ("lines", "bytes", "est_tokens"):
        delta_pct = (baseline[key] - current[key]) / baseline[key] * 100
        ok = current[key] <= baseline[key] * (1 - fraction)
        status = "PASS" if ok else "FAIL"
        print(f"  {key:10s}: {baseline[key]:>6} -> {current[key]:>6} ({delta_pct:+.1f}%) [{status}]")
        if ok:
            passes += 1

    if passes >= 2:
        print(f"OK: {passes}/3 dimensions meet -{threshold_pct}% threshold.")
        return 0
    print(f"FAIL: only {passes}/3 dimensions meet -{threshold_pct}% threshold.", file=sys.stderr)
    return 1


def main() -> int:
    ap = argparse.ArgumentParser()
    g = ap.add_mutually_exclusive_group()
    g.add_argument("--capture-baseline", action="store_true")
    g.add_argument("--assert-delta", type=int, metavar="PCT", help="Assert post-trim shrinkage >= PCT%%")
    args = ap.parse_args()

    if args.capture_baseline:
        return capture_baseline()
    if args.assert_delta is not None:
        return assert_delta(args.assert_delta)

    _print_current(measure(CLAUDE_MD))
    return 0


if __name__ == "__main__":
    sys.exit(main())
