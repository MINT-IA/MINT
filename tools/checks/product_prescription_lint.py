#!/usr/bin/env python3
"""Lint des prescriptions de produit — ADR 2026-07-28-prescriptions.

Refuse tout NOUVEL impératif d'achat (« Souscris… », « Ouvrez un compte… »,
« Versez le maximum ») dans les chaînes source des trois stacks (.py, .dart,
.arb). La dette existante est portée par une BASELINE-CLIQUET
(``_baseline_prescription_sites.txt``, patron ``hmac_pepper_audit``) :

- entrée ``chemin::motif::hash(extrait)`` connue : tolérée, en attente de
  réécriture ;
- NOUVELLE entrée (fichier neuf, motif neuf, occurrence supplémentaire ou
  ÉCHANGE d'occurrence — le hash d'extrait change) : exit 1 ;
- entrée devenue introuvable (site réécrit ou déplacé) : exit 1 — la
  baseline doit être mise à jour consciemment dans le même commit ;
- l'anti-croissance de la baseline elle-même est verrouillée en CI
  (comparaison contre origin/dev, bootstrap excepté).

Limite assumée : scan par ligne — une prescription coupée sur deux lignes
(concaténation de chaînes) échappe aux motifs multi-mots.

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
import hashlib
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
    # Le vocabulaire et les gardes runtime CITENT les motifs par design.
    "/app/services/coach/prescription_vocab.py/",
    "/app/services/coach/compliance_guard.py/",
    "/lib/services/coach/compliance_guard.dart/",
    # Fichiers l10n GÉNÉRÉS depuis les .arb (source de vérité : l'ARB ;
    # le généré ne peut pas porter de lint-ignore et double-compterait).
    "/lib/l10n/app_localizations",
)



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


_IGNORE_RE = re.compile(r"(?:#|//)\s*lint-ignore:\s*prescription\s*$")

# Préfixes de commentaire PAR LANGAGE (revue Codex P2) : « # Souscris » dans
# une chaîne multi-ligne .dart n'est pas un commentaire Dart — il reste
# scanné ; « // Open a pillar 3a » dans une chaîne .py idem. Le résidu
# assumé : un marqueur du MÊME langage à l'intérieur d'une chaîne
# multi-ligne de ce langage (limite du scan par ligne, documentée).
_COMMENT_PREFIXES = {".py": ("#",), ".dart": ("//",), ".arb": ()}


def _line_is_exempt(line: str, suffix: str) -> bool:
    # Échappatoire ANCRÉE en commentaire de fin de ligne — un contenu qui
    # porterait la chaîne au milieu d'une valeur .arb n'exempte rien
    # (revue adversariale P2-4).
    if _IGNORE_RE.search(line.rstrip()):
        return True
    prefixes = _COMMENT_PREFIXES.get(suffix, ())
    if not prefixes:
        return False
    return line.lstrip().startswith(prefixes)


def scan_text(
    text: str, motifs, prix, suffix: str = ".dart"
) -> list[tuple[int, str, str]]:
    """(ligne, nom-du-motif, extrait) — motif prix seulement co-occurrent."""
    out: list[tuple[int, str, str]] = []
    for lineno, line in enumerate(text.splitlines(), start=1):
        if _line_is_exempt(line, suffix):
            continue
        nfkc = unicodedata.normalize("NFKC", line)
        hits = [name for name, rx in motifs if rx.search(nfkc)]
        if not hits:
            continue
        # Ligne COMPLÈTE : le hash de baseline doit couvrir toute la ligne
        # (revue adversariale 2026-07-28 P2 : tronquer avant hachage laissait
        # la queue au-delà de 120 caractères hors surveillance). La troncature
        # n'intervient qu'à l'affichage des diagnostics.
        snippet = line.strip()
        for name in hits:
            out.append((lineno, name, snippet))
        if prix.search(nfkc):
            out.append((lineno, "prix-co-occurrent", snippet))
    return out


def derive_entries(found: dict[str, list[tuple[int, str, str]]]) -> set[str]:
    """Entrées de baseline PAR OCCURRENCE : chemin::motif::hash8(ligne
    normalisée complète), suffixe -N pour les doublons verbatim."""
    current: set[str] = set()
    for path, rows in found.items():
        vus: dict[str, int] = {}
        for _, name, snippet in rows:
            norme = " ".join(snippet.lower().split())
            h = hashlib.sha1(norme.encode()).hexdigest()[:8]
            base = f"{path}::{name}::{h}"
            vus[base] = vus.get(base, 0) + 1
            current.add(base if vus[base] == 1 else f"{base}-{vus[base]}")
    return current


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
        rows = scan_text(text, motifs, prix, suffix=path.suffix)
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
        ("# Souscris une assurance", False, "commentaire python exempt", ".py"),
        ("# Souscris une assurance", True, "# dans une chaine .dart : scanne (Codex P2)", ".dart"),
        ("// Open a pillar 3a", True, "// dans une chaine .py : scanne (Codex P2)", ".py"),
        ("Ouvrir compte 3a", True, "infinitif sans article (Codex P1)"),
        ("3a-Konto eröffnen", True, "de : verbe final Konto (Codex P1)"),
        ("Open multiple 3a accounts", True, "en : multiple/pluriel (Codex P1)"),
        ("Abrir una cuenta 3a", True, "es : una (Codex P1)"),
        ("Souscris une RC  // lint-ignore: prescription", False, "échappatoire ancrée"),
        (
            '"k": "Souscris ceci lint-ignore: prescription et cela",',
            True,
            "marqueur au milieu d'une valeur : n'exempte pas (P2-4)",
        ),
        ("  * Souscris une APG des CHF 45/mois", True, "bullet de prompt (P2-1)"),
        ("open a pillar 3a today", True, "en : open pillar"),
        ("Take out death/disability risk insurance", True, "en : take out insurance"),
        ("25 Jahre: Säule 3a eröffnen", True, "de : verbe final"),
        ("Aos 25 anos, abrir um 3º pilar", True, "pt : abrir pilar"),
        ("Ouvre un 3ème pilier des maintenant", True, "variante ème (P2-3)"),
        ("Versez-y le montant maximum", True, "variante -y + montant (P2-3)"),
        (
            "Ouvrez un compte pour recevoir vos alertes",
            False,
            "compte applicatif non financier : plus matché",
        ),
        # Véhicule AVANT le verbe (revue adversariale #1084 P2) : les 6
        # traductions réelles de firstJob3aHeader doivent toutes matcher.
        ("PILIER 3A — À OUVRIR MAINTENANT", True, "fr : véhicule-puis-ouvrir"),
        ("PILLAR 3A — OPEN NOW", True, "en : véhicule-puis-ouvrir"),
        ("SÄULE 3A — JETZT ERÖFFNEN", True, "de : véhicule-puis-ouvrir"),
        ("PILASTRO 3A — DA APRIRE ORA", True, "it : véhicule-puis-ouvrir"),
        ("PILAR 3A — ABRIR AHORA", True, "es : véhicule-puis-ouvrir"),
        ("PILAR 3A — ABRIR AGORA", True, "pt : véhicule-puis-ouvrir"),
    ]
    failures = 0
    for case in cases:
        line, should_flag, why = case[0], case[1], case[2]
        suffix = case[3] if len(case) > 3 else ".dart"
        rows = scan_text(line + "\n", motifs, prix, suffix=suffix)
        flagged = any(name != "prix-co-occurrent" for _, name, _ in rows)
        if flagged != should_flag:
            print(
                f"self-test FAIL [{why}] : attendu {should_flag}, "
                f"obtenu {flagged} — {line!r}",
                file=sys.stderr,
            )
            failures += 1
    # Mécanique des entrées (revue adversariale #1084 P2) : la queue au-delà
    # du 120e caractère compte dans le hash, et un doublon verbatim reçoit
    # un suffixe -2.
    prefixe = "Souscris une assurance vie complète " + "x " * 50
    assert len(prefixe) > 120
    a = derive_entries({"p.dart": [(1, "souscrire-imperatif", prefixe + "AAA")]})
    b = derive_entries({"p.dart": [(1, "souscrire-imperatif", prefixe + "BBB")]})
    if a == b:
        print(
            "self-test FAIL [hash ligne complète] : deux queues différentes "
            "au-delà de 120 caractères donnent la même entrée",
            file=sys.stderr,
        )
        failures += 1
    doublon = derive_entries({"p.dart": [
        (1, "souscrire-imperatif", "Souscris X"),
        (2, "souscrire-imperatif", "Souscris X"),
    ]})
    if len(doublon) != 2 or not any(e.endswith("-2") for e in doublon):
        print(
            "self-test FAIL [doublon verbatim] : suffixe -2 absent",
            file=sys.stderr,
        )
        failures += 1
    if failures:
        return 1
    print(
        f"product_prescription_lint self-test OK "
        f"({len(cases)} cas + mécanique des entrées)"
    )
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
    # Entrées PAR OCCURRENCE (revue Codex 2026-07-28 P1) — retirer une
    # occurrence baselinée et en ajouter une autre du même motif dans le même
    # fichier change le hash : l'échange est visible. Le hash couvre la ligne
    # normalisée COMPLÈTE (revue adversariale P2) : éditer un site baseliné,
    # y compris au-delà du 120e caractère, change son hash -> stale + new ->
    # passage conscient par la baseline.
    current = derive_entries(found)

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
        # Les entrées portent le compte (path::motif::N) — les diagnostics
        # se sélectionnent sur la clé path::motif (revue Codex P2).
        failing_keys = {e.rpartition("::")[0] for e in new_sites}
        for path, rows in sorted(found.items()):
            for lineno, name, snippet in rows:
                if f"{path}::{name}" in failing_keys:
                    print(
                        f"{path}:{lineno}: [{name}] {snippet[:120]}",
                        file=sys.stderr,
                    )
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
