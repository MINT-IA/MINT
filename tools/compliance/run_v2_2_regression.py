#!/usr/bin/env python3
"""
Plan 12-04 — v2.2 ComplianceGuard regression runner.

Walks the v2.2 channel fixture, runs every sample through ComplianceGuard,
prints a per-channel summary, and writes `docs/COMPLIANCE_REGRESSION_v2.2.md`
with the final report. Exits 0 on full pass, 1 on any violation.

Usage:
    python3 tools/compliance/run_v2_2_regression.py

Re-run after every voice/copy change touching a tracked channel. This script
is the executable form of audit fix B4 (ship gate).
"""

from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# ── Path resolution ────────────────────────────────────────────────────────
_THIS_FILE = Path(__file__).resolve()
_REPO_ROOT = _THIS_FILE.parents[2]
_BACKEND_ROOT = _REPO_ROOT / "services" / "backend"
_FIXTURE_PATH = (
    _BACKEND_ROOT / "data" / "compliance_regression" / "v2_2_channels.json"
)
_REPORT_PATH = _REPO_ROOT / "docs" / "COMPLIANCE_REGRESSION_v2.2.md"

# Make `app.*` importable when invoking the runner from the repo root.
sys.path.insert(0, str(_BACKEND_ROOT))

from app.services.coach.compliance_guard import ComplianceGuard  # noqa: E402
from app.services.coach.coach_models import ComponentType  # noqa: E402


def _git_sha() -> str:
    try:
        out = subprocess.check_output(
            ["git", "rev-parse", "--short", "HEAD"],
            cwd=str(_REPO_ROOT),
            stderr=subprocess.DEVNULL,
        )
        return out.decode().strip()
    except Exception:
        return "unknown"


def _load_fixture() -> dict:
    with _FIXTURE_PATH.open("r", encoding="utf-8") as f:
        return json.load(f)


def main() -> int:
    fixture = _load_fixture()
    guard = ComplianceGuard()

    rows: list[dict] = []
    total = 0
    total_pass = 0
    all_violations: list[str] = []

    for channel in fixture["channels"]:
        ch_id = channel["id"]
        ch_name = channel["name"]
        samples = channel.get("samples", [])
        ch_pass = 0
        ch_violations: list[str] = []

        for sample in samples:
            total += 1
            result = guard.validate(
                llm_output=sample["text"],
                component_type=ComponentType.general,
                cursor_level=sample.get("cursor_level"),
            )
            if result.is_compliant and not result.use_fallback:
                ch_pass += 1
                total_pass += 1
            else:
                msg = f"{sample['id']}: {result.violations}"
                ch_violations.append(msg)
                all_violations.append(f"{ch_id} :: {msg}")

        rows.append(
            {
                "id": ch_id,
                "name": ch_name,
                "samples": len(samples),
                "passed": ch_pass,
                "violations": ch_violations,
            }
        )

    timestamp = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    sha = _git_sha()
    overall = "GREEN" if total_pass == total else "RED"

    # ── Build report ──
    lines: list[str] = []
    lines.append("# COMPLIANCE_REGRESSION_v2.2")
    lines.append("")
    lines.append(
        "Final ComplianceGuard regression run for v2.2 ship gate. "
        "Every output channel touched in v2.0 / v2.1 / v2.2 is enumerated "
        "and walked through `ComplianceGuard.validate()`. Zero violations "
        "is required for ship."
    )
    lines.append("")
    lines.append("## Run Metadata")
    lines.append("")
    lines.append(f"- **Run date**: {timestamp}")
    lines.append(f"- **Git SHA**: `{sha}`")
    lines.append(f"- **Fixture**: `services/backend/data/compliance_regression/v2_2_channels.json`")
    lines.append(f"- **Test file**: `services/backend/tests/services/compliance/test_compliance_regression_v2_2.py`")
    lines.append(f"- **Runner**: `tools/compliance/run_v2_2_regression.py`")
    lines.append(f"- **Overall status**: **{overall}**")
    lines.append(f"- **Total samples**: {total}")
    lines.append(f"- **Passed**: {total_pass}")
    lines.append(f"- **Violations**: {total - total_pass}")
    lines.append("")
    lines.append("## Channels Under Test")
    lines.append("")
    lines.append("| # | Channel ID | Channel | Samples | Passed | Pass Rate |")
    lines.append("|---|-----------|---------|--------:|-------:|----------:|")
    for i, row in enumerate(rows, start=1):
        rate = (row["passed"] / row["samples"] * 100) if row["samples"] else 0.0
        lines.append(
            f"| {i} | `{row['id']}` | {row['name']} | "
            f"{row['samples']} | {row['passed']} | {rate:.1f}% |"
        )
    lines.append("")
    lines.append("## Exclusions & Rationale")
    lines.append("")
    lines.append(
        "- **Internal logs / audit trails** — never reach the user, out of scope."
    )
    lines.append(
        "- **Backend exception messages** — surfaced only as generic localized "
        "errors via the mobile app, covered by Phase 9 fallback strings."
    )
    lines.append(
        "- **Pure numeric outputs** (calculator results without prose) — covered "
        "by hallucination detection in the live runtime path, not by this "
        "anti-shame text regression."
    )
    lines.append(
        "- **Admin / dev tooling text** — internal-only, not user-facing."
    )
    lines.append("")
    lines.append("## Run Results")
    lines.append("")
    if total_pass == total:
        lines.append(
            f"All **{total}** samples across **{len(rows)}** channels passed "
            f"`ComplianceGuard.validate()` with **zero violations**. "
            f"Audit fix B4 satisfied. Ship gate: **OPEN**."
        )
    else:
        lines.append(
            f"**{total - total_pass}** samples failed across "
            f"{sum(1 for r in rows if r['violations'])} channel(s). "
            f"Ship gate: **CLOSED**."
        )
        lines.append("")
        lines.append("### Violations")
        lines.append("")
        for v in all_violations:
            lines.append(f"- {v}")
    lines.append("")
    lines.append("## Reproduction")
    lines.append("")
    lines.append("```bash")
    lines.append("cd services/backend && \\")
    lines.append("  python3 -m pytest tests/services/compliance/test_compliance_regression_v2_2.py -q")
    lines.append("")
    lines.append("# or, full report:")
    lines.append("python3 tools/compliance/run_v2_2_regression.py")
    lines.append("```")
    lines.append("")

    _REPORT_PATH.parent.mkdir(parents=True, exist_ok=True)
    _REPORT_PATH.write_text("\n".join(lines), encoding="utf-8")

    # ── Console summary ──
    print(f"v2.2 ComplianceGuard regression — {overall}")
    print(f"  channels: {len(rows)}")
    print(f"  samples : {total}")
    print(f"  passed  : {total_pass}")
    print(f"  report  : {_REPORT_PATH.relative_to(_REPO_ROOT)}")
    if all_violations:
        print("  violations:")
        for v in all_violations:
            print(f"    - {v}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
