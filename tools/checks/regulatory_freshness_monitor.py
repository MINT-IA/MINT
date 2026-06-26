#!/usr/bin/env python3
"""Warn when regulatory constants are due for human review.

This monitor is intentionally warning-first by default. Product/runtime callers
can still use RegulatoryRegistry.check_freshness() to identify stale constants,
but ordinary PR/push CI should not go red only because the calendar advanced.
Use --strict for a deliberate fail-closed review gate.
"""

from __future__ import annotations

import argparse
import sys
from datetime import date
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
BACKEND_ROOT = REPO_ROOT / "services" / "backend"
sys.path.insert(0, str(BACKEND_ROOT))

from app.services.regulatory.registry import RegulatoryRegistry  # noqa: E402


def _build_markdown(*, as_of: date, max_age_days: int, stale: list) -> str:
    lines = [
        "# Regulatory Constants Review Due",
        "",
        f"- Checked at: `{as_of.isoformat()}`",
        f"- SLA: `{max_age_days}` days since `reviewed_at`",
        f"- Stale constants: `{len(stale)}`",
        "",
    ]
    if not stale:
        lines.append("No constants are stale.")
        return "\n".join(lines) + "\n"

    lines.append("| key | reviewed_at | age_days | source |")
    lines.append("|---|---:|---:|---|")
    for param in stale:
        reviewed_at = param.reviewed_at.isoformat() if param.reviewed_at else "missing"
        age = "missing" if param.reviewed_at is None else str((as_of - param.reviewed_at).days)
        source = param.source_url or "missing"
        lines.append(f"| `{param.key}` | `{reviewed_at}` | `{age}` | {source} |")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Regulatory constants freshness monitor.")
    parser.add_argument("--max-age-days", type=int, default=90)
    parser.add_argument("--as-of", type=date.fromisoformat)
    parser.add_argument("--strict", action="store_true")
    parser.add_argument("--markdown-out", type=Path)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args(argv)

    as_of = args.as_of or date.today()
    registry = RegulatoryRegistry.instance()
    stale = registry.check_freshness(max_age_days=args.max_age_days, as_of=as_of)
    stale_keys = [param.key for param in stale]

    if args.markdown_out:
        args.markdown_out.parent.mkdir(parents=True, exist_ok=True)
        args.markdown_out.write_text(
            _build_markdown(as_of=as_of, max_age_days=args.max_age_days, stale=stale),
            encoding="utf-8",
        )

    if args.github_output:
        with args.github_output.open("a", encoding="utf-8") as fh:
            fh.write(f"stale_count={len(stale)}\n")

    if stale:
        print(
            f"::warning::Regulatory constants review due: {len(stale)} "
            f"stale parameter(s) as of {as_of.isoformat()}.",
            file=sys.stderr,
        )
        for key in stale_keys[:20]:
            print(f"stale: {key}", file=sys.stderr)
        if len(stale_keys) > 20:
            print(f"stale: ... {len(stale_keys) - 20} more", file=sys.stderr)
        return 1 if args.strict else 0

    print(
        f"Regulatory freshness OK: 0 stale parameters as of {as_of.isoformat()}."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
