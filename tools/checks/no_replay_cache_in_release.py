#!/usr/bin/env python3
# tools/checks/no_replay_cache_in_release.py
#
# Phase A5 (v2.13) — block any release-bound workflow from passing
# `MINT_LLM_CACHE_MODE=replay` (or `=record`) as a dart-define. The
# replay cache is debug/profile only ; production users must hit the
# live backend. Belt + suspenders alongside :
#   - llm_replay_cache.dart `kReleaseMode` early-return in `mode` getter
#   - llm_replay_cache.dart `kReleaseMode` StateError in `lookup`
#   - testflight.yml pre-build asset strip
#
# Usage : invoked by lefthook (pre-commit) and CI ci.yml.
# Exit codes : 0 clean / 1 violation found.

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[2]
WORKFLOWS_DIR = REPO_ROOT / ".github" / "workflows"

# Workflows that build / ship release-bound artefacts.
RELEASE_WORKFLOWS = {
    "testflight.yml",
    "play-store.yml",
    "web.yml",
}

# `record` is included because it ALSO bypasses the live path on hit.
# Match only real dart-define ASSIGNMENTS, not bash glob comparisons
# (`*"MINT_LLM_CACHE_MODE=replay"*`) used inside guard expressions.
FORBIDDEN = re.compile(
    r"--dart-define\s*=\s*MINT_LLM_CACHE_MODE\s*=\s*(replay|record)\b"
)


STRIP_LINE = re.compile(r"rm\s+-rf\s+[^\s]*assets/llm_replay_cache")


def main() -> int:
    if not WORKFLOWS_DIR.exists():
        print(f"[skip] no workflows dir at {WORKFLOWS_DIR}")
        return 0

    violations: list[tuple[Path, int, str]] = []
    missing_strip: list[Path] = []
    for wf_name in RELEASE_WORKFLOWS:
        wf_path = WORKFLOWS_DIR / wf_name
        if not wf_path.exists():
            continue
        text = wf_path.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), start=1):
            # Allow guard / lint references that mention the flag literally
            # without setting it.
            if "::error::" in line or line.lstrip().startswith("#"):
                continue
            if FORBIDDEN.search(line):
                violations.append((wf_path, lineno, line.strip()))
        # Phase A5 panel hardening — every release workflow MUST contain
        # an asset-strip line for the replay-cache dir, fail-closed.
        # Without this, a future fixture sub-tree (e.g. a renamed dir)
        # would silently ship to production.
        if not STRIP_LINE.search(text):
            missing_strip.append(wf_path)

    fail = False
    if violations:
        print("[fail] MINT_LLM_CACHE_MODE=replay/record found in release workflows :")
        for path, lineno, line in violations:
            rel = path.relative_to(REPO_ROOT)
            print(f"  {rel}:{lineno}  {line}")
        print(
            "\nThe replay cache is debug/profile only. Release builds must hit\n"
            "the live backend. Remove the dart-define from the workflow."
        )
        fail = True

    if missing_strip:
        print("[fail] release workflow missing assets/llm_replay_cache strip :")
        for path in missing_strip:
            rel = path.relative_to(REPO_ROOT)
            print(f"  {rel}  (expected line matching: rm -rf .../assets/llm_replay_cache)")
        print(
            "\nEvery release-bound build MUST strip the dev-only LLM replay\n"
            "cache fixtures before flutter build, even though kReleaseMode\n"
            "guards the runtime path. Add a `rm -rf` step before the build."
        )
        fail = True

    if fail:
        return 1

    print("[ok] no replay-cache dart-define + every release workflow strips fixtures")
    return 0


if __name__ == "__main__":
    sys.exit(main())
