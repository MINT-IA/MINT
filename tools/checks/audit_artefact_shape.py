#!/usr/bin/env python3
"""Phase 31 OBS-06 + OBS-07 artefact-shape audit.

Asserts that Wave 3/4 Markdown artefacts have the expected sections so
downstream consumers (/gsd-verify-phase, creator-device gate) can trust
their shape without reading them line-by-line.

Usage:
    python3 tools/checks/audit_artefact_shape.py <artefact_name>

Supported artefact names:
  SENTRY_REPLAY_REDACTION_AUDIT  (OBS-06 Wave 3)
      Path:   .planning/research/SENTRY_REPLAY_REDACTION_AUDIT.md
      Must contain:
        - '## Screens audited'
        - '## Masks verified'
        - Each of 5 screen-name literals: CoachChat, DocumentScan,
          ExtractionReviewSheet, Onboarding, Budget
        - '## Sign-off'

  SENTRY_PRICING_2026_04         (OBS-07 (a) Wave 4)
      Path:   .planning/research/SENTRY_PRICING_2026_04.md
      Must contain:
        - Either `fetch_date:` frontmatter OR a `**Fetched:**` line
        - Business tier pricing literal (string 'Business' on a line
          with a dollar amount)

  observability-budget           (OBS-07 (a) Wave 4)
      Path:   .planning/observability-budget.md
      Must contain:
        - '## Quota projection' table
        - '## Sample rate reference' section
        - '## Revisit triggers' section

Exit codes:
  0  artefact file exists and all required sections present
  1  missing section OR missing file OR unknown artefact name

No network access. Stdlib only.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]

ARTEFACTS = {
    "SENTRY_REPLAY_REDACTION_AUDIT": {
        "path": REPO_ROOT
        / ".planning"
        / "research"
        / "SENTRY_REPLAY_REDACTION_AUDIT.md",
        "sections": [
            "## Screens audited",
            "## Masks verified",
            "## Sign-off",
        ],
        "extra_literals": [
            "CoachChat",
            "DocumentScan",
            "ExtractionReviewSheet",
            "Onboarding",
            "Budget",
        ],
    },
    "SENTRY_PRICING_2026_04": {
        "path": REPO_ROOT
        / ".planning"
        / "research"
        / "SENTRY_PRICING_2026_04.md",
        "sections": [],
        # Custom check below: frontmatter OR Fetched line, plus Business
        # tier line with dollar sign.
        "custom": "pricing",
    },
    "observability-budget": {
        "path": REPO_ROOT / ".planning" / "observability-budget.md",
        "sections": [
            "## Quota projection",
            "## Sample rate reference",
            "## Revisit triggers",
        ],
    },
}


def _check_pricing(text: str, path: Path) -> list[str]:
    failures: list[str] = []
    has_frontmatter = bool(re.search(r"^fetch_date:\s*", text, re.MULTILINE))
    has_fetched_line = bool(
        re.search(r"^\*\*Fetched:\*\*", text, re.MULTILINE)
    )
    if not (has_frontmatter or has_fetched_line):
        failures.append(
            f"[FAIL: missing section fetch_date: frontmatter OR "
            f"**Fetched:** line in {path}]"
        )

    # Business tier pricing literal — look for a line containing
    # 'Business' plus a '$' symbol.
    if not re.search(r"Business.*\$", text):
        failures.append(
            f"[FAIL: missing section Business tier pricing literal "
            f"(expected line with 'Business' + '$') in {path}]"
        )
    return failures


def main() -> int:
    ap = argparse.ArgumentParser(
        description=(
            "Phase 31 OBS-06 + OBS-07 Markdown artefact shape audit."
        )
    )
    ap.add_argument(
        "artefact_name",
        choices=sorted(ARTEFACTS.keys()),
        help=(
            "Which artefact to audit: SENTRY_REPLAY_REDACTION_AUDIT, "
            "SENTRY_PRICING_2026_04, or observability-budget."
        ),
    )
    args = ap.parse_args()

    spec = ARTEFACTS[args.artefact_name]
    path: Path = spec["path"]

    if not path.exists():
        print(
            f"[FAIL: missing section <artefact file not found> in {path}]",
            file=sys.stderr,
        )
        return 1

    text = path.read_text(encoding="utf-8")
    failures: list[str] = []

    for section in spec.get("sections", []):
        if section not in text:
            failures.append(
                f"[FAIL: missing section {section} in {path}]"
            )

    for literal in spec.get("extra_literals", []):
        if literal not in text:
            failures.append(
                f"[FAIL: missing section {literal} (screen literal) in {path}]"
            )

    if spec.get("custom") == "pricing":
        failures.extend(_check_pricing(text, path))

    if failures:
        for f in failures:
            print(f, file=sys.stderr)
        print(
            f"\naudit_artefact_shape: FAIL — {args.artefact_name} shape "
            f"broken ({len(failures)} issue(s))",
            file=sys.stderr,
        )
        return 1

    print(
        f"audit_artefact_shape: OK — {args.artefact_name} shape valid at {path}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
