#!/usr/bin/env python3
"""LINT-03 — prefer_mint_fonts (Phase MVP-DESIGN-LINTS-V1).

Block `GoogleFonts.<family>` and `TextStyle(fontFamily: '...')` outside
`apps/mobile/lib/theme/`. The token registry encapsulates font selection in
`MintTextStyles.*` builders inside `lib/theme/mint_text_styles.dart`.

Phase 3 (MVP-FONTS-TOKENS-V2) will land local Supreme + Gambarino + Fraunces
fonts and drop the `google_fonts` package. This lint prevents Phase 3's
sweep PRs from re-introducing GoogleFonts.* in the same edit.

Behaviour:
  - Two patterns ORed: `\\bGoogleFonts\\.<word>` and `fontFamily\\s*:\\s*['"]`.
  - Excludes lib/theme/, lib/l10n/, *.g.dart, test/, build/.
  - Inline escape: `// lint-ignore: prefer_mint_fonts`.

Per RESEARCH.md §LINT-03 + PLAN-CHECK §3 R1/R2.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

LINT_NAME = "prefer_mint_fonts"
REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = REPO / "apps" / "mobile" / "lib"
DEFAULT_BASELINE = (
    Path(__file__).resolve().parent / "baselines" / f"{LINT_NAME}.baseline.txt"
)

GOOGLE_FONTS_PATTERN = re.compile(r"\bGoogleFonts\.([A-Za-z_][A-Za-z0-9_]*)")
FONT_FAMILY_PATTERN = re.compile(r"\bfontFamily\s*:\s*['\"]")

EXCLUDE_DIRS = (
    "/lib/theme/",
    "/lib/l10n/",
    "/test/",
    "/test_driver/",
    "/.dart_tool/",
    "/build/",
    "/tools/checks/tests/fixtures/",
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
    try:
        rel = f"{scope_root.name}/{path.relative_to(scope_root).as_posix()}"
    except ValueError:
        rel = path.as_posix()
    out: list[str] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("//"):
            continue
        if IGNORE_MARKER in line:
            continue
        m = GOOGLE_FONTS_PATTERN.search(line) or FONT_FAMILY_PATTERN.search(line)
        if m:
            out.append(f"{rel}:{lineno}: {m.group(0)}")
    return out


def scan(scope_root: Path, files: list[Path] | None = None) -> list[str]:
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
            continue
        if _is_excluded(rel) or _is_excluded(f.as_posix()):
            continue
        out.extend(_scan_file(f, scope_root))
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
        description=f"{LINT_NAME} — block GoogleFonts.* and raw fontFamily outside lib/theme/"
    )
    ap.add_argument("--file", action="append", type=Path, default=None)
    ap.add_argument("--scope-root", type=Path, default=DEFAULT_SCOPE)
    ap.add_argument("--baseline", type=Path, default=DEFAULT_BASELINE)
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("files", nargs="*", type=Path)
    args = ap.parse_args(argv)

    if not args.scope_root.exists():
        print(f"INFO {LINT_NAME}: scope-root {args.scope_root} missing")
        return 0

    files = [*(args.file or []), *args.files]
    current = scan(args.scope_root, files=files)

    if args.update_baseline:
        _write_baseline(args.baseline, current)
        print(f"OK {LINT_NAME}: baseline updated ({len(current)} entries)")
        return 0

    if not args.baseline.exists():
        print(
            f"INFO {LINT_NAME}: no baseline yet at {args.baseline} — "
            "run with --update-baseline to seed."
        )
        return 0

    baseline = _load_baseline(args.baseline)
    new = sorted(set(current) - baseline)
    if new:
        print(f"::error::{LINT_NAME}: {len(new)} new violation(s):")
        for v in new:
            print(v)
        print()
        print(
            f"Fix: replace `GoogleFonts.<x>()` / raw `fontFamily:` with a "
            f"`MintTextStyles.<token>()` builder. The single legal site for "
            f"GoogleFonts.* is apps/mobile/lib/theme/mint_text_styles.dart. "
            f"If unavoidable, add `// lint-ignore: {LINT_NAME}` on the same line."
        )
        return 1

    if files:
        print(f"OK {LINT_NAME}: clean (staged scope, baseline unchanged)")
        return 0

    removed = baseline - set(current)
    if removed:
        print(f"OK {LINT_NAME}: clean (-{len(removed)} from baseline)")
    else:
        print(f"OK {LINT_NAME}: clean ({len(current)} grandfathered)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
