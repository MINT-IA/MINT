#!/usr/bin/env python3
"""Early-ship hardcoded-FR lint (CTX-02 metric a ingestion).

Scans `.dart` widgets under `apps/mobile/lib/` (EXCLUDING `lib/l10n/`) for
French strings embedded inline instead of routed through AppLocalizations.
Heuristic : lines with a quoted literal containing accented FR chars OR
common FR function words, that do NOT reference `AppLocalizations`, `tr(`,
`l10n`, or `// lint-ignore`.

Exit codes:
  0 — clean
  1 — violations found (stderr has `path:line: snippet` rows)

Use --file <path> to lint a single file (pattern used by ingest_git.py).

--added-only : ne juge QUE les lignes ajoutées par le diff indexé. C'est le mode
utilisé par le hook pre-commit. Raison : le dépôt porte une dette héritée de
plusieurs milliers de littéraux ; un contrôle sur fichier entier bloquerait tout
commit touchant un fichier déjà en dette, donc il n'a jamais pu être câblé et la
dette a continué de croître. En ne jugeant que ce qui est AJOUTÉ, la barrière
devient posable aujourd'hui : l'existant reste tel quel, le neuf est arrêté.
"""
from __future__ import annotations

import argparse
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

# Quoted FR-ish literals. We match either (a) accented chars inside the quotes
# or (b) at least two common French function words touching each other.
ACCENT_CHARS = r"àâçéèêëîïôùûüÀÂÇÉÈÊËÎÏÔÙÛÜ"
_QUOTED_ACCENT = re.compile(rf"['\"]([^'\"]*[{ACCENT_CHARS}][^'\"]*)['\"]")
_QUOTED_FR_WORDS = re.compile(
    r"""['"]([^'"]*?\b(?:le|la|les|de|des|du|et|pour|avec|sur|dans|une|un|mon|ma|mes|ton|ta|tes|son|sa|ses|mais|donc|ou|car)\s+\w+[^'"]*?)['"]""",
    re.IGNORECASE,
)

IGNORE_MARKERS = (
    "AppLocalizations",
    "l10n",
    "tr(",
    "// lint-ignore",
    "// ignore:",
    "debugPrint(",
    "print(",  # dev logs — noise; real CI gate in Phase 34
    "assert(",
)

TEXT_EXTS = {".dart"}
DEFAULT_SCOPE = ["apps/mobile/lib"]
EXCLUDE_SUBSTRINGS = (
    "/lib/l10n/",
    "/.dart_tool/",
    "/build/",
    "/.git/",
    "/test/",  # tests often need literal strings
    # Fichiers *.g.dart auto-générés (ex. snapshot du registre réglementaire
    # généré par tools/codegen/regulatory_constants_to_dart.py) : ce sont des
    # données dérivées de la source de vérité backend, pas des libellés écrits
    # à la main rendus à l'utilisateur. Le blob JSON minifié ré-« ajoute » à
    # chaque regen toutes les descriptions FR du registre -> faux positifs.
    "/generated/",
)


def _line_is_exempt(line: str) -> bool:
    stripped = line.lstrip()
    # Un commentaire n'est jamais rendu à l'utilisateur : le signaler produisait
    # 352 faux positifs sur 5274, ce qui rendait la sortie illisible.
    if stripped.startswith(("///", "//", "*", "/*")):
        return True
    return any(marker in line for marker in IGNORE_MARKERS)


def _staged_added_lines() -> dict[str, set[int]]:
    """Lignes AJOUTÉES par le diff indexé, indexées par chemin de fichier."""
    proc = subprocess.run(
        ["git", "diff", "--cached", "-U0", "--", "apps/mobile/lib"],
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


def scan_file(path: Path) -> list[tuple[int, str, str]]:
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        return []
    return scan_text(text)


def scan_text(text: str) -> list[tuple[int, str, str]]:
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        if _line_is_exempt(line):
            continue
        m1 = _QUOTED_ACCENT.search(line)
        if m1:
            out.append((lineno, line.strip()[:140], f"hardcoded-fr-accent: {m1.group(1)[:60]}"))
            continue
        m2 = _QUOTED_FR_WORDS.search(line)
        if m2:
            out.append((lineno, line.strip()[:140], f"hardcoded-fr-words: {m2.group(1)[:60]}"))
    return out


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


def _self_test() -> int:
    """Prouve que le lint détecte encore, et qu'il ignore encore les commentaires.

    Sans cela, un lint peut cesser de détecter sans que personne s'en aperçoive :
    il continue de sortir 0 et passe pour vert.
    """
    import tempfile
    cases = [
        ("    return const Text('Ton épargne de prévoyance');", True, "code accentué"),
        ("    title: 'le montant du rachat',", True, "code, mots FR"),
        ("/// Sonde de prévoyance — commentaire.", False, "commentaire doc"),
        ("// une ligne de commentaire", False, "commentaire ligne"),
        ("    Text(AppLocalizations.of(context)!.greeting),", False, "passe par l10n"),
        ("    final x = 'plain ascii value';", False, "chaîne non FR"),
    ]
    failures = 0
    with tempfile.TemporaryDirectory() as d:
        for line, should_flag, why in cases:
            p = Path(d) / "probe.dart"
            p.write_text(line + "\n", encoding="utf-8")
            flagged = bool(scan_file(p))
            if flagged != should_flag:
                print(f"no_hardcoded_fr self-test FAIL [{why}] : "
                      f"attendu flag={should_flag}, obtenu {flagged} — {line!r}",
                      file=sys.stderr)
                failures += 1
    if failures:
        return 1
    print(f"no_hardcoded_fr self-test OK ({len(cases)} cas)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(
        description=(
            "Early-ship hardcoded-FR lint for .dart widgets. "
            "Excludes lib/l10n/ and test/. "
            "Full version lands in Phase 34 GUARD-04."
        )
    )
    ap.add_argument("--file", help="Lint a single file")
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
        default=DEFAULT_SCOPE,
        help="Directories to scan (default: apps/mobile/lib)",
    )
    args = ap.parse_args()

    if args.self_test:
        return _self_test()

    if args.added_only:
        added = _staged_added_lines()
        paths = [Path(f) for f in added
                 if f.endswith(".dart")
                 and not any(ex in "/" + f + "/" for ex in EXCLUDE_SUBSTRINGS)]
        found = 0
        for path in paths:
            # Juger le BLOB INDEXÉ, pas le worktree : c'est l'index qui sera
            # commité. Lire le worktree laissait passer un littéral indexé
            # dont seule la copie de travail avait été corrigée — trou relevé
            # par revue Codex sur le portage accent_lint_fr (2026-07-27).
            blob = subprocess.run(
                ["git", "show", f":{path.as_posix()}"],
                capture_output=True, text=True,
            )
            if blob.returncode != 0:
                continue
            allowed = added.get(path.as_posix(), set())
            for lineno, snippet, kind in scan_text(blob.stdout):
                if lineno not in allowed:
                    continue
                print(f"{path}:{lineno}: {snippet} ({kind})", file=sys.stderr)
                found += 1
        if found:
            print(
                f"no_hardcoded_fr: FAIL — {found} nouveau(x) littéral(aux) FR "
                "en dur. Passe par AppLocalizations (clé ARB dans les 6 langues) "
                "ou marque la ligne `// lint-ignore` si elle n'est pas rendue.",
                file=sys.stderr,
            )
            return 1
        return 0

    if args.file:
        target = Path(args.file)
        if not target.exists():
            print(f"no_hardcoded_fr: file not found: {target}", file=sys.stderr)
            return 1
        paths = [target]
    else:
        paths = _collect_paths(args.scope)

    found = 0
    for path in paths:
        for lineno, snippet, kind in scan_file(path):
            print(f"{path}:{lineno}: {snippet} ({kind})", file=sys.stderr)
            found += 1

    if found:
        print(f"no_hardcoded_fr: FAIL — {found} hardcoded FR literal(s)", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
