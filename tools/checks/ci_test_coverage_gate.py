#!/usr/bin/env python3
"""Aucun répertoire de tests ne peut disparaître de la CI en silence.

CE QUE CE GARDE A TROUVÉ EN NAISSANT

`.github/workflows/ci.yml` n'exécute pas `flutter test`. Il exécute trois
shards sur des répertoires ÉNUMÉRÉS À LA MAIN. Le dépôt en contient 32 ;
quinze n'apparaissaient dans aucun shard, plus dix-huit fichiers de test posés
à la racine de `test/`. **Soixante-dix fichiers de test ne s'exécutaient jamais
en intégration continue.**

Le piège de nommage vaut d'être cité : un shard listait `test/golden/` au
singulier, tandis que les références visuelles vivent dans `test/goldens/` au
pluriel. Deux répertoires distincts, un seul couvert, aucun message.

Ce n'est pas une curiosité. Le même jour, un lot livré contenait neuf échecs de
tests, et ils vivaient précisément dans `test/architecture/`, `test/goldens/` et
`test/integration/` — la CI ne les aurait pas vus davantage que l'agent qui les
a écrits. La barrière serveur portait le même défaut que l'agent : un périmètre
énuméré à la main qui omet sans le dire.

LE PRINCIPE

Une énumération n'est pas fautive en soi — le sharding sert à paralléliser. Ce
qui est fautif, c'est qu'elle puisse être incomplète sans que rien ne le
signale. Ce garde compare donc l'énumération à l'arbre réel des tests et échoue
sur tout répertoire non couvert. Une exclusion reste possible, mais elle devient
EXPLICITE et motivée, jamais un oubli.

Usage :
    python3 tools/checks/ci_test_coverage_gate.py
    python3 tools/checks/ci_test_coverage_gate.py --self-test
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CI = REPO / ".github/workflows/ci.yml"
TESTS = REPO / "apps/mobile/test"

# Exclusions EXPLICITES et motivées. Chacune doit dire pourquoi elle ne peut
# pas tourner sur un agent d'intégration, sinon elle n'a rien à faire ici.
EXCLUDED: dict[str, str] = {
    "patrol": "exige une infrastructure d'émulateur, indisponible sur l'agent",
    "golden_screenshots": (
        "diffs au pixel près, fragiles entre plateformes — les références sont "
        "produites sur macOS et échouent sur un agent Linux"
    ),
    # `_archive` a été retiré : le répertoire n'existe plus. Le garde l'a
    # signalé lui-même — une exclusion sans objet ferait croire à une dette
    # qui n'existe pas.
}


def ci_listed_directories(ci_text: str) -> set[str]:
    listed: set[str] = set()
    for match in re.finditer(r'test_dirs:\s*"([^"]+)"', ci_text):
        for entry in match.group(1).split():
            listed.add(entry.rstrip("/").removeprefix("test/"))
    return listed


def ci_covers_root_tests(ci_text: str) -> bool:
    """Un motif tel que `test/*_test.dart` couvre les fichiers posés à la
    racine de `test/`, qu'aucun répertoire ne peut atteindre."""
    return bool(re.search(r'test_dirs:\s*"[^"]*test/\*[^"]*"', ci_text))


def directories_with_tests(root: Path) -> set[str]:
    found: set[str] = set()
    for path in root.rglob("*_test.dart"):
        parts = path.relative_to(root).parts
        if len(parts) > 1:
            found.add(parts[0])
    return found


def root_level_tests(root: Path) -> list[str]:
    return sorted(p.name for p in root.glob("*_test.dart"))


def main() -> int:
    if not CI.exists():
        print(f"ÉCHEC — {CI.relative_to(REPO)} introuvable.")
        return 1
    if not TESTS.exists():
        print(f"ÉCHEC — {TESTS.relative_to(REPO)} introuvable.")
        return 1

    ci_text = CI.read_text(encoding="utf-8")
    listed = ci_listed_directories(ci_text)
    if not listed:
        print(
            "ÉCHEC — aucun `test_dirs:` trouvé dans ci.yml. Le garde ne sait "
            "plus lire la configuration : c'est un échec, pas un laissez-passer."
        )
        return 1

    actual = directories_with_tests(TESTS)
    uncovered = sorted(d for d in actual if d not in listed and d not in EXCLUDED)
    orphan_exclusions = sorted(d for d in EXCLUDED if d not in actual)
    roots = root_level_tests(TESTS)

    problems = False

    if uncovered:
        problems = True
        print(f"ÉCHEC — {len(uncovered)} répertoire(s) de tests hors CI :")
        for directory in uncovered:
            count = len(list((TESTS / directory).rglob("*_test.dart")))
            print(f"    test/{directory}  ({count} fichier(s)) — jamais exécuté")
        print(
            "\n  Les ajouter à un shard de `ci.yml`, ou les inscrire dans\n"
            "  EXCLUDED avec la raison qui les empêche de tourner."
        )

    if roots and not ci_covers_root_tests(ci_text):
        problems = True
        print(
            f"\nÉCHEC — {len(roots)} fichier(s) de test à la racine de test/ : "
            "aucun shard ne les atteint."
        )
        for name in roots[:8]:
            print(f"    test/{name}")
        if len(roots) > 8:
            print(f"    … et {len(roots) - 8} autre(s)")
        print(
            "\n  Ajouter `test/*_test.dart` à un shard, ou les déplacer dans\n"
            "  un répertoire couvert."
        )

    if orphan_exclusions:
        problems = True
        print(
            f"\nÉCHEC — exclusion(s) sans objet : {', '.join(orphan_exclusions)}.\n"
            "  Le répertoire ne contient plus de test ; retirer l'entrée pour\n"
            "  que la liste dise la vérité."
        )

    if problems:
        return 1

    covered = sorted(actual - set(EXCLUDED))
    total = sum(len(list((TESTS / d).rglob("*_test.dart"))) for d in covered)
    print(
        f"OK ci_test_coverage_gate — {len(covered)} répertoire(s), "
        f"{total} fichier(s) de test couverts ; "
        f"{len(EXCLUDED)} exclusion(s) motivée(s)."
    )
    return 0


def self_test() -> int:
    """Le garde doit voir ce qu'il a été écrit pour voir."""
    failures = 0

    if not ci_covers_root_tests('test_dirs: "test/theme/"'):
        pass
    else:
        print("ÉCHEC self-test : un répertoire simple n'est pas un motif racine")
        failures += 1
    if not ci_covers_root_tests('test_dirs: "test/theme/ test/*_test.dart"'):
        print("ÉCHEC self-test : le motif racine n'est pas reconnu")
        failures += 1

    parsed = ci_listed_directories(
        'test_dirs: "test/services/ test/domain/"\n'
        'test_dirs: "test/widgets/"\n'
    )
    if parsed != {"services", "domain", "widgets"}:
        print(f"ÉCHEC self-test : lecture des shards → {parsed}")
        failures += 1

    # Le piège d'origine : singulier contre pluriel. Deux répertoires
    # distincts, et rien ne le signalait.
    listed = ci_listed_directories('test_dirs: "test/golden/"')
    if "goldens" in listed:
        print("ÉCHEC self-test : `golden` ne doit pas couvrir `goldens`")
        failures += 1

    if not EXCLUDED:
        print("ÉCHEC self-test : une exclusion sans motif n'est pas une exclusion")
        failures += 1
    for name, reason in EXCLUDED.items():
        if len(reason) < 20:
            print(f"ÉCHEC self-test : motif trop court pour {name}")
            failures += 1

    if failures:
        return 1
    print("OK ci_test_coverage_gate --self-test")
    return 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
