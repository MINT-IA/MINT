#!/usr/bin/env python3
"""Lint des prescriptions de produit — ADR 2026-07-28-prescriptions.

Refuse tout NOUVEL impératif d'achat (« Souscris… », « Ouvrez un compte… »,
« Versez le maximum ») dans les chaînes source des trois stacks (.py, .dart,
.arb). La dette existante est portée par une BASELINE-CLIQUET
(``_baseline_prescription_sites.txt``, patron ``hmac_pepper_audit``) :

- site connu (dans la baseline) : toléré, en attente de réécriture ;
- site NOUVEAU hors baseline : exit 1 ;
- entrée de baseline devenue introuvable : exit 1 — la liste ne peut que
  rétrécir, dans le même commit que la réécriture.

Le vocabulaire canonique vit côté backend
(``app/services/coach/prescription_vocab.py``) et ce lint le CHARGE — jamais
l'inverse (le build Docker n'embarque pas ``tools/``).

Échappatoire explicite et grep-able : ``lint-ignore: prescription`` sur la
ligne (commentaire Python ``#`` ou Dart ``//``). Les fichiers ``.arb`` n'ont
pas de commentaires : entrée de baseline.

Exit codes :
    0 — aucun site hors baseline, aucune entrée de baseline périmée
    1 — nouveau site OU entrée périmée
    2 — usage / vocabulaire introuvable

Usage :
    python3 tools/checks/product_prescription_lint.py [--self-test]
"""
from __future__ import annotations

import argparse
import importlib.util
import re
import sys
import unicodedata
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
VOCAB_PATH = (
    ROOT / "services/backend/app/services/coach/prescription_vocab.py"
)
BASELINE_PATH = Path(__file__).resolve().parent / (
    "_baseline_prescription_sites.txt"
)

SCAN_ROOTS = ("apps/mobile/lib", "services/backend/app")
TEXT_EXTS = {".py", ".dart", ".arb"}
EXCLUDE_SUBSTRINGS = (
    "/.git/",
    "/node_modules/",
    "/.dart_tool/",
    "/build/",
    "/__pycache__/",
    "/tests/",
    "/test/",
    # Le vocabulaire lui-même et les gardes portent les motifs par design.
    "/tools/checks/",
    "/app/services/coach/prescription_vocab.py/",
    # Fichiers l10n GÉNÉRÉS depuis les .arb (source de vérité : l'ARB ;
    # le généré ne peut pas porter de lint-ignore et double-compterait).
    "/lib/l10n/app_localizations",
)

IGNORE_MARKER = "lint-ignore: prescription"


def _load_vocab():
    if not VOCAB_PATH.exists():
        print(
            f"product_prescription_lint: vocabulaire introuvable: {VOCAB_PATH}",
            file=sys.stderr,
        )
        raise SystemExit(2)
    spec = importlib.util.spec_from_file_location(
        "prescription_vocab", VOCAB_PATH
    )
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def _compile(vocab):
    motifs = [
        (name, re.compile(pattern, re.IGNORECASE))
        for name, pattern in vocab.PRESCRIPTION_MOTIFS
    ]
    prix = re.compile(vocab.PRIX_MENSUEL_RE, re.IGNORECASE)
    return motifs, prix


def _line_is_exempt(line: str) -> bool:
    if IGNORE_MARKER in line:
        return True
    stripped = line.lstrip()
    # Un commentaire n'est jamais rendu à l'utilisateur.
    return stripped.startswith(("#", "//", "///", "*", "/*", '"""', "'''"))


def scan_text(text: str, motifs, prix) -> list[tuple[int, str, str]]:
    """(ligne, nom-du-motif, extrait) — motif prix seulement co-occurrent."""
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        if _line_is_exempt(line):
            continue
        nfkc = unicodedata.normalize("NFKC", line)
        hits = [name for name, rx in motifs if rx.search(nfkc)]
        if not hits:
            continue
        snippet = line.strip()[:120]
        for name in hits:
            out.append((lineno, name, snippet))
        if prix.search(nfkc):
            out.append((lineno, "prix-co-occurrent", snippet))
    return out


def _collect_paths() -> list[Path]:
    paths: list[Path] = []
    for root in SCAN_ROOTS:
        base = ROOT / root
        if not base.exists():
            continue
        for p in sorted(base.rglob("*")):
            if not p.is_file() or p.suffix not in TEXT_EXTS:
                continue
            rel = "/" + p.relative_to(ROOT).as_posix() + "/"
            if any(ex in rel for ex in EXCLUDE_SUBSTRINGS):
                continue
            paths.append(p)
    return paths


def _read_baseline() -> set[str]:
    if not BASELINE_PATH.exists():
        return set()
    entries: set[str] = set()
    for raw in BASELINE_PATH.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        entries.add(line.split()[0])
    return entries


def _scan_repo(motifs, prix) -> dict[str, list[tuple[int, str, str]]]:
    found: dict[str, list[tuple[int, str, str]]] = {}
    for path in _collect_paths():
        try:
            text = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue
        rows = scan_text(text, motifs, prix)
        if rows:
            found[path.relative_to(ROOT).as_posix()] = rows
    return found


def _self_test(motifs, prix) -> int:
    cases = [
        ("Souscris une APG privée (dès CHF 45/mois)", True, "impératif + prix"),
        ("Souscrire une RC privee (~CHF 5/mois)", True, "infinitif checklist + prix"),
        ("Souscrivez une assurance IJM individuelle", True, "vouvoiement"),
        ("Ouvrez un compte 3a aupres d'une banque", True, "ouvrir véhicule"),
        ("Ouvre un 3e pilier des maintenant", True, "ouvrir pilier tutoiement"),
        ("Verse le maximum chaque annee", True, "verser le maximum"),
        ("la souscription d'une assurance est un contrat", False, "nom commun"),
        ("avant de souscrire, compare les offres", True, "assumé : famille énumérée"),
        ("une APG coûte typiquement dès CHF 45/mois", False, "prix seul = info"),
        ("ouvre une porte sur tes finances", False, "hors véhicule financier"),
        ("Souscriｓ une assurance", True, "evasion NFKC (s pleine chasse)"),
        ("# Souscris une assurance — commentaire", False, "commentaire exempt"),
        ("Souscris une RC  // lint-ignore: prescription", False, "échappatoire"),
    ]
    failures = 0
    for line, should_flag, why in cases:
        rows = scan_text(line + "\n", motifs, prix)
        flagged = any(name != "prix-co-occurrent" for _, name, _ in rows)
        if flagged != should_flag:
            print(
                f"self-test FAIL [{why}] : attendu {should_flag}, "
                f"obtenu {flagged} — {line!r}",
                file=sys.stderr,
            )
            failures += 1
    if failures:
        return 1
    print(f"product_prescription_lint self-test OK ({len(cases)} cas)")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument(
        "--emit-baseline",
        action="store_true",
        help="Imprime les entrées baseline du scan courant (bootstrap/répare)",
    )
    args = ap.parse_args()

    vocab = _load_vocab()
    motifs, prix = _compile(vocab)

    if args.self_test:
        return _self_test(motifs, prix)

    found = _scan_repo(motifs, prix)
    current = {
        f"{path}::{name}"
        for path, rows in found.items()
        for _, name, _ in rows
    }

    if args.emit_baseline:
        for entry in sorted(current):
            print(entry)
        return 0

    baseline = _read_baseline()
    new_sites = current - baseline
    stale = baseline - current

    status = 0
    if new_sites:
        status = 1
        for path, rows in sorted(found.items()):
            for lineno, name, snippet in rows:
                if f"{path}::{name}" in new_sites:
                    print(f"{path}:{lineno}: [{name}] {snippet}", file=sys.stderr)
        print(
            f"product_prescription_lint: FAIL — {len(new_sites)} nouveau(x) "
            "site(s) de prescription hors baseline. Réécris en description "
            "conditionnelle sourcée (ADR 2026-07-28-prescriptions) ou marque "
            "la ligne `lint-ignore: prescription` si elle n'est pas rendue.",
            file=sys.stderr,
        )
    if stale:
        status = 1
        for entry in sorted(stale):
            print(f"baseline périmée: {entry}", file=sys.stderr)
        print(
            "product_prescription_lint: FAIL — retire ces entrées de "
            f"{BASELINE_PATH.name} dans le même commit (cliquet).",
            file=sys.stderr,
        )
    return status


if __name__ == "__main__":
    sys.exit(main())
