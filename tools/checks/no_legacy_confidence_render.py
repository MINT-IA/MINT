#!/usr/bin/env python3
"""CI gate: no legacy confidence-rendering patterns outside the allowlist.

Phase 8a Plan 08a-03 — mechanical enforcement layer for the MTC migration.
After Phase 8a completes, every `calculation`-confidence rendering surface
outside the 7 DO-NOT-MIGRATE files and the MTC trust dir must consume
`MintTrameConfiance` instead of hand-rolled color/threshold/band logic.

This script grep-scans `apps/mobile/lib/` for known legacy patterns (see
Phase 8a CONTEXT §D-07) and fails the build on any hit in a file that is
NOT on the allowlist.

Scope:
  Walks `apps/mobile/lib/` recursively, reads every `.dart` file, runs the
  pattern list below. Generated l10n files (`l10n/app_localizations*.dart`)
  are skipped unconditionally (they mirror ARB content, not render logic).

Allowlist (file-path exemptions):
  - `apps/mobile/lib/widgets/trust/` (MTC owns its tokens)
  - Engine sources: `confidence_scorer.dart`, `enhanced_confidence_service.dart`,
    `freshness_decay_service.dart`
  - The 7 DO-NOT-MIGRATE logic-gate consumers from AUDIT-01 §DO-NOT-MIGRATE
  - The "residue baseline" — files currently carrying legacy patterns that
    are either (a) already planned for Phase 8a Plan 08a-02 migration but
    not yet executed, or (b) deferred to a later phase per
    `docs/MIGRATION_RESIDUE_8a.md`. Each entry in the residue baseline
    MUST have a corresponding row in that doc.

Escape valve:
  If a legitimate new file needs to reference one of these patterns (e.g.
  a new test helper), add the file to `docs/MIGRATION_RESIDUE_8a.md` with
  a justified reason and a ticket ID, then add it to `RESIDUE_BASELINE`
  below with a comment pointing at the residue doc row.

Exit codes:
  0 — clean (no hits, or all hits are in allowlisted files)
  1 — at least one hit in a non-allowlisted file

Usage:
  python3 tools/checks/no_legacy_confidence_render.py
  python3 tools/checks/no_legacy_confidence_render.py --verbose
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# ─── Pattern list (Phase 8a CONTEXT §D-07, verbatim) ──────────────────────
PATTERNS = [
    # Local color tier mappings — must come from MTC tokens, not per-file
    re.compile(r"_confidenceColor\s*\("),
    re.compile(r"(?<!_)confidenceColor\s*\("),
    # Hard-coded < 70 / < .70 thresholds for confidence labels
    re.compile(r"confidence(?:Score)?\s*<\s*70\b"),
    re.compile(r"confidence(?:Score)?\s*<\s*0?\.70\b"),
    re.compile(r"confidenceLevel\s*<\s*70\b"),
    # Hand-rolled "indicatif" / approximate flags
    re.compile(r"isApproximate\s*="),
    re.compile(r"isApproximate\s*\?"),
    # Hard-coded uncertainty band
    re.compile(r"±\s*15\s*%"),
    re.compile(r"\bplusMinus15\b"),
    # Legacy MintConfidenceNotice consumers (replaced by MTC)
    re.compile(r"MintConfidenceNotice\s*\("),
    # Legacy direct instantiation of migrated widgets
    re.compile(r"\bConfidenceBanner\s*\("),
    re.compile(r"\bConfidenceScoreCard\s*\("),
    re.compile(r"\bConfidenceBreakdownCard\s*\("),
    re.compile(r"\bConfidenceBlocksBar\s*\("),
    # Hand-rolled per-axis bar painters outside the trust dir
    re.compile(r"CustomPainter.*[Cc]onfidence"),
]

SCAN_ROOT = "apps/mobile/lib"

# ─── Hard exclusions (never scanned) ──────────────────────────────────────
# Generated l10n files mirror ARB content and contain user-facing strings
# (including "±15%" inside `instantPremierEclairageConfidence`). They are
# not render-logic files and are excluded from the scan.
EXCLUDE_PATH_PREFIXES = (
    "apps/mobile/lib/l10n/",
)

# ─── Allowlist: engine sources + MTC dir ──────────────────────────────────
ALLOWLIST_DIRS = (
    # MTC owns its tokens and may reference any legacy pattern
    "apps/mobile/lib/widgets/trust/",
)

ALLOWLIST_FILES_ENGINE = {
    # Engine sources — the authority on tier/threshold logic
    "apps/mobile/lib/services/financial_core/confidence_scorer.dart",
    "apps/mobile/lib/services/confidence/enhanced_confidence_service.dart",
    "apps/mobile/lib/services/biography/freshness_decay_service.dart",
}

# ─── DO-NOT-MIGRATE list (AUDIT-01 §DO-NOT-MIGRATE, 7 files, verbatim) ────
# Logic-gate consumers that read `EnhancedConfidence.combined` as an int.
# They never render a chip/banner/visualisation. MTC migration must never
# touch them. The MTC engine output must keep emitting `combined: int`.
ALLOWLIST_FILES_DO_NOT_MIGRATE = {
    "apps/mobile/lib/widgets/coach/progressive_dashboard_widget.dart",
    "apps/mobile/lib/widgets/coach/smart_shortcuts.dart",
    "apps/mobile/lib/widgets/onboarding/premier_eclairage_card.dart",
    "apps/mobile/lib/services/coach/precomputed_insights_service.dart",
    "apps/mobile/lib/services/cap_engine.dart",
    "apps/mobile/lib/services/coach/coach_orchestrator.dart",
    "apps/mobile/lib/services/financial_core/coach_reasoner.dart",
}

# ─── Residue baseline: files currently carrying legacy patterns ──────────
# These are either the 11 Phase 8a migration targets (to be migrated by
# Plan 08a-02, currently un-migrated per 08a-02-batch-a-FAILURE.md) OR
# lower-leverage surfaces deferred to a later phase. Each entry has a
# corresponding row in `docs/MIGRATION_RESIDUE_8a.md`.
#
# The script returns 0 as long as legacy patterns appear ONLY in these
# files. Any new file that introduces a legacy pattern fails the build.
# As Plan 08a-02 migrates each surface, its entry here must be removed
# so the gate tightens monotonically.
RESIDUE_BASELINE = {
    # Phase 8a Plan 08a-02 migration targets (11 surfaces, D-01 table)
    "apps/mobile/lib/widgets/home/confidence_score_card.dart",
    "apps/mobile/lib/widgets/retirement/confidence_banner.dart",
    "apps/mobile/lib/widgets/coach/retirement_hero_zone.dart",
    "apps/mobile/lib/screens/coach/cockpit_detail_screen.dart",
    "apps/mobile/lib/widgets/coach/plan_preview_card.dart",
    "apps/mobile/lib/widgets/confidence_breakdown_card.dart",
    # Lower-leverage residue (deferred to Phase 8b/9/10 per residue doc)
    "apps/mobile/lib/widgets/precision/smart_default_indicator.dart",
    "apps/mobile/lib/widgets/premium/mint_confidence_notice.dart",
    "apps/mobile/lib/screens/documents_screen.dart",
    "apps/mobile/lib/screens/arbitrage/arbitrage_bilan_screen.dart",
    "apps/mobile/lib/screens/onboarding/premier_eclairage_screen.dart",
    "apps/mobile/lib/screens/mortgage/affordability_screen.dart",
    "apps/mobile/lib/screens/demenagement_cantonal_screen.dart",
    # Prompt registry mentions the < 70 threshold in a prompt string; not
    # a renderer, but matches the grep. Engine-adjacent coach prompt.
    "apps/mobile/lib/services/coach/prompt_registry.dart",
}

# Union of all allowlisted file paths (per-file match)
ALLOWLIST_FILES = (
    ALLOWLIST_FILES_ENGINE
    | ALLOWLIST_FILES_DO_NOT_MIGRATE
    | RESIDUE_BASELINE
)


def is_excluded_scan(rel: str) -> bool:
    return any(rel.startswith(p) for p in EXCLUDE_PATH_PREFIXES)


def is_allowlisted(rel: str) -> bool:
    if rel in ALLOWLIST_FILES:
        return True
    if any(rel.startswith(d) for d in ALLOWLIST_DIRS):
        return True
    return False


def scan(repo_root: Path) -> tuple[list[tuple[str, int, str, str]], list[tuple[str, int, str, str]]]:
    """Return (violations, allowlisted_hits)."""
    violations: list[tuple[str, int, str, str]] = []
    allowlisted: list[tuple[str, int, str, str]] = []
    base = repo_root / SCAN_ROOT
    if not base.exists():
        return violations, allowlisted
    for path in base.rglob("*.dart"):
        if not path.is_file():
            continue
        rel = path.relative_to(repo_root).as_posix()
        if is_excluded_scan(rel):
            continue
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        for lineno, line in enumerate(text.splitlines(), start=1):
            for pat in PATTERNS:
                m = pat.search(line)
                if m:
                    entry = (rel, lineno, pat.pattern, line.strip())
                    if is_allowlisted(rel):
                        allowlisted.append(entry)
                    else:
                        violations.append(entry)
                    break  # one pattern per line is enough
    return violations, allowlisted


def main() -> int:
    verbose = "--verbose" in sys.argv
    repo_root = Path(__file__).resolve().parents[2]
    violations, allowlisted = scan(repo_root)

    if verbose and allowlisted:
        print(
            f"no_legacy_confidence_render: {len(allowlisted)} allowlisted hit(s) "
            f"(residue baseline + engine + trust dir):"
        )
        for rel, lineno, pat, line in allowlisted:
            snippet = line if len(line) <= 120 else line[:117] + "..."
            print(f"  [allow] {rel}:{lineno} [/{pat}/]: {snippet}")

    if not violations:
        print(
            "no_legacy_confidence_render: OK — "
            f"zero legacy hits outside allowlist ({len(allowlisted)} allowlisted)"
        )
        return 0

    print(
        f"no_legacy_confidence_render: FAIL — {len(violations)} legacy hit(s) "
        "outside allowlist:",
        file=sys.stderr,
    )
    # Group by file for readability
    by_file: dict[str, list[tuple[int, str, str]]] = {}
    for rel, lineno, pat, line in violations:
        by_file.setdefault(rel, []).append((lineno, pat, line))
    for rel in sorted(by_file):
        print(f"  {rel}:", file=sys.stderr)
        for lineno, pat, line in by_file[rel]:
            snippet = line if len(line) <= 120 else line[:117] + "..."
            print(f"    L{lineno} [/{pat}/]: {snippet}", file=sys.stderr)
    print(
        "\nTo fix: migrate the file to MintTrameConfiance "
        "(see Phase 8a CONTEXT §D-01), OR add it to "
        "docs/MIGRATION_RESIDUE_8a.md with a justified reason + ticket ID, "
        "then add the path to RESIDUE_BASELINE in "
        "tools/checks/no_legacy_confidence_render.py.",
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    sys.exit(main())
