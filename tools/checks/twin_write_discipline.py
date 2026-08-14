#!/usr/bin/env python3
"""La règle du jumeau, rendue mécanique.

LA RÈGLE, énoncée par Julien le 2026-08-13 :

    « Aucun écran n'est terminé si les informations qu'il collecte ne
      rejoignent pas le jumeau financier, et si ses résultats ne peuvent pas
      être retrouvés et réutilisés ailleurs. »

Tant qu'elle n'est qu'écrite, elle sera oubliée. Ce n'est pas une supposition :
une consigne procédurale sans contrôle mécanique est mesurée nette-négative
ailleurs dans ce dépôt.

CE QUE CE GARDE CONTRÔLE

Le jumeau tient l'autorité ; le magasin plat clé-valeur n'est plus que sa
projection. Écrire directement dans la projection, c'est court-circuiter le
registre : la valeur apparaît à l'écran sans version, sans provenance, sans
historique — et un jour sans que personne comprenne d'où elle vient.

Le garde refuse donc toute NOUVELLE écriture directe. Les 28 sites existants
sont nommés dans la base ci-dessous : ils datent d'avant le jumeau et seront
repris un par un. C'est un CLIQUET, pas une amnistie — la base ne peut que
décroître.

Usage :
    python3 tools/checks/twin_write_discipline.py
    python3 tools/checks/twin_write_discipline.py --self-test
    python3 tools/checks/twin_write_discipline.py --update-baseline
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
LIB = REPO / "apps/mobile/lib"
BASELINE = REPO / "tools/checks/_baseline_twin_direct_writes.txt"

# Les écritures qui court-circuitent le registre.
WRITE_PATTERNS = (
    re.compile(r"ReportPersistenceService\.saveAnswers\b"),
    # `writeCanonicalHousing` et `writeCanonicalHousingDeleted` sont EXCLUS :
    # ils ne contournent plus le registre, ils SONT la frontière de commande du
    # logement. Un écran qui les appelle fait entrer le fait au jumeau — c'est
    # exactement ce que cette discipline réclame.
    #
    # Les autres faits n'ont pas encore de frontière : leurs writers restent
    # des contournements et restent surveillés. La liste rétrécira quand ils
    # en auront une, jamais avant.
    # Les CINQ faits ont desormais une frontiere de commande : ces appels
    # font entrer le fait au jumeau, ils ne le contournent plus. Ne reste
    # surveille que l'ecriture directe dans la projection plate.
    re.compile(r"SecureWizardStore\.writeCanonical(?!Housing|CivilStatus|Revenu|LppAffiliation|Versements3a)\w+"),
)

# Le jumeau lui-même écrit forcément dans la projection : c'est son travail.
EXEMPT_PREFIXES = ("services/twin/",)

# Échappatoire par ligne, pour un cas légitime et argumenté.
ESCAPE = "twin-write-ok"


def scan() -> list[str]:
    """Les sites d'écriture directe, sous la forme `chemin:ligne`."""
    sites: list[str] = []
    for path in sorted(LIB.rglob("*.dart")):
        relative = path.relative_to(LIB).as_posix()
        if any(relative.startswith(prefix) for prefix in EXEMPT_PREFIXES):
            continue
        for number, line in enumerate(
            path.read_text(encoding="utf-8").splitlines(), start=1
        ):
            if ESCAPE in line:
                continue
            if any(pattern.search(line) for pattern in WRITE_PATTERNS):
                sites.append(f"{relative}:{number}")
    return sites


def load_baseline() -> set[str]:
    if not BASELINE.exists():
        return set()
    return {
        line.strip()
        for line in BASELINE.read_text(encoding="utf-8").splitlines()
        if line.strip() and not line.startswith("#")
    }


def write_baseline(sites: list[str]) -> None:
    header = (
        "# Écritures directes dans la projection, héritées d'avant le jumeau.\n"
        "#\n"
        "# Chacune court-circuite le registre : la valeur apparaît à l'écran\n"
        "# sans version, sans provenance et sans historique. Elles seront\n"
        "# reprises une par une ; d'ici là elles sont tolérées et NOMMÉES.\n"
        "#\n"
        "# CLIQUET : cette liste ne peut que décroître. Un nouveau site est\n"
        "# refusé ; un site repris doit quitter la liste dans le même lot.\n"
        "#\n"
        "# Régénérer après une reprise :\n"
        "#   python3 tools/checks/twin_write_discipline.py --update-baseline\n"
        "\n"
    )
    BASELINE.write_text(header + "\n".join(sites) + "\n", encoding="utf-8")


def main() -> int:
    if not LIB.exists():
        print(f"ÉCHEC — {LIB.relative_to(REPO)} introuvable.")
        return 1

    sites = scan()

    if "--update-baseline" in sys.argv:
        write_baseline(sites)
        print(f"base régénérée — {len(sites)} site(s) hérité(s).")
        return 0

    baseline = load_baseline()
    if not baseline:
        print(
            "ÉCHEC — base absente. Le garde ne sait pas ce qui est hérité,\n"
            "  et sans elle il ne peut pas distinguer l'ancien du neuf.\n"
            "  Créer :  python3 tools/checks/twin_write_discipline.py "
            "--update-baseline"
        )
        return 1

    current = set(sites)
    added = sorted(current - baseline)
    removed = sorted(baseline - current)

    if added:
        print(f"ÉCHEC — {len(added)} écriture(s) directe(s) NOUVELLE(s) :")
        for site in added:
            print(f"    {site}")
        print(
            "\n  Le magasin plat n'est plus l'autorité : c'est la projection du\n"
            "  jumeau. Une valeur écrite directement apparaît à l'écran sans\n"
            "  version, sans provenance et sans historique.\n"
            "\n"
            "  Passer par le jumeau (`TwinStore.append`), ou — si l'écriture\n"
            "  est légitime et argumentée — marquer la ligne `twin-write-ok`."
        )
        return 1

    if removed:
        # Décroissance : à saluer, mais la base doit suivre, sinon elle finit
        # par décrire un monde qui n'existe plus.
        print(f"ÉCHEC — {len(removed)} site(s) de la base ont disparu :")
        for site in removed:
            print(f"    {site}")
        print(
            "\n  Bonne nouvelle, mais la base doit le refléter — sinon elle\n"
            "  décrit un monde qui n'existe plus.\n"
            "  Régénérer :  python3 tools/checks/twin_write_discipline.py "
            "--update-baseline"
        )
        return 1

    print(
        f"OK twin_write_discipline — {len(current)} écriture(s) héritée(s), "
        "aucune nouvelle."
    )
    return 0


def self_test() -> int:
    """Le garde doit voir ce qu'il a été écrit pour voir."""
    failures = 0

    for source, should_match in (
        ("await ReportPersistenceService.saveAnswers(next);", True),
        # Le logement a une FRONTIÈRE DE COMMANDE : ces appels font entrer le
        # fait au jumeau, ils ne le contournent pas. Cet auto-test affirmait
        # l'inverse — il gardait une vérité périmée.
        ("await SecureWizardStore.writeCanonicalHousing(fact);", False),
        ("await SecureWizardStore.writeCanonicalHousingDeleted();", False),
        # Les autres n'en ont pas encore : ils restent des contournements.
        ("await SecureWizardStore.writeCanonicalCivilStatusDeleted();", False),
        ("await SecureWizardStore.writeCanonicalRevenu(fact);", False),
        # Les versements 3a n'ont PAS de frontiere : leur valeur est une liste
        # qui se decompose, pas un fait qui s'enveloppe.
        ("await SecureWizardStore.writeCanonicalVersements3a(fact);", False),
        # Il faut au moins UN positif pour le motif restant.
        ("await SecureWizardStore.writeCanonicalDomicile(fact);", True),
        ("final answers = await ReportPersistenceService.loadAnswers();", False),
        ("// ReportPersistenceService.saveAnswers dans un commentaire", True),
    ):
        matched = any(p.search(source) for p in WRITE_PATTERNS)
        if matched != should_match:
            print(f"ÉCHEC self-test : « {source} » → {matched}")
            failures += 1

    if not WRITE_PATTERNS:
        print("ÉCHEC self-test : aucun motif d'écriture déclaré")
        failures += 1
    if not EXEMPT_PREFIXES:
        print("ÉCHEC self-test : le jumeau lui-même doit être exempté")
        failures += 1

    if failures:
        return 1
    print("OK twin_write_discipline --self-test")
    return 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
