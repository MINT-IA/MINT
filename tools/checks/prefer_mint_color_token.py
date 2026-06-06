#!/usr/bin/env python3
"""LINT-01 — prefer_mint_color_token (Phase MVP-DESIGN-LINTS-V1).

Block raw color literals outside `apps/mobile/lib/theme/`:
  - `Color(0xFF...)` / `Color(0xAARRGGBB)` hex constructor calls
  - Material `Colors.{white,black,transparent,red,green,blue,grey,yellow,...}` references

Phase 1 of the chat-as-verb milestone. Token registry is `lib/theme/colors.dart`.

Behaviour:
  - Scope: `apps/mobile/lib/` recursively (override via --scope-root for tests).
  - Excludes: `lib/theme/`, `lib/l10n/`, `*.g.dart`, `*.freezed.dart`, `test/`,
    `test_driver/`, `.dart_tool/`, `build/`.
  - Inline escape: `// lint-ignore: prefer_mint_color_token` on the same line.
  - Baseline: `tools/checks/baselines/prefer_mint_color_token.baseline.txt`
    contains grandfathered `path:line: snippet` rows. Net-new violations fail.
  - Lefthook: pass `--file <path>` (action='append'), repeated per staged file.
  - CI: full-repo scan (no --file).

Exit codes:
  0 — clean (current ⊆ baseline) OR --update-baseline succeeded OR baseline absent (INFO).
  1 — net-new violations (diagnostic on stdout).

Per RESEARCH.md §Code Examples lines 564-597 and PLAN-CHECK §3 R1/R2 amendments.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

LINT_NAME = "prefer_mint_color_token"

REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = REPO / "apps" / "mobile" / "lib"
DEFAULT_BASELINE = (
    Path(__file__).resolve().parent / "baselines" / f"{LINT_NAME}.baseline.txt"
)

# `Color(0xFF...)` constructor — RGB or ARGB.
HEX_PATTERN = re.compile(r"\bColor\(\s*0x([0-9A-Fa-f]{6,8})\s*\)")

# Material `Colors.<name>` — covers white, black, transparent, red, green, blue,
# grey, yellow, cyan, amber, orange, pink, purple, indigo, teal, lime, brown.
# Excludes `Colors.MintColors` (impossible) and any chained access via dot.
MATERIAL_PATTERN = re.compile(
    r"\bColors\.("
    r"white|black|transparent|red|green|blue|grey|gray|yellow|cyan|"
    r"amber|orange|pink|purple|indigo|teal|lime|brown|deepOrange|deepPurple|"
    r"lightBlue|lightGreen|blueGrey"
    r")\b"
)

EXCLUDE_DIRS = (
    "/lib/theme/",
    "/lib/l10n/",
    "/test/",
    "/test_driver/",
    "/.dart_tool/",
    "/build/",
    "/tools/checks/tests/fixtures/",  # synthetic test fixtures
)
EXCLUDE_SUFFIXES = (".g.dart", ".freezed.dart")
IGNORE_MARKER = f"// lint-ignore: {LINT_NAME}"


def _is_excluded(rel_posix: str) -> bool:
    norm = "/" + rel_posix.lstrip("/") + "/"
    if any(ex in norm for ex in EXCLUDE_DIRS):
        return True
    if rel_posix.endswith(EXCLUDE_SUFFIXES):
        return True
    return False


def _scan_file(path: Path, scope_root: Path) -> list[str]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    rel = path.relative_to(scope_root.parent if scope_root.is_dir() else REPO).as_posix() \
        if scope_root != REPO else path.relative_to(REPO).as_posix()
    # Always normalise to scope-relative posix for stable baseline keys.
    try:
        rel = path.relative_to(scope_root).as_posix()
        rel = f"{scope_root.name}/{rel}" if scope_root.name else rel
    except ValueError:
        rel = path.as_posix()
    out: list[str] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        stripped = line.strip()
        if stripped.startswith("//"):
            continue
        if IGNORE_MARKER in line:
            continue
        for pat in (HEX_PATTERN, MATERIAL_PATTERN):
            m = pat.search(line)
            if m:
                snippet = m.group(0)
                out.append(f"{rel}:{lineno}: {snippet}")
                break  # one violation per line is enough
    return out


def scan(scope_root: Path, files: list[Path] | None = None) -> list[str]:
    """Return sorted list of `path:line: snippet` violation rows.

    `path` is rendered relative to `scope_root` (with the scope-name prefix)
    so test invocations (which point scope-root at a tmpdir) produce paths
    like `lib/foo.dart` rather than the absolute tmpdir path.

    Lefthook passes `{staged_files}` as repo-relative paths. `scope_root`
    defaults to `apps/mobile/lib` (absolute). To make `f.relative_to(scope_root)`
    work, both sides must be resolved to absolute. We resolve `files` here.
    """
    scope_root = scope_root.resolve()
    out: list[str] = []
    if files:
        targets = [f.resolve() for f in files if f.exists() and f.suffix == ".dart"]
    else:
        targets = list(scope_root.rglob("*.dart"))

    for f in targets:
        try:
            rel = f.relative_to(scope_root).as_posix()
        except ValueError:
            # File outside scope — skip silently (lefthook passes paths from
            # diff, including non-Dart or out-of-scope edits).
            continue
        if _is_excluded(rel) or _is_excluded(f.as_posix()):
            continue
        for row in _scan_file(f, scope_root):
            out.append(row)
    return sorted(set(out))


def _load_baseline(p: Path) -> set[str]:
    if not p.exists():
        return set()
    return {line for line in p.read_text(encoding="utf-8").splitlines() if line.strip()}


def _write_baseline(p: Path, rows: list[str]) -> None:
    p.parent.mkdir(parents=True, exist_ok=True)
    p.write_text("\n".join(rows) + ("\n" if rows else ""), encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        description=f"{LINT_NAME} — block raw colors outside lib/theme/"
    )
    ap.add_argument(
        "--file",
        action="append",
        type=Path,
        default=None,
        help="Lint a single file (repeat for multiple staged files; lefthook mode)",
    )
    ap.add_argument(
        "--scope-root",
        type=Path,
        default=DEFAULT_SCOPE,
        help="Scope root (defaults to apps/mobile/lib; override for tests)",
    )
    ap.add_argument(
        "--baseline",
        type=Path,
        default=DEFAULT_BASELINE,
        help=f"Baseline file (default {DEFAULT_BASELINE.relative_to(REPO)})",
    )
    ap.add_argument(
        "--update-baseline",
        action="store_true",
        help="Re-snapshot the baseline file from current scan (after a sweep PR)",
    )
    ap.add_argument(
        "files",
        nargs="*",
        type=Path,
        help="Additional file paths accepted for lefthook `--file {staged_files}` expansion",
    )
    args = ap.parse_args(argv)

    scope_root: Path = args.scope_root
    if not scope_root.exists():
        # Lefthook may pass --file paths even when the scope-root is missing
        # (e.g. checked out subset). Treat as no-op.
        print(f"INFO {LINT_NAME}: scope-root {scope_root} missing — nothing to scan")
        return 0

    files = [*(args.file or []), *args.files]
    current = scan(scope_root, files=files)

    if args.update_baseline:
        _write_baseline(args.baseline, current)
        print(
            f"OK {LINT_NAME}: baseline updated "
            f"({len(current)} entries → {args.baseline.relative_to(REPO) if args.baseline.is_absolute() and REPO in args.baseline.parents else args.baseline})"
        )
        return 0

    if not args.baseline.exists():
        print(
            f"INFO {LINT_NAME}: no baseline yet at {args.baseline} — "
            "run with --update-baseline to seed. Skipping enforcement this run."
        )
        return 0

    if args.baseline.stat().st_size == 0:
        baseline = set()
    else:
        baseline = _load_baseline(args.baseline)

    current_set = set(current)
    new = sorted(current_set - baseline)
    if new:
        print(f"::error::{LINT_NAME}: {len(new)} new violation(s):")
        for v in new:
            print(v)
        print()
        print(
            f"Fix: replace raw `Color(0xFF...)` / `Colors.<name>` with "
            f"`MintColors.<token>` (see apps/mobile/lib/theme/colors.dart). "
            f"If unavoidable for this site, add `// lint-ignore: {LINT_NAME}` "
            f"on the same line."
        )
        return 1

    # In single-file mode (lefthook), `current` covers only the staged
    # files — it is NOT a full-repo snapshot, so `baseline - current` is
    # NOT a meaningful « removed » count. Suppress the shrink-suggestion
    # message in that mode; full-repo mode (CI) still surfaces it.
    if files:
        print(f"OK {LINT_NAME}: clean (staged scope, baseline unchanged)")
        return 0

    removed = baseline - current_set
    if removed:
        print(
            f"OK {LINT_NAME}: clean (-{len(removed)} from baseline). "
            f"Run `python3 tools/checks/{LINT_NAME}.py --update-baseline` "
            f"to shrink the baseline file."
        )
    else:
        print(f"OK {LINT_NAME}: clean ({len(current)} grandfathered)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
