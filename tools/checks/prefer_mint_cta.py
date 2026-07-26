#!/usr/bin/env python3
"""LINT-05 — prefer_mint_cta (Phase MVP-DESIGN-LINTS-V1, baseline-only mode).

Block raw `ElevatedButton(`, `OutlinedButton(`, `FilledButton(`, `TextButton(`
calls outside `apps/mobile/lib/widgets/cta/` and `apps/mobile/lib/theme/`.

This is the « scaffold for upcoming sweep » pattern (RESEARCH §Open Q2 +
LINT-05): Phase 4 (MVP-CTA-UNIFICATION-V1) will create a `MintCTA` widget
with `.primary`, `.secondary`, `.tertiary`, `.destructive` constructors,
and the lint will pivot from baseline-only to hard import-path enforcement.

Phase 1 freezes the 154-site baseline so no new raw button widgets land
during the gap before Phase 4.

Behaviour:
  - Pattern: `\\b(?:Elevated|Outlined|Filled|Text)Button\\s*\\(`.
  - Excludes lib/widgets/cta/, lib/theme/, lib/l10n/, *.g.dart, test/, build/.
  - Inline escape: `// lint-ignore: prefer_mint_cta` on the same line or
    the next formatter-produced argument line.

Per RESEARCH.md §LINT-05 + PLAN-CHECK §3 R1/R2.
"""
from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from _baseline_diff import new_violations  # noqa: E402

LINT_NAME = "prefer_mint_cta"
REPO = Path(__file__).resolve().parents[2]
DEFAULT_SCOPE = REPO / "apps" / "mobile" / "lib"
DEFAULT_BASELINE = (
    Path(__file__).resolve().parent / "baselines" / f"{LINT_NAME}.baseline.txt"
)

PATTERN = re.compile(r"\b(?:Elevated|Outlined|Filled|Text)Button\s*\(")

EXCLUDE_DIRS = (
    "/lib/widgets/cta/",
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
    lines = text.splitlines()
    for lineno, line in enumerate(lines, 1):
        if line.lstrip().startswith("//"):
            continue
        if IGNORE_MARKER in line:
            continue
        m = PATTERN.search(line)
        if m:
            if lineno < len(lines) and IGNORE_MARKER in lines[lineno]:
                continue
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
        description=(
            f"{LINT_NAME} — block raw button widgets outside lib/widgets/cta/"
        )
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
    new = new_violations(current, baseline)
    if new:
        print(f"::error::{LINT_NAME}: {len(new)} new violation(s):")
        for v in new:
            print(v)
        print()
        print(
            "Raw button widgets are frozen pending Phase 4 "
            "(MVP-CTA-UNIFICATION-V1) — MintCTA.{primary,secondary,tertiary,"
            "destructive} lands then. If you need a new button surface this "
            f"phase, contact #design or use `// lint-ignore: {LINT_NAME}`."
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
