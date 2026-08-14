#!/usr/bin/env python3
"""Tout fait que le jumeau possède doit avoir un chemin de DÉRIVATION.

CE QUE CE GARDE A ÉTÉ ÉCRIT POUR EMPÊCHER

Le registre du jumeau écrivait sa projection dans le magasin plat. En
retirant cette écriture — parce que les canonicalisations dérivent désormais
la valeur à chaque chargement — un fait s'est révélé orphelin : le domicile
n'avait AUCUNE canonicalisation. Sa valeur n'atteignait les écrans que par
l'écriture qu'on venait de supprimer.

Le défaut ne se voyait pas : le fait entrait au registre, l'écriture réussissait,
les tests du registre passaient — et l'écran restait vide. Un fait qu'on
enregistre et que personne ne lit est pire qu'un fait absent, parce qu'il
donne l'impression d'avoir été collecté.

CE QUE LE GARDE CONTRÔLE

Chaque type déclaré dans `FactContracts.all` doit être consulté quelque part
dans `secure_wizard_store.dart` — par `forFact('<type>...')` pour les faits
qui se projettent membre par membre, ou par une recomposition dédiée pour
ceux qui s'agrègent.

Usage :
    python3 tools/checks/twin_every_fact_is_derived.py
    python3 tools/checks/twin_every_fact_is_derived.py --self-test
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
CONTRACTS = REPO / "apps/mobile/lib/services/twin/fact_contract.dart"
STORE = REPO / "apps/mobile/lib/services/secure_wizard_store.dart"

# Les faits qui ne se consultent PAS membre par membre : ils se reconstituent
# à partir de TOUS leurs membres. La marque de leur dérivation est l'appel de
# recomposition, pas un `forFact`.
AGGREGATED = {"versements_3a": "lookup.versements3a("}


def declared_types(source: str) -> list[str]:
    return re.findall(r"factType:\s*'([a-z_0-9]+)'", source)


def derived_types(source: str) -> set[str]:
    found = {t for t in re.findall(r"\.forFact\('([a-z_0-9]+)", source)}
    for fact_type, marker in AGGREGATED.items():
        if marker in source:
            found.add(fact_type)
    return found


def main() -> int:
    if not CONTRACTS.exists() or not STORE.exists():
        print("ÉCHEC — fichiers introuvables.")
        return 1

    declared = declared_types(CONTRACTS.read_text(encoding="utf-8"))
    derived = derived_types(STORE.read_text(encoding="utf-8"))

    if not declared:
        print("ÉCHEC — aucun type de fait lu dans le catalogue : le garde ne\n"
              "  contrôle plus rien. Vérifier le motif d'extraction.")
        return 1

    orphans = [t for t in declared if t not in derived]
    if orphans:
        print(f"ÉCHEC — {len(orphans)} fait(s) sans chemin de dérivation :")
        for fact_type in orphans:
            print(f"    {fact_type}")
        print(
            "\n  Ces faits peuvent entrer au registre, mais leur valeur\n"
            "  n'atteindra jamais les écrans : aucune canonicalisation ne les\n"
            "  consulte. L'écriture réussira, les tests du registre passeront,\n"
            "  et l'écran restera vide.\n"
            "\n"
            "  Ajouter un `canonicalize<Fait>Answers` qui interroge le jumeau\n"
            "  AVANT son repli — voir `canonicalizeDomicileAnswers`."
        )
        return 1

    print(f"OK twin_every_fact_is_derived — {len(declared)} fait(s) déclaré(s), "
          "tous dérivés.")
    return 0


def self_test() -> int:
    """Le garde doit voir ce qu'il a été écrit pour voir."""
    failures = 0

    sample_contracts = """
      FactContract(factType: 'domicile', cardinality: x),
      FactContract(factType: 'versements_3a', cardinality: y),
    """
    if declared_types(sample_contracts) != ["domicile", "versements_3a"]:
        print("ÉCHEC self-test : lecture du catalogue")
        failures += 1

    if "domicile" not in derived_types("(await _twinLookup(a)).forFact('domicile')"):
        print("ÉCHEC self-test : dérivation membre par membre non vue")
        failures += 1

    if "versements_3a" not in derived_types("final x = lookup.versements3a(\n"):
        print("ÉCHEC self-test : dérivation agrégée non vue")
        failures += 1

    if derived_types("rien du tout"):
        print("ÉCHEC self-test : faux positif sur une source vide")
        failures += 1

    # Et le cas qui compte : un fait declare mais jamais consulte doit sortir.
    declared = declared_types("FactContract(factType: 'orphelin', c: 1),")
    if [t for t in declared if t not in derived_types("")] != ["orphelin"]:
        print("ÉCHEC self-test : un fait orphelin doit être signalé")
        failures += 1

    if failures:
        return 1
    print("OK twin_every_fact_is_derived --self-test")
    return 0


if __name__ == "__main__":
    sys.exit(self_test() if "--self-test" in sys.argv else main())
