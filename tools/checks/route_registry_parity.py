#!/usr/bin/env python3
"""Phase 32 MAP-04 — route registry parity lint.

Compares path literals extracted from `apps/mobile/lib/app.dart` (via
`GoRoute|ScopedGoRoute(path: ...)` regex) against the keys of
`kRouteRegistry` in `apps/mobile/lib/routes/route_metadata.dart`.

Exits:
  0 — parity holds (after KNOWN-MISSES exemption).
  1 — drift detected (registry missing a route OR ghost key with no route).
  2 — usage / argument / missing-file error (sysexits.h EX_USAGE).

Respects `tools/checks/route_registry_parity-KNOWN-MISSES.md` category
signals. Specifically:

  * Category 2 (ternary `path: x ? '/a' : '/b'`) and Category 3 (dynamic
    `path: _fn(seg)`) are structurally uncapturable by the regex — the
    lint simply does not see them, so they cannot false-positive.
  * Category 5 (nested `routes: [...]` sub-routes) is handled by
    exempting known bare segments + their composed `/parent/child`
    registry form from comparison (see `_NESTED_PROFILE_CHILDREN`).
  * Category 7 (admin-only compile-conditional routes) is handled by
    exempting `/admin/routes` from comparison (see `_ADMIN_CONDITIONAL`).

If an unknown regex miss is suspected: audit with `--extract-only` then
update KNOWN-MISSES.md per the maintenance policy at the bottom of that file.

Usage:
    python3 tools/checks/route_registry_parity.py
    python3 tools/checks/route_registry_parity.py --extract-only apps/mobile/lib/app.dart
    python3 tools/checks/route_registry_parity.py --dry-run-fixture tests/checks/fixtures/parity_drift.dart

Python 3.9-compatible (dev 3.9.6, CI 3.11). stdlib-only.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import List, Optional, Set, Tuple

REPO_ROOT = Path(__file__).resolve().parents[2]
APP_DART = REPO_ROOT / "apps" / "mobile" / "lib" / "app.dart"
REGISTRY_DART = REPO_ROOT / "apps" / "mobile" / "lib" / "routes" / "route_metadata.dart"

# ---------------------------------------------------------------------------
# KNOWN-MISSES allow-lists (see tools/checks/route_registry_parity-KNOWN-MISSES.md)
# ---------------------------------------------------------------------------
# Category 7 — admin-only compile-conditional routes.
# `/admin/routes` is declared in app.dart inside `if (AdminGate.isAvailable) ...[`
# and is INTENTIONALLY absent from kRouteRegistry (dev-only surface, tree-shaken
# in prod builds per D-06 + D-10). Adding new admin-conditional routes requires
# updating both this set AND KNOWN-MISSES.md Category 7.
_ADMIN_CONDITIONAL: Set[str] = {
    "/admin/routes",
}

# Category 5 — nested `routes: [...]` child segments.
# These bare segments are declared under parent `/profile` at app.dart L906+.
# At runtime go_router composes parent + child -> `/profile/<segment>`.
# The regex captures the bare segment (left side); the registry stores the
# composed form (right side per CONTEXT D-04 nested-route guidance).
# Both sides are excluded from comparison to prevent false-positive drift.
# Adding new nested children requires updating this mapping AND
# KNOWN-MISSES.md Category 5.
_NESTED_PROFILE_CHILDREN: List[Tuple[str, str]] = [
    ("admin-observability", "/profile/admin-observability"),
    ("admin-analytics", "/profile/admin-analytics"),
    ("byok", "/profile/byok"),
    ("slm", "/profile/slm"),
    ("bilan", "/profile/bilan"),
    ("privacy-control", "/profile/privacy-control"),
    ("privacy", "/profile/privacy"),
]

# ---------------------------------------------------------------------------
# Regex library
# ---------------------------------------------------------------------------
# Matches both `GoRoute(...)` and `ScopedGoRoute(...)` path declarations.
# DOTALL lets the regex cross newlines between `(` and `path:` (108 multi-line
# constructor entries at HEAD-b7a88cc8 use this shape). The non-greedy
# `[^)]*?` prevents swallowing the whole route list.
_GOROUTE_RE = re.compile(
    r"""(?:GoRoute|ScopedGoRoute)\s*\(       # constructor
        [^)]*?                                 # any preceding kwargs (scope:, name:, ...)
        path\s*:\s*                            # path kwarg
        (?P<q>['"])(?P<path>[^'"]+?)(?P=q)     # captured path literal
    """,
    re.VERBOSE | re.DOTALL,
)

# Category 2 — ternary path expression (regex-unparsable, counted only).
_TERNARY_PATH_RE = re.compile(
    r"""(?:GoRoute|ScopedGoRoute)\s*\(
        [^)]*?
        path\s*:\s*[A-Za-z_][A-Za-z0-9_]*\s*\?
    """,
    re.VERBOSE | re.DOTALL,
)

# Category 3 — dynamic path builder (regex-unparsable, counted only).
_DYNAMIC_PATH_RE = re.compile(
    r"""(?:GoRoute|ScopedGoRoute)\s*\(
        [^)]*?
        path\s*:\s*_[A-Za-z_][A-Za-z0-9_]*\s*\(
    """,
    re.VERBOSE | re.DOTALL,
)

# `kRouteRegistry` entry keys: literal-string : RouteMeta( at line start.
_REGISTRY_KEY_RE = re.compile(
    r"""^\s*(?P<q>['"])(?P<path>[^'"]+?)(?P=q)\s*:\s*RouteMeta\(""",
    re.MULTILINE,
)


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------
def extract_app_paths(src: str) -> Tuple[Set[str], int, int]:
    """Return (literal_paths, ternary_count, dynamic_count)."""
    paths = {m.group("path") for m in _GOROUTE_RE.finditer(src)}
    ternary = len(_TERNARY_PATH_RE.findall(src))
    dynamic = len(_DYNAMIC_PATH_RE.findall(src))
    return paths, ternary, dynamic


def extract_registry_keys(src: str) -> Set[str]:
    return {m.group("path") for m in _REGISTRY_KEY_RE.finditer(src)}


def _apply_known_misses(app_paths: Set[str], reg_keys: Set[str]) -> Tuple[Set[str], Set[str]]:
    """Strip KNOWN-MISSES exemptions from both sides before comparison.

    Returns (app_paths_cleaned, reg_keys_cleaned).
    """
    # Category 7: admin-conditional — exempt from app side (not in registry).
    app_cleaned = set(app_paths) - _ADMIN_CONDITIONAL

    # Category 5: nested — exempt bare segments from app side AND composed form
    # from registry side. Both halves must exist; if only one is present, we
    # leave the other unexempted so drift is still caught.
    nested_segments = {seg for seg, _ in _NESTED_PROFILE_CHILDREN}
    nested_composed = {composed for _, composed in _NESTED_PROFILE_CHILDREN}
    app_cleaned = app_cleaned - nested_segments
    reg_cleaned = set(reg_keys) - nested_composed

    return app_cleaned, reg_cleaned


# ---------------------------------------------------------------------------
# Core comparison
# ---------------------------------------------------------------------------
def run_parity(app_src: str, registry_src: str) -> int:
    app_paths, ternary, dynamic = extract_app_paths(app_src)
    reg_keys = extract_registry_keys(registry_src)

    app_cmp, reg_cmp = _apply_known_misses(app_paths, reg_keys)
    missing_in_registry = app_cmp - reg_cmp
    ghost_in_registry = reg_cmp - app_cmp

    sys.stderr.write(
        "[info] extracted {n} path literal(s) from app.dart "
        "(ternary={t}, dynamic={d} known-miss, category 2/3 skipped)\n".format(
            n=len(app_paths), t=ternary, d=dynamic
        )
    )
    sys.stderr.write(
        "[info] registry has {n} key(s); {a} admin-conditional + {p} nested-profile entries "
        "exempted per KNOWN-MISSES.md\n".format(
            n=len(reg_keys),
            a=len(_ADMIN_CONDITIONAL & app_paths),
            p=len(_NESTED_PROFILE_CHILDREN),
        )
    )

    if not missing_in_registry and not ghost_in_registry:
        print("[OK] {n} routes parity OK (after KNOWN-MISSES exemption).".format(
            n=len(app_cmp)
        ))
        return 0

    if missing_in_registry:
        sys.stderr.write(
            "[FAIL] {n} path(s) present in app.dart but absent from kRouteRegistry:\n".format(
                n=len(missing_in_registry)
            )
        )
        for p in sorted(missing_in_registry):
            sys.stderr.write("  + {p}\n".format(p=p))
        sys.stderr.write(
            "  Fix: add a RouteMeta entry to apps/mobile/lib/routes/route_metadata.dart\n"
            "  OR, if the pattern is regex-unparsable or intentionally dev-only,\n"
            "  document it in tools/checks/route_registry_parity-KNOWN-MISSES.md\n"
            "  AND update the allow-list constants in this script.\n"
        )

    if ghost_in_registry:
        sys.stderr.write(
            "[FAIL] {n} key(s) present in kRouteRegistry but absent from app.dart (ghost):\n".format(
                n=len(ghost_in_registry)
            )
        )
        for p in sorted(ghost_in_registry):
            sys.stderr.write("  - {p}\n".format(p=p))
        sys.stderr.write(
            "  Fix: remove the stale entry from kRouteRegistry OR restore the\n"
            "  GoRoute/ScopedGoRoute declaration in app.dart.\n"
        )

    return 1


# ---------------------------------------------------------------------------
# Fixture mode (--dry-run-fixture)
# ---------------------------------------------------------------------------
def _extract_block(text: str, start_marker: str, end_marker: str) -> Optional[str]:
    pattern = re.compile(
        r"--\s*" + re.escape(start_marker) + r"\s*--(.*?)--\s*" + re.escape(end_marker) + r"\s*--",
        re.DOTALL,
    )
    m = pattern.search(text)
    return m.group(1) if m else None


def run_fixture(path: Path) -> int:
    """Run parity against a self-contained fixture file.

    The fixture must contain two marker pairs:
        -- BEGIN fake app.dart --  ... -- END fake app.dart --
        -- BEGIN fake registry --  ... -- END fake registry --

    Fixture mode DOES NOT apply the live KNOWN-MISSES exemptions — the
    fixture is a synthetic closed system. This lets drift tests assert
    the raw comparison engine without fighting with production allow-lists.
    """
    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError:
        sys.stderr.write("[FAIL] fixture not found: {p}\n".format(p=path))
        return 2

    app_block = _extract_block(text, "BEGIN fake app.dart", "END fake app.dart")
    reg_block = _extract_block(text, "BEGIN fake registry", "END fake registry")
    if app_block is None or reg_block is None:
        sys.stderr.write(
            "[FAIL] fixture malformed: must contain marker pairs\n"
            "  -- BEGIN fake app.dart -- ... -- END fake app.dart --\n"
            "  -- BEGIN fake registry -- ... -- END fake registry --\n"
        )
        return 2

    app_paths, ternary, dynamic = extract_app_paths(app_block)
    reg_keys = extract_registry_keys(reg_block)

    missing = app_paths - reg_keys
    ghost = reg_keys - app_paths

    sys.stderr.write(
        "[fixture] {p}: extracted={n} ternary={t} dynamic={d} registry={r}\n".format(
            p=path.name,
            n=len(app_paths),
            t=ternary,
            d=dynamic,
            r=len(reg_keys),
        )
    )

    if not missing and not ghost:
        print("[OK] {n} routes parity OK (fixture mode).".format(n=len(app_paths)))
        return 0

    if missing:
        sys.stderr.write("[FAIL] fixture drift — paths in fake app.dart missing from fake registry:\n")
        for p in sorted(missing):
            sys.stderr.write("  + {p}\n".format(p=p))
    if ghost:
        sys.stderr.write("[FAIL] fixture drift — keys in fake registry missing from fake app.dart:\n")
        for p in sorted(ghost):
            sys.stderr.write("  - {p}\n".format(p=p))
    return 1


# ---------------------------------------------------------------------------
# I/O + CLI
# ---------------------------------------------------------------------------
def _read(p: Path) -> str:
    try:
        return p.read_text(encoding="utf-8")
    except FileNotFoundError:
        sys.stderr.write("[FAIL] file not found: {p}\n".format(p=p))
        sys.exit(2)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(
        description="Phase 32 MAP-04 — route registry parity lint.",
    )
    parser.add_argument(
        "--extract-only",
        metavar="FILE",
        help="Print extracted path literals (sorted, one per line) and exit 0.",
    )
    parser.add_argument(
        "--dry-run-fixture",
        metavar="FILE",
        help="Run parity against a self-contained fixture file (see --help).",
    )
    args = parser.parse_args(argv)

    if args.extract_only:
        target = Path(args.extract_only)
        if not target.exists():
            sys.stderr.write("[FAIL] file not found: {p}\n".format(p=target))
            return 2
        src = target.read_text(encoding="utf-8")
        paths, _, _ = extract_app_paths(src)
        for path in sorted(paths):
            print(path)
        return 0

    if args.dry_run_fixture:
        fixture = Path(args.dry_run_fixture)
        if not fixture.exists():
            sys.stderr.write("[FAIL] fixture not found: {p}\n".format(p=fixture))
            return 2
        return run_fixture(fixture)

    # Default: live repo comparison.
    app_src = _read(APP_DART)
    reg_src = _read(REGISTRY_DART)
    return run_parity(app_src, reg_src)


if __name__ == "__main__":
    sys.exit(main())
