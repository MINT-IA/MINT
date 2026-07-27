#!/usr/bin/env python3
"""Early-ship FR accent lint (CTX-02 metric a ingestion).

Scope: detect ASCII-flattened French words that should carry diacritics.
Scans `.dart`, `.py`, `.arb`, `.md` files by default. Writes offending
`path:line: snippet (pattern)` lines to stderr when violations are found.

Exit codes:
  0 — clean
  1 — violations found (stderr has machine-readable `path:line: snippet` rows)

Phase 34 GUARD-04 will extend the pattern list and wire CI. Phase 30.5
Plan 01 only needs the early-ship version to make `ingest_git.py` run lints
on each Claude commit's diff and populate the `violations` table.

Pattern list sourced from MEMORY.md feedback files + 30.5-CONTEXT.md D-14.
Use --file <path> to lint a single file (pattern used by ingest_git.py).

--added-only : ne juge QUE les lignes ajoutées par le diff indexé. C'est le mode
utilisé par le hook pre-commit. Raison : le dépôt porte une dette héritée
(~263 violations en fichier entier) ; un contrôle sur fichier entier bloquerait
tout commit touchant un fichier déjà en dette, donc il n'a jamais pu être câblé
et la dette a continué de croître. En ne jugeant que ce qui est AJOUTÉ, la
barrière devient posable aujourd'hui : l'existant reste tel quel, le neuf est
arrêté. Patron repris de no_hardcoded_fr.py.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

# Each pattern = (word_regex, suggested_correction). Patterns use \b word
# boundaries and (?i) case-insensitive via re.IGNORECASE at call-site.
PATTERNS: list[tuple[str, str]] = [
    (r"\bcreer\b", "créer"),
    (r"\bdecouvrir\b", "découvrir"),
    (r"\beclairage\b", "éclairage"),
    (r"\bsecurite\b", "sécurité"),
    (r"\bliberer\b", "libérer"),
    (r"\bpreter\b", "prêter"),
    (r"\brealiser\b", "réaliser"),
    (r"\bdeja\b", "déjà"),
    (r"\brecu\b", "reçu"),
    (r"\belaborer\b", "élaborer"),
    (r"\bregler\b", "régler"),
    (r"\bspecialistes?\b", "spécialiste(s)"),
    (r"\bgerer\b", "gérer"),
    (r"\bprogres\b", "progrès"),
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
    # Test code is developer-facing, not user-facing. Excluded to avoid false
    # positives on: (a) HTTP URL paths that MUST stay ASCII for REST compatibility,
    # (b) intentional fixtures (test harnesses that feed the lint its own
    # expected inputs), and (c) backend category / enum keys kept ASCII for
    # DB and JSON serialization stability. User-facing accent correctness is
    # enforced on lib/ + app/services/* sources.
    "/tests/",
    "/test/",
    # Lint scripts themselves contain ASCII-flattened patterns by design
    # (anti-patterns to detect). Skip self-scanning to avoid meta-loops.
    "/tools/checks/",
)


def scan_text(text: str) -> list[tuple[int, str, str]]:
    """Scan a raw text buffer for ASCII-flattened French accent patterns.

    Returns list of (lineno, snippet, pattern->correction) violations. 1-indexed lines.
    Backward-compatible with scan_file — shares the PATTERNS list.
    Added in Phase 30.7 TOOL-04 MCP wrapper. Do NOT duplicate PATTERNS here.
    """
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        for pat, correct in PATTERNS:
            if re.search(pat, line, re.IGNORECASE):
                snippet = line.strip()[:140]
                out.append((lineno, snippet, f"{pat} -> {correct}"))
    return out


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    """Return list of (lineno, snippet, pattern->correction) violations."""
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return scan_text(text)


def _collect_paths(scope: list[str]) -> list[Path]:
    paths: list[Path] = []
    for s in scope:
        root = Path(s)
        if not root.exists():
            continue
        for p in root.rglob("*"):
            if not p.is_file():
                continue
            if p.suffix not in TEXT_EXTS:
                continue
            rel = "/" + p.as_posix() + "/"
            if any(ex in rel for ex in EXCLUDE_SUBSTRINGS):
                continue
            paths.append(p)
    return paths


def _staged_added_lines(scope: list[str]) -> dict[str, set[int]]:
    """Lignes AJOUTÉES par le diff indexé, indexées par chemin de fichier."""
    proc = subprocess.run(
        ["git", "diff", "--cached", "-U0", "--", *scope],
        capture_output=True, text=True,
    )
    added: dict[str, set[int]] = defaultdict(set)
    current: str | None = None
    for line in proc.stdout.splitlines():
        if line.startswith("+++ b/"):
            current = line[6:]
        elif line.startswith("@@") and current:
            m = re.search(r"\+(\d+)(?:,(\d+))?", line)
            if m:
                start = int(m.group(1))
                for i in range(start, start + int(m.group(2) or 1)):
                    added[current].add(i)
    return added


def _self_test() -> int:
    """Prouve que le lint détecte encore, et qu'il épargne encore le correct.

    Sans cela, un lint peut cesser de détecter sans que personne s'en aperçoive :
    il continue de sortir 0 et passe pour vert.
    """
    import tempfile
    cases = [
        ("le bouton permet de creer un compte", True, "creer sans accent"),
        ("le bouton permet de créer un compte", False, "créer accentué"),
        ("Premier eclairage sur ta situation", True, "eclairage sans accent"),
        ("Premier éclairage sur ta situation", False, "éclairage accentué"),
        ("Deja vu dans le parcours", True, "deja sans accent, casse mixte"),
        ("consulte un specialiste agréé", True, "specialiste sans accent"),
        ("la recuperation du mot de passe", False, "recuperation : pas dans la liste, \\b protège recu"),
        ("plain ascii sentence with no french", False, "phrase neutre"),
    ]
    failures = 0
    with tempfile.TemporaryDirectory() as d:
        for line, should_flag, why in cases:
            p = Path(d) / "probe.md"
            p.write_text(line + "\n", encoding="utf-8")
            flagged = bool(scan_file(p))
            if flagged != should_flag:
                print(f"accent_lint_fr self-test FAIL [{why}] : "
                      f"attendu flag={should_flag}, obtenu {flagged} — {line!r}",
                      file=sys.stderr)
                failures += 1
    if failures:
        return 1
    print(f"accent_lint_fr self-test OK ({len(cases)} cas)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description="Early-ship FR accent lint — scans for ASCII-flattened French words"
    )
    ap.add_argument("--file", help="Lint a single file (absolute or relative path)")
    ap.add_argument(
        "--self-test",
        action="store_true",
        help="Vérifie que le lint détecte encore ce qu'il doit détecter",
    )
    ap.add_argument(
        "--added-only",
        action="store_true",
        help="Ne juger que les lignes ajoutées par le diff indexé (mode hook)",
    )
    ap.add_argument(
        "--scope",
        nargs="*",
        default=["apps/mobile/lib", "services/backend/app", "tools"],
        help="Directories to scan (default: lib/app/tools)",
    )
    args = ap.parse_args()

    if args.self_test:
        return _self_test()

    if args.added_only:
        added = _staged_added_lines(args.scope)
        paths = [Path(f) for f in added
                 if Path(f).suffix in TEXT_EXTS and Path(f).exists()
                 and not any(ex in "/" + f + "/" for ex in EXCLUDE_SUBSTRINGS)]
        found = 0
        for path in paths:
            allowed = added.get(path.as_posix(), set())
            for lineno, snippet, pat in scan_file(path):
                if lineno not in allowed:
                    continue
                print(f"{path}:{lineno}: {snippet} ({pat})", file=sys.stderr)
                found += 1
        if found:
            print(
                f"accent_lint_fr: FAIL — {found} nouveau(x) mot(s) français "
                "aplati(s) en ASCII. Les accents sont obligatoires "
                "(CLAUDE.md TOP rule #2) : `creer -> créer`, "
                "`eclairage -> éclairage`.",
                file=sys.stderr,
            )
            return 1
        return 0

    if args.file:
        target = Path(args.file)
        if not target.exists():
            print(f"accent_lint_fr: file not found: {target}", file=sys.stderr)
            return 1
        # Respect EXCLUDE_SUBSTRINGS for per-file mode too so lefthook
        # staged-file invocations don't re-introduce the false positives
        # that --all-files mode already filters out (tests, build artefacts).
        rel = "/" + target.as_posix() + "/"
        if any(ex in rel for ex in EXCLUDE_SUBSTRINGS):
            return 0
        paths = [target]
    else:
        paths = _collect_paths(args.scope)

    found = 0
    for path in paths:
        for lineno, snippet, pat in scan_file(path):
            print(f"{path}:{lineno}: {snippet} ({pat})", file=sys.stderr)
            found += 1

    if found:
        print(f"accent_lint_fr: FAIL — {found} violation(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
