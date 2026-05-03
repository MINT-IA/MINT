#!/usr/bin/env python3
"""Safe auto-fix companion to accent_lint_fr.py.

Applies the 14 patterns from PATTERNS, but SKIPS matches that look like
slug components (preceded or followed by `/`, `-`, `_`) so route paths
like `/onboarding/premier-eclairage` or identifiers like
`var_eclairage_count` are not corrupted.

Usage:
    python3 tools/checks/accent_lint_fr_autofix.py            # dry-run, shows diffs
    python3 tools/checks/accent_lint_fr_autofix.py --apply    # writes files in place

Exit code: 0 always.
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

# Mirrors accent_lint_fr.py PATTERNS, with replacement string per pattern.
# Each pattern is case-insensitive at substitution time (preserves the
# matched word's first-letter case).
PATTERNS: list[tuple[str, str]] = [
    (r"creer", "créer"),
    (r"decouvrir", "découvrir"),
    (r"eclairage", "éclairage"),
    (r"securite", "sécurité"),
    (r"liberer", "libérer"),
    (r"preter", "prêter"),
    (r"realiser", "réaliser"),
    (r"deja", "déjà"),
    (r"recu", "reçu"),
    (r"elaborer", "élaborer"),
    (r"regler", "régler"),
    (r"specialiste", "spécialiste"),  # matches both specialiste + specialistes
    (r"gerer", "gérer"),
    (r"progres", "progrès"),
]

TEXT_EXTS = {".dart", ".py", ".arb", ".md"}
EXCLUDE_SUBSTRINGS = (
    "/.git/",
    "/node_modules/",
    "/.dart_tool/",
    "/build/",
    "/__pycache__/",
    "/docs/archive/",
    "/.planning/archives/",
    "/tests/",
    "/test/",
    "/tools/checks/",
)


def _preserve_case(matched: str, replacement: str) -> str:
    """Preserve the first-letter case of the matched word in the replacement."""
    if matched and matched[0].isupper():
        return replacement[0].upper() + replacement[1:]
    return replacement


def _safe_sub_factory(pattern: str, replacement: str):
    """Build a `re.sub` callable that:
    - skips matches inside slug-like contexts (preceded/followed by `/`, `-`, `_`)
    - preserves first-letter case
    """
    SLUG_BEFORE = ("/", "-", "_")
    SLUG_AFTER = ("-", "_")

    def sub(match: re.Match[str]) -> str:
        word = match.group(0)
        full = match.string
        s, e = match.span()
        before = full[s - 1 : s] if s > 0 else ""
        after = full[e : e + 1] if e < len(full) else ""
        if before in SLUG_BEFORE or after in SLUG_AFTER:
            return word
        return _preserve_case(word, replacement)

    return sub


def fix_text(text: str) -> tuple[str, int]:
    """Apply all patterns. Returns (new_text, num_substitutions)."""
    out = text
    total = 0
    for pat_str, repl in PATTERNS:
        compiled = re.compile(rf"\b{pat_str}\b", re.IGNORECASE)
        sub_fn = _safe_sub_factory(pat_str, repl)
        new_out, n = compiled.subn(sub_fn, out)
        if n:
            out = new_out
            total += n
    return out, total


def _included_path(path: Path) -> bool:
    if path.suffix not in TEXT_EXTS:
        return False
    p = str(path).replace("\\", "/")
    return not any(s in p for s in EXCLUDE_SUBSTRINGS)


def walk(root: Path):
    for p in root.rglob("*"):
        if not p.is_file():
            continue
        if not _included_path(p):
            continue
        yield p


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--apply", action="store_true", help="Write files in place")
    parser.add_argument(
        "--root",
        default=str(Path(__file__).resolve().parents[2]),
        help="Repo root (default: 2 dirs up)",
    )
    args = parser.parse_args(argv)
    root = Path(args.root)

    total_files = 0
    total_subs = 0
    for path in walk(root):
        # Skip Flutter-generated localization files — they're regenerated
        # by `flutter gen-l10n` from ARB sources, so any manual edit
        # would be overwritten on next pub get / build.
        rel_str = str(path).replace("\\", "/")
        if "/lib/l10n/app_localizations" in rel_str:
            continue
        # Skip non-FR ARB files — applying FR accent patterns to German
        # ('Regler' = slider) or other locales corrupts the translation.
        if rel_str.endswith(".arb") and not rel_str.endswith("/app_fr.arb") \
                and not rel_str.endswith("app_localizations_fr.dart"):
            continue
        try:
            original_bytes = path.read_bytes()
            original = original_bytes.decode("utf-8")
        except (UnicodeDecodeError, OSError):
            continue
        new_text, n = fix_text(original)
        if n == 0:
            continue
        total_files += 1
        total_subs += n
        rel = path.relative_to(root)
        if args.apply:
            # Preserve original line endings (CRLF / LF) by encoding
            # back to bytes without normalisation.
            path.write_bytes(new_text.encode("utf-8"))
            print(f"FIX {rel}: {n} substitution(s) applied")
        else:
            print(f"DRY-RUN {rel}: {n} substitution(s) would be applied")

    mode = "APPLIED" if args.apply else "DRY-RUN"
    print(f"\n{mode}: {total_subs} substitution(s) across {total_files} file(s)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
