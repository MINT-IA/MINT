#!/usr/bin/env python3
"""Phase 31 OBS-01 audit — verify Sentry init invariants in main.dart.

This is a greppable-discipline lint over:
  - apps/mobile/pubspec.yaml   (sentry_flutter pin)
  - apps/mobile/lib/main.dart  (SentryFlutter.init options)

It mechanically asserts that the CTX-05 spike output (Phase 30.6-02) is
still in place. Any future edit that drops maskAllText / maskAllImages /
sendDefaultPii / SentryWidget fails this lint — the façade-sans-câblage
Pitfall 10 mitigation at the mechanical-gate level, not a 'I read the
file' claim.

Covered invariants:

Hard literal presence (case-sensitive):
  - pubspec.yaml: `sentry_flutter: 9.14.0` exact pin (D-01 + STACK.md)
  - main.dart: `SentryWidget(child:` wraps runApp
  - main.dart: `options.privacy.maskAllText = true`  (A1 PITFALLS nLPD kill-gate)
  - main.dart: `options.privacy.maskAllImages = true`
  - main.dart: `options.tracePropagationTargets`
  - main.dart: `options.sendDefaultPii = false`
  - main.dart: `options.replay.onErrorSampleRate = 1.0`

Presence-only (value-agnostic) regex:
  - main.dart: `options\.replay\.sessionSampleRate\s*=`
    Value is env-dependent (prod=0.0 / staging=0.10 / dev=1.0 per D-01 Option C).
    Only presence is enforced — value assertion would break after Plan 31-01
    Task 2 ships the ternary that replaces the current literal `= 0.05`.

Exit code:
  0  all checks pass
  1  at least one check failed (detailed [FAIL: ...] lines on stderr)

Usage:
    python3 tools/checks/verify_sentry_init.py
"""
from __future__ import annotations

import re
import sys
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[2]
PUBSPEC = REPO_ROOT / "apps" / "mobile" / "pubspec.yaml"
MAIN_DART = REPO_ROOT / "apps" / "mobile" / "lib" / "main.dart"

# (literal, human-readable label)
PUBSPEC_LITERALS: list[tuple[str, str]] = [
    ("sentry_flutter: 9.14.0", "sentry_flutter pin (D-01)"),
]

MAIN_DART_LITERALS: list[tuple[str, str]] = [
    ("SentryWidget(child:", "SentryWidget wraps runApp"),
    ("options.privacy.maskAllText = true", "maskAllText=true (nLPD A1)"),
    ("options.privacy.maskAllImages = true", "maskAllImages=true (nLPD A1)"),
    ("options.tracePropagationTargets", "tracePropagationTargets allowlist"),
    ("options.sendDefaultPii = false", "sendDefaultPii=false (nLPD)"),
    ("options.replay.onErrorSampleRate = 1.0", "onErrorSampleRate=1.0"),
]

# (regex, human-readable label, rationale-for-presence-only)
MAIN_DART_REGEXES: list[tuple[str, str]] = [
    (
        r"options\.replay\.sessionSampleRate\s*=",
        "sessionSampleRate present (value env-dependent per D-01 Option C)",
    ),
]


def _line_number(text: str, literal: str) -> int:
    """Return 1-based line of first match, or 0 if absent."""
    for i, line in enumerate(text.splitlines(), start=1):
        if literal in line:
            return i
    return 0


def _regex_line_number(text: str, pattern: str) -> int:
    rx = re.compile(pattern)
    for i, line in enumerate(text.splitlines(), start=1):
        if rx.search(line):
            return i
    return 0


def main() -> int:
    failures: list[str] = []
    passes: list[str] = []

    if not PUBSPEC.exists():
        print(f"[FAIL] pubspec not found at {PUBSPEC}", file=sys.stderr)
        return 1
    if not MAIN_DART.exists():
        print(f"[FAIL] main.dart not found at {MAIN_DART}", file=sys.stderr)
        return 1

    pubspec_text = PUBSPEC.read_text(encoding="utf-8")
    main_text = MAIN_DART.read_text(encoding="utf-8")

    # Pubspec literals
    for literal, label in PUBSPEC_LITERALS:
        line = _line_number(pubspec_text, literal)
        if line:
            passes.append(f"[PASS] pubspec.yaml:{line}  {label} -> '{literal}'")
        else:
            failures.append(
                f"[FAIL: missing literal] pubspec.yaml  {label} -> "
                f"expected '{literal}'"
            )

    # main.dart literals
    for literal, label in MAIN_DART_LITERALS:
        line = _line_number(main_text, literal)
        if line:
            passes.append(f"[PASS] main.dart:{line}  {label} -> '{literal}'")
        else:
            failures.append(
                f"[FAIL: missing literal] main.dart  {label} -> "
                f"expected '{literal}'"
            )

    # main.dart regexes
    for pattern, label in MAIN_DART_REGEXES:
        line = _regex_line_number(main_text, pattern)
        if line:
            passes.append(f"[PASS] main.dart:{line}  {label} -> /{pattern}/")
        else:
            failures.append(
                f"[FAIL: missing pattern] main.dart  {label} -> /{pattern}/"
            )

    for p in passes:
        print(p)

    if failures:
        print("", file=sys.stderr)
        for f in failures:
            print(f, file=sys.stderr)
        print(
            f"\nverify_sentry_init: FAIL — {len(failures)} invariant(s) broken "
            f"({len(passes)} ok)",
            file=sys.stderr,
        )
        return 1

    print(
        f"\nverify_sentry_init: OK — {len(passes)}/{len(passes)} "
        f"invariants green (OBS-01 audit PASS on CTX-05 spike output)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
