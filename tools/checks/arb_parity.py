#!/usr/bin/env python3
"""Phase 34 GUARD-05 — ARB key-set parity lint.

Compares the key sets of the 6 MINT ARB files (fr / en / de / es / it / pt)
against the FR reference locale (CLAUDE.md TOP rule #5: « i18n required —
6 ARB files under apps/mobile/lib/l10n/ »).

Parity holds when every non-metadata key present in `app_fr.arb` is also
present in each of the 5 other locales, and vice versa. Metadata keys
(those starting with `@` or `_`) are excluded — they describe the
schema, not user-facing strings.

Exits:
  0 — parity holds across all 6 locales.
  1 — drift detected (missing or extra keys vs FR reference).
  2 — usage / argument / missing-file error.

Python 3.9-compatible (matches project convention). stdlib-only.

Usage:
    python3 tools/checks/arb_parity.py
    python3 tools/checks/arb_parity.py --locale en           # check one locale only
    python3 tools/checks/arb_parity.py --reference fr        # default
    python3 tools/checks/arb_parity.py --sample 10           # show up to N missing/extra per locale
"""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
ARB_DIR = REPO_ROOT / "apps" / "mobile" / "lib" / "l10n"
LOCALES = ("fr", "en", "de", "es", "it", "pt")
DEFAULT_REFERENCE = "fr"
DEFAULT_SAMPLE = 5


def _load_keys(arb_path: Path) -> Set[str]:
    """Return the set of user-facing keys in an ARB file.

    Excludes metadata keys: those starting with `@` (Flutter ARB convention
    for placeholder/description metadata) or `_` (project-internal comments).
    """
    if not arb_path.is_file():
        raise FileNotFoundError(f"ARB file missing: {arb_path}")
    try:
        data = json.loads(arb_path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        raise ValueError(f"malformed ARB {arb_path}: {exc}") from exc
    if not isinstance(data, dict):
        raise ValueError(f"ARB root must be a JSON object: {arb_path}")
    return {k for k in data if not k.startswith(("@", "_"))}


def _diff(reference: Set[str], other: Set[str]) -> Tuple[Set[str], Set[str]]:
    """Return (missing_in_other, extra_in_other) vs the reference."""
    return reference - other, other - reference


def _format_drift(
    locale: str, missing: Set[str], extra: Set[str], sample: int
) -> str:
    out = [f"  [{locale}] missing={len(missing):3d}  extra={len(extra):3d}"]
    if missing:
        sample_keys = sorted(missing)[:sample]
        out.append(f"     missing sample: {sample_keys}")
    if extra:
        sample_keys = sorted(extra)[:sample]
        out.append(f"     extra sample:   {sample_keys}")
    return "\n".join(out)


def _build_parser() -> argparse.ArgumentParser:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument(
        "--locale",
        choices=list(LOCALES) + ["all"],
        default="all",
        help="check a single locale against reference (default: all 5 non-reference)",
    )
    p.add_argument(
        "--reference",
        choices=list(LOCALES),
        default=DEFAULT_REFERENCE,
        help=f"reference locale (default: {DEFAULT_REFERENCE})",
    )
    p.add_argument(
        "--sample",
        type=int,
        default=DEFAULT_SAMPLE,
        help=f"max missing/extra keys to print per locale (default: {DEFAULT_SAMPLE})",
    )
    p.add_argument(
        "--arb-dir",
        type=Path,
        default=ARB_DIR,
        help="override ARB directory (used by tests)",
    )
    return p


def main(argv: list | None = None) -> int:
    args = _build_parser().parse_args(argv)
    arb_dir: Path = args.arb_dir

    keysets: Dict[str, Set[str]] = {}
    for loc in LOCALES:
        path = arb_dir / f"app_{loc}.arb"
        try:
            keysets[loc] = _load_keys(path)
        except FileNotFoundError as exc:
            print(f"FAIL — {exc}", file=sys.stderr)
            return 2
        except ValueError as exc:
            print(f"FAIL — {exc}", file=sys.stderr)
            return 2

    ref = args.reference
    targets = (
        [args.locale] if args.locale != "all" else [l for l in LOCALES if l != ref]
    )
    if ref in targets:
        targets.remove(ref)

    drift_lines = []
    total_missing = 0
    total_extra = 0
    for loc in targets:
        missing, extra = _diff(keysets[ref], keysets[loc])
        if missing or extra:
            drift_lines.append(_format_drift(loc, missing, extra, args.sample))
            total_missing += len(missing)
            total_extra += len(extra)

    if not drift_lines:
        ref_count = len(keysets[ref])
        n_locales = len(targets) + 1
        print(
            f"OK — {n_locales} locale(s) parity (reference={ref}, "
            f"{ref_count} keys each)."
        )
        return 0

    print("ARB parity drift detected:\n", file=sys.stderr)
    for line in drift_lines:
        print(line, file=sys.stderr)
    print(
        f"\n{total_missing} missing + {total_extra} extra key(s) across "
        f"{len(drift_lines)} locale(s). Run `flutter gen-l10n` after syncing "
        f"keys, or update the FR reference and propagate.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
