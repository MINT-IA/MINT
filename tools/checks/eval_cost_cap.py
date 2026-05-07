#!/usr/bin/env python3
"""Phase 95 Plan 95-01 / TEST-01 — promptfoo cost cap + banned-term gate.

Reads a promptfoo JSON report (the file referenced by `outputPath` in
`services/backend/evals/promptfooconfig.yaml`) plus the cap declared in
`services/backend/evals/cost_cap.json`, sums per-test cost telemetry, and
exits non-zero if the run exceeded the cap. Doctrine 2026-05-06 §6 objection
1 (cost-runaway mitigation).

In `--self-test-banned-term-mode` the script ALSO scans every test row's
LLM output for any term in
`services/backend/app/services/coach/compliance_guard.py:BANNED_TERMS`
(loaded textually so the script stays stdlib-only and node-promptfoo-friendly)
and exits non-zero on any hit. Used by Plan 95-01 Task 3 « Experiment B »
to prove the banned-term canary gate works against an injected « garanti ».

Exit codes:
    0  cost ≤ cap (and, in banned-term mode, no banned term emitted)
    1  cost cap exceeded OR banned term emitted OR malformed input
    2  usage / argument / missing-file error (sysexits.h EX_USAGE)

Usage:
    python3 tools/checks/eval_cost_cap.py --report path/to/run.json
    python3 tools/checks/eval_cost_cap.py --self-test
    python3 tools/checks/eval_cost_cap.py --report path/to/run.json --self-test-banned-term-mode

Python 3.9-compatible (dev 3.9.6, CI 3.11). stdlib-only.
"""
from __future__ import annotations

import argparse
import json
import logging
import pathlib
import re
import sys
from typing import Iterable

logger = logging.getLogger("eval_cost_cap")

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
DEFAULT_CAP_FILE = REPO_ROOT / "services" / "backend" / "evals" / "cost_cap.json"
COMPLIANCE_GUARD_PATH = (
    REPO_ROOT / "services" / "backend" / "app" / "services" / "coach" / "compliance_guard.py"
)


def _load_cap(cap_path: pathlib.Path) -> float:
    """Read cost_cap.json and return the max_usd_per_run float."""
    try:
        data = json.loads(cap_path.read_text(encoding="utf-8"))
    except FileNotFoundError:
        logger.error("cost cap file missing: %s", cap_path)
        raise
    except json.JSONDecodeError as exc:
        logger.error("cost cap file is not valid JSON: %s (%s)", cap_path, exc)
        raise
    cap = data.get("max_usd_per_run")
    if not isinstance(cap, (int, float)):
        raise ValueError(
            f"cost_cap.json missing required numeric key 'max_usd_per_run' "
            f"(got {cap!r} from {cap_path})"
        )
    return float(cap)


def _load_banned_terms() -> list[str]:
    """Parse compliance_guard.py textually to extract BANNED_TERMS list.

    We avoid importing the module so this script stays stdlib-only and
    runnable from a CI runner that doesn't have the backend's pip deps
    installed (matching the route_registry_parity.py pattern).
    """
    if not COMPLIANCE_GUARD_PATH.is_file():
        raise FileNotFoundError(
            f"compliance_guard.py not found at {COMPLIANCE_GUARD_PATH}"
        )
    src = COMPLIANCE_GUARD_PATH.read_text(encoding="utf-8")
    match = re.search(r"BANNED_TERMS\s*=\s*\[(.*?)\]", src, re.DOTALL)
    if not match:
        raise RuntimeError(
            "Could not locate BANNED_TERMS = [...] in compliance_guard.py — "
            "doctrine §3 SOT reference is broken"
        )
    body = match.group(1)
    # Capture every "..." string literal inside the list body (stdlib-only;
    # avoids ast.literal_eval to side-step the comment/inline noise).
    terms = re.findall(r'"([^"\\]*(?:\\.[^"\\]*)*)"', body)
    return [t for t in terms if t.strip()]


def _iter_results(report: dict) -> Iterable[dict]:
    """Yield each promptfoo per-test result dict; tolerant to schema variants."""
    if isinstance(report.get("results"), list):
        yield from report["results"]
        return
    nested = report.get("results")
    if isinstance(nested, dict) and isinstance(nested.get("results"), list):
        yield from nested["results"]
        return
    # Empty or unknown shape → empty iter (caller handles).
    return


def _sum_cost(report: dict) -> float:
    total = 0.0
    for row in _iter_results(report):
        cost = row.get("cost")
        if cost is None:
            continue
        try:
            total += float(cost)
        except (TypeError, ValueError):
            logger.warning("non-numeric cost field in row, skipping: %r", cost)
            continue
    return total


def _scan_banned_terms(report: dict, banned: list[str]) -> list[tuple[str, str]]:
    """Return list of (term, snippet) hits across all per-row outputs."""
    lowered = [(t, t.lower()) for t in banned]
    hits: list[tuple[str, str]] = []
    for row in _iter_results(report):
        # promptfoo schema variants — output may be at row['output'] or
        # row['response']['output'] or row['provider_response']['output'].
        candidates: list[str] = []
        out = row.get("output")
        if isinstance(out, str):
            candidates.append(out)
        resp = row.get("response")
        if isinstance(resp, dict) and isinstance(resp.get("output"), str):
            candidates.append(resp["output"])
        prov = row.get("provider_response")
        if isinstance(prov, dict) and isinstance(prov.get("output"), str):
            candidates.append(prov["output"])
        for text in candidates:
            text_lc = text.lower()
            for term, term_lc in lowered:
                if term_lc in text_lc:
                    hits.append((term, text[:160]))
                    break  # one hit per row is enough for diagnostics
    return hits


def _self_test() -> int:
    """Smoke-parse a synthetic in-memory promptfoo report. No I/O fail = 0."""
    fixture = {
        "results": [
            {"output": "Réponse neutre sans aucun terme banni.", "cost": 0.0123},
            {"output": "On pourrait envisager le 3a.", "cost": 0.0118},
        ],
    }
    cost = _sum_cost(fixture)
    banned = _load_banned_terms()
    hits = _scan_banned_terms(fixture, banned)
    if not (0.02 <= cost <= 0.03):
        logger.error("self-test cost mismatch: %.4f", cost)
        return 1
    if hits:
        logger.error("self-test banned-term false positive: %r", hits)
        return 1
    if len(banned) < 50:
        logger.error("self-test only found %d banned terms (expected >= 50)", len(banned))
        return 1
    print(f"[OK] self-test: parsed {len(list(_iter_results(fixture)))} rows, "
          f"cost ${cost:.4f}, BANNED_TERMS loaded: {len(banned)}")
    return 0


def _make_argparser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--report", type=pathlib.Path, help="Path to promptfoo JSON report")
    p.add_argument(
        "--cap-file",
        type=pathlib.Path,
        default=DEFAULT_CAP_FILE,
        help=f"Path to cost_cap.json (default {DEFAULT_CAP_FILE})",
    )
    p.add_argument(
        "--self-test",
        action="store_true",
        help="Smoke-parse a synthetic report; verify SOT BANNED_TERMS load.",
    )
    p.add_argument(
        "--self-test-banned-term-mode",
        action="store_true",
        help="Also scan output text for BANNED_TERMS hits (Plan 95-01 Experiment B).",
    )
    return p


def main(argv: list[str] | None = None) -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(name)s: %(message)s")
    args = _make_argparser().parse_args(argv)

    if args.self_test:
        return _self_test()

    if not args.report:
        logger.error("--report is required (or use --self-test)")
        return 2

    report_path = args.report
    if not report_path.is_file():
        logger.error("report not found: %s", report_path)
        return 2

    try:
        report = json.loads(report_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        logger.error("report is not valid JSON: %s (%s)", report_path, exc)
        return 1

    try:
        cap = _load_cap(args.cap_file)
    except (FileNotFoundError, ValueError, json.JSONDecodeError):
        return 2

    cost = _sum_cost(report)
    print(f"[INFO] eval cost: ${cost:.4f} (cap ${cap:.2f})")
    if cost > cap:
        print(f"::error::eval cost ${cost:.4f} exceeds cap ${cap:.2f} — see cost_cap.json")
        return 1

    if args.self_test_banned_term_mode:
        banned = _load_banned_terms()
        hits = _scan_banned_terms(report, banned)
        if hits:
            print(
                f"::error::banned-term gate RED: {len(hits)} hit(s) in promptfoo "
                f"output — doctrine §3 canary"
            )
            for term, snippet in hits[:10]:
                print(f"  - term={term!r}  snippet={snippet!r}")
            return 1
        print(f"[OK] banned-term scan: 0 hits across {len(list(_iter_results(report)))} rows")

    print("[OK] cost cap respected")
    return 0


if __name__ == "__main__":
    sys.exit(main())
