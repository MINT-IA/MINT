#!/usr/bin/env python3
"""Un garde que personne n'appelle n'est pas un garde.

POURQUOI CE FICHIER EXISTE

Le 2026-08-15, trois fois dans la même journée, j'ai livré un vérificateur
que rien n'invoquait :

  · `lego_lease_guard.py` — écrit le matin, câblé nulle part. Il a laissé
    passer un commit hors périmètre pendant qu'il existait ;
  · la parité des six fichiers de langue — désactivée en silence par une
    règle du harnais qui prenait `-` pour un fichier manquant ;
  · `verify_receipt_gate.py` — écrit, testé, fusionné dans `dev`, et le
    pré-envoi ne l'appelait pas.

Ce n'est pas de l'étourderie, c'est structurel : écrire un contrôle et le
brancher sont deux gestes, et seul le premier laisse une trace visible. Un
garde non branché est PIRE que pas de garde — il donne la confiance sans le
contrôle, et personne ne s'en aperçoit puisqu'il ne dit jamais rien.

CE QU'IL VÉRIFIE

Tout `tools/checks/*.py` exécutable comme contrôle doit être invoqué par au
moins un point d'entrée réel : `lefthook.yml`, un workflow `.github/`, ou
`tools/verify_full.sh`. Sinon il est orphelin, et le harnais échoue.

Les exceptions se DÉCLARENT dans `EXEMPTS`, avec leur raison. Une exception
est une ligne de diff que quelqu'un relit ; un orphelin silencieux ne l'est
par personne.
"""

from __future__ import annotations

import sys
from pathlib import Path

RACINE = Path(__file__).resolve().parents[2]
CHECKS = RACINE / "tools/checks"

# Points d'entrée réels. Un garde cité ailleurs — un README, un commentaire —
# n'est pas branché pour autant.
ENTREES = [
    RACINE / "lefthook.yml",
    *sorted((RACINE / ".github/workflows").glob("*.yml")),
    # Tout script shell de `tools/` compte : la première version ne lisait que
    # `verify_full.sh` et déclarait orphelins des gardes lancés par
    # `tools/ship_gate/run_all_gates_v2_2.sh`. Un contrôle qui accuse à tort
    # finit désactivé.
    *sorted((RACINE / "tools").rglob("*.sh")),
]

EXEMPTS = {
    "__init__.py": "paquet, pas un contrôle",
    "gardes_cables_check.py": "ce fichier — il se contrôlerait lui-même",

    # LA DETTE DU PREMIER JOUR, DÉCLARÉE PLUTÔT QUE TUE.
    #
    # Ce garde a trouvé 20 vérificateurs que personne n'appelle.
    # En faire échouer le harnais aujourd'hui bloquerait tout ; les taire
    # laisserait le motif prospérer. On les DÉCLARE donc, une fois, en clair :
    # le garde est dur dès le premier jour pour tout NOUVEL orphelin, et cette
    # liste ne peut que rétrécir — chaque ligne retirée est un garde branché
    # ou un fichier supprimé.
    #
    # Le plus parlant : `wiring_check.py` avait été écrit pour ce motif exact
    # — « le fichier existe, les tests passent, aucun consommateur » — et il
    # était orphelin lui-même. Le dépôt portait déjà la réponse, non branchée.
    "audit_artefact_shape.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "budget_read_contract.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "claude_md_bracket.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "claude_md_triplets.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "create_or_update_mint_skills.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "ios_universal_links_release_gate.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "mint_next_storyboard_guard.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "mint_next_three_a_goal_annexes_guard.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "mint_quality_os_check.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "mint_variable_contract_extract.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "mint_variable_dictionary_lint.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "nav_graph.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "no_legal_admission_in_public_docs.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "no_mobile_fact_current_regulatory_read.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "no_stale_regulatory_anchors.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "sentry_capture_single_source.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "test_banned_terms_arb.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "tool_description_rubric.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "user_data_capture_contract.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
    "wiring_check.py": "DETTE 2026-08-15 — orphelin trouvé le jour où ce garde a été écrit ; à câbler ou à supprimer",
}

PREFIXES_EXEMPTS = (
    ("generate_", "générateur, pas un contrôle : il produit, il ne refuse pas"),
    ("regen_", "régénérateur, pas un contrôle"),
)


def raison_exemption(nom: str) -> str | None:
    if nom in EXEMPTS:
        return EXEMPTS[nom]
    for prefixe, raison in PREFIXES_EXEMPTS:
        if nom.startswith(prefixe):
            return raison
    return None


def main() -> int:
    corpus = ""
    for f in ENTREES:
        if f.is_file():
            corpus += f.read_text(encoding="utf-8", errors="replace")

    # UN MODULE IMPORTÉ PAR UN GARDE BRANCHÉ EST BRANCHÉ.
    #
    # Première version : 22 orphelins, dont `journey_os_generate` et
    # `nav_graph`, importés par des gardes qui tournent bel et bien. Un
    # contrôle qui crie 22 fois à tort finit désactivé — et c'est ainsi qu'on
    # perd un contrôle utile. On lit donc aussi les imports entre gardes.
    imports = "".join(
        f.read_text(encoding="utf-8", errors="replace")
        for f in CHECKS.glob("*.py")
    )

    orphelins: list[str] = []
    branches = 0
    exemptes = 0

    for f in sorted(CHECKS.glob("*.py")):
        raison = raison_exemption(f.name)
        if raison:
            exemptes += 1
            continue
        module = f.stem
        cite_en_import = (
            f"import {module}" in imports or f"from {module} " in imports
            or f"checks.{module}" in imports
        )
        if f.name in corpus or cite_en_import:
            branches += 1
        else:
            orphelins.append(f.name)

    if orphelins:
        print(f"ÉCHEC gardes_cables_check : {len(orphelins)} garde(s) que "
              f"personne n'appelle.")
        for nom in orphelins:
            print(f"  · tools/checks/{nom}")
        print("  → le brancher dans lefthook.yml, un workflow, ou")
        print("    tools/verify_full.sh ; ou le déclarer dans EXEMPTS avec sa")
        print("    raison. Un garde non branché donne la confiance sans le")
        print("    contrôle, et ne dit jamais rien pour se signaler.")
        return 1

    print(f"OK gardes_cables_check — {branches} garde(s) branché(s), "
          f"{exemptes} exemption(s) déclarée(s).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
