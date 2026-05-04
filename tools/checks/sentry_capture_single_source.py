#!/usr/bin/env python3
"""Phase 31 OBS-02 (c) — ban direct Sentry.captureException outside the
single-source error boundary.

Scans apps/mobile/lib/ recursively (excluding generated code) for any
call to `Sentry.captureException(`. The only files allowed to invoke it
are the whitelisted single-source modules:

  - apps/mobile/lib/services/error_boundary.dart          (Wave 1 creates this)
  - apps/mobile/lib/services/sentry_breadcrumbs.dart      (Wave 1 creates this)

Any other match = violation, exit 1 with file:line:snippet output.

WAVE 0 SEMANTICS:
  At Wave 0 commit time, NEITHER whitelisted file exists yet. That is
  fine — the lint simply reports `[INFO] error_boundary.dart not present
  yet (Wave 1 creates it)` and scans the rest of lib/ for violations.
  The ban kicks in fully once Wave 1 lands the single-source module.

The lint enforces the 'one boundary, one capture' invariant locked by
D-A3 (3-prongs + single capture — rejects runZonedGuarded). Paired with
the Flutter unit test `error_boundary_single_capture_test.dart` which
asserts exactly-once dispatch at runtime.

Exclusions:
  - *.g.dart (code-gen)
  - apps/mobile/lib/generated/**
  - apps/mobile/lib/l10n/**   (generated i18n)

Exit codes:
  0  no violations (or only whitelisted hits)
  1  at least one non-whitelisted Sentry.captureException( call found

Usage:
    python3 tools/checks/sentry_capture_single_source.py
"""
from __future__ import annotations

import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
LIB_ROOT = REPO_ROOT / "apps" / "mobile" / "lib"

# Relative-to-LIB_ROOT paths of the ONLY files allowed to call
# Sentry.captureException. Wave 1 Plan 31-01 creates these.
WHITELIST = {
    Path("services") / "error_boundary.dart",
    Path("services") / "sentry_breadcrumbs.dart",
}

EXCLUDE_SUFFIXES = (".g.dart",)
EXCLUDE_DIRS = {"generated", "l10n"}

PATTERN = "Sentry.captureException("


def _is_excluded(path: Path) -> bool:
    if path.name.endswith(EXCLUDE_SUFFIXES):
        return True
    try:
        rel = path.relative_to(LIB_ROOT)
    except ValueError:
        return False
    for part in rel.parts:
        if part in EXCLUDE_DIRS:
            return True
    return False


def main() -> int:
    if not LIB_ROOT.is_dir():
        print(f"[FAIL] lib/ not found at {LIB_ROOT}", file=sys.stderr)
        return 1

    violations: list[str] = []
    whitelisted_hits: list[str] = []
    scanned = 0

    for dart_path in sorted(LIB_ROOT.rglob("*.dart")):
        if _is_excluded(dart_path):
            continue
        scanned += 1
        rel = dart_path.relative_to(LIB_ROOT)

        try:
            text = dart_path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            # Skip non-UTF8 files; not expected in lib/ but defensive.
            continue

        if PATTERN not in text:
            continue

        for i, line in enumerate(text.splitlines(), start=1):
            if PATTERN in line:
                msg = f"{dart_path}:{i}: {line.strip()}"
                if rel in WHITELIST:
                    whitelisted_hits.append(msg)
                else:
                    violations.append(msg)

    # Wave 0 info line: flag whitelisted files that don't exist yet.
    for wl in sorted(WHITELIST, key=str):
        target = LIB_ROOT / wl
        if not target.exists():
            print(
                f"[INFO] {wl.as_posix()} not present yet (Wave 1 creates it)"
            )

    if whitelisted_hits:
        print(
            f"[INFO] {len(whitelisted_hits)} whitelisted "
            f"Sentry.captureException hit(s):"
        )
        for hit in whitelisted_hits:
            print(f"  {hit}")

    if violations:
        print("", file=sys.stderr)
        print(
            f"sentry_capture_single_source: FAIL — "
            f"{len(violations)} non-whitelisted Sentry.captureException "
            f"call(s) (scanned {scanned} .dart file(s))",
            file=sys.stderr,
        )
        for v in violations:
            print(f"  {v}", file=sys.stderr)
        print(
            "\nFix: route the capture through "
            "services/error_boundary.dart (single source).",
            file=sys.stderr,
        )
        return 1

    print(
        f"sentry_capture_single_source: OK — scanned {scanned} .dart file(s), "
        f"0 violations ({len(whitelisted_hits)} whitelisted hit(s))"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
