#!/usr/bin/env python3
"""Le bail du Lego — ce que le loop a le droit de faire, et rien d'autre.

POURQUOI CE FICHIER EXISTE

Le 14.08.2026, un loop autonome a tourné une journée sur un texte figé la
semaine précédente. Il a fidèlement répété un ordre du jour mort : le Lego
réellement en cours (bascule 4) n'a pas été touché, `product/mint_next/BRIEF.md`
— que la méthode déclare « lu au début de chaque session » — n'a jamais été
ouvert, et une PR de 159 fichiers hors cadence a notifié Julien d'échecs CI.

Un axe adverse a corrigé le diagnostic : le texte périmé n'était que la cause
immédiate. La cause profonde est qu'une prose ancienne gardait le pouvoir de
CHOISIR LE TRAVAIL, sans contrôle d'autorité, de périmètre ni de terminaison.
Et son verdict tient en une phrase :

    « La dérive ne devient mécaniquement impossible que si le wrapper et le
      pre-push imposent ce bail. Un meilleur prompt seul reste contournable. »

D'où ce garde. Il ne conseille pas, il REFUSE.

CE QU'IL VÉRIFIE
  1. le bail existe, est actif, et nomme un Lego ;
  2. le cadrage et le storyboard qu'il cite existent VRAIMENT sur disque ;
  3. chaque beat déclaré vert a une preuve, et cette preuve existe ;
  4. il reste au moins un beat ouvert — sinon le Lego est fini et le loop doit
     s'arrêter au lieu d'inventer la suite ;
  5. le travail en cours ne sort pas de `allowed_paths`.

Le point 4 est le plus important : c'est celui qui ARRÊTE. Un loop qui ne sait
pas s'arrêter réinvente du travail — c'est exactement ce qui s'est passé.

DEUX MÉTIERS, DEUX MODES (2026-08-15)

Ce garde a été écrit pour être incontournable, et il n'était appelé NULLE PART
— ni crochet, ni harnais. Il a laissé passer un commit hors périmètre le jour
même de son écriture. Motif connu : la capacité existe, l'appel manque.

En cherchant à le câbler, la raison est apparue : il confondait deux questions
sous un seul code de sortie.

  · « ce changement sort-il du bail ? »  — question de COMMIT
  · « le loop doit-il continuer ? »      — question de LOOP

Les tenir ensemble le rendait incâblable : un Lego dont tous les beats sont
verts sort 1, ce qui bloquerait n'importe quel commit de n'importe qui, y
compris sur une branche sans bail actif.

D'où `--portee`, qui ne pose que la première question et LAISSE PASSER quand
aucun bail n'est actif : on n'enferme que ce qu'un bail revendique.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEASE = ROOT / "product" / "mint_next" / "lego_lease.json"


def _fail(msg: str) -> int:
    print(f"STOP lego_lease_guard : {msg}")
    print("  → aucune écriture, aucun commit, aucune PR. Rendre la main.")
    return 1


def _changed_paths(portee: bool = False) -> list[str]:
    """Ce que l'arbre courant modifie — index, arbre de travail, non suivis.

    En mode `--portee` on ne regarde QUE l'index : un crochet de pré-commit
    juge le commit qu'on écrit, pas un brouillon posé à côté.
    """
    sources = (
        [["git", "diff", "--cached", "--name-only"]]
        if portee
        else [
            ["git", "diff", "--name-only"],
            ["git", "diff", "--cached", "--name-only"],
            ["git", "ls-files", "--others", "--exclude-standard"],
        ]
    )
    out: set[str] = set()
    for args in sources:
        p = subprocess.run(args, cwd=ROOT, text=True, capture_output=True)
        if p.returncode:
            continue
        out.update(l for l in p.stdout.splitlines() if l)
    return sorted(out)


def main() -> int:
    portee = "--portee" in sys.argv

    if not LEASE.exists():
        if portee:
            return 0  # aucun bail ne revendique ce dépôt
        return _fail(f"bail absent ({LEASE.relative_to(ROOT)})")

    try:
        bail = json.loads(LEASE.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        return _fail(f"bail illisible : {exc}")

    if not bail.get("active"):
        if portee:
            return 0  # bail au repos : il n'enferme rien
        return _fail("bail inactif — aucun Lego n'est ouvert")

    lego = bail.get("lego")
    if not lego:
        return _fail("le bail ne nomme aucun Lego")

    # UN BAIL GOUVERNE UNE BRANCHE, ET SE TAIT AILLEURS.
    #
    # Le bail est un fichier COMMITÉ. Une fois fondu dans `dev`, il voyagerait
    # avec l'historique et jugerait les commits de tout le monde contre une
    # branche qui n'existe plus. Hors de sa branche, il n'a rien à dire.
    branche_bail = bail.get("worktree", {}).get("branche") or bail.get("branche")
    branche_ici = subprocess.run(
        ["git", "rev-parse", "--abbrev-ref", "HEAD"],
        cwd=ROOT, text=True, capture_output=True,
    ).stdout.strip()
    if branche_bail and branche_ici != branche_bail:
        if portee:
            return 0
        return _fail(
            f"branche « {branche_ici or '?'} » alors que le bail déclare "
            f"« {branche_bail} »"
        )

    # Le contrat doit exister sur disque. Un bail qui cite un cadrage absent
    # laisserait le loop travailler sans contrat — le trou d'origine.
    # Le CADRAGE doit toujours exister : sans lui, le loop travaille sans
    # contrat, et c'est le trou d'origine.
    cadrage = bail.get("cadrage")
    if not cadrage or not (ROOT / cadrage).exists():
        return _fail(f"le cadrage cité par le bail est introuvable : {cadrage}")

    # Le STORYBOARD peut être À LIVRER — mais alors aucun beat ne peut être
    # vert. Nuance ajoutée le 2026-08-15 en armant le worktree de
    # reconstruction : sur une base propre, le contrat n'est pas encore porté,
    # et exiger sa présence aurait forcé soit à tout importer d'un coup, soit
    # à relâcher le garde. Ni l'un ni l'autre. Un beat vert SANS contrat serait
    # une preuve sans promesse — c'est ça qu'on interdit.
    storyboard = bail.get("storyboard")
    storyboard_present = bool(storyboard) and (ROOT / storyboard).exists()
    if storyboard and not storyboard_present and not bail.get("storyboard_a_livrer"):
        return _fail(
            f"le storyboard cité est introuvable : {storyboard}. S'il reste à "
            "porter, le déclarer avec `storyboard_a_livrer: true` — et alors "
            "aucun beat ne pourra être vert."
        )

    # UN SEUL JOURNAL DES LEGOS.
    #
    # Le 2026-08-15, `product/mint_next/BRIEF.md` en portait DEUX : l'un avec
    # onze Legos livrés, l'autre affirmant « aucun livré sous ce protocole ».
    # Le second était un talon jamais rempli, resté depuis la conception du
    # protocole.
    #
    # Personne ne l'avait vu, et j'allais construire un tableau de bord en
    # parsant l'un des deux — au hasard. Une source qui se contredit ne produit
    # pas une vue incomplète : elle produit une vue qui MENT, avec l'autorité
    # d'un fichier généré.
    brief = ROOT / "product" / "mint_next" / "BRIEF.md"
    if brief.exists():
        journaux = [
            l for l in brief.read_text(encoding="utf-8").splitlines()
            if l.startswith("#") and "Journal des Legos" in l
        ]
        if len(journaux) != 1:
            return _fail(
                f"le BRIEF porte {len(journaux)} journaux des Legos, il en faut "
                "UN. Deux journaux, c'est deux vérités — et celle qu'on lit "
                "dépend de l'ordre de lecture.\n  " + "\n  ".join(journaux)
            )

    beats = bail.get("beats") or []
    if not beats:
        return _fail("le bail ne déclare aucun beat")

    # LE BAIL SUIT EXACTEMENT LES BEATS DU STORYBOARD.
    #
    # Le 2026-08-15, le storyboard de la première ouverture en déclarait NEUF
    # et le bail en suivait HUIT. Le manquant — `b4_empty_today` — avait son
    # écran, son widget et ses deux tests sur la branche : le travail existait,
    # la comptabilité ne le voyait pas.
    #
    # C'est le pire cas, pas le plus bénin. Un beat que le bail ignore ne peut
    # ni exiger de preuve, ni exiger de verdict, ni empêcher la clôture — le
    # Lego se serait déclaré fini avec un neuvième de son contrat non gardé.
    if storyboard_present:
        try:
            sb = json.loads((ROOT / storyboard).read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as exc:
            return _fail(f"storyboard illisible : {exc}")
        sb_ids = {b.get("id") for b in (sb.get("beats") or []) if b.get("id")}
        if sb_ids:
            bail_ids = {b.get("id") for b in beats if b.get("id")}
            if sb_ids != bail_ids:
                manquants = sorted(sb_ids - bail_ids)
                en_trop = sorted(bail_ids - sb_ids)
                detail = []
                if manquants:
                    detail.append("  absents du bail : " + ", ".join(manquants))
                if en_trop:
                    detail.append("  inconnus du storyboard : " + ", ".join(en_trop))
                return _fail(
                    "le bail et le storyboard ne suivent pas les mêmes beats.\n"
                    + "\n".join(detail)
                    + "\n  Le storyboard est le contrat : un beat qu'il déclare "
                    "et que le bail ignore n'exige ni preuve ni verdict."
                )

    # Un beat vert SANS preuve est un mensonge de tableau de bord.
    for b in beats:
        if b.get("etat") == "vert":
            preuve = b.get("preuve")
            if not preuve or not (ROOT / preuve).exists():
                return _fail(
                    f"beat « {b.get('id')} » déclaré vert mais sa preuve est "
                    f"absente : {preuve}"
                )

    # RIEN NE SE FERME SANS VERDICT CODEX. Idée de Julien, 2026-08-15.
    #
    # J'avais écrit avoir besoin de lui pour un « superviseur extérieur non
    # modifiable par l'agent ». Il a répondu : Codex est exactement cela. Il
    # avait raison — Codex est hors de moi, je ne peux pas le modifier, et il
    # juge seul. Ce qui lui manquait, c'est que son avis n'arrêtait rien : je
    # choisissais quand l'appeler, et je pouvais l'ignorer.
    #
    # Ici il cesse d'être un conseiller. Un beat déclaré vert doit citer un
    # verdict qui EXISTE sur disque. Je ne peux plus fermer sans l'avoir
    # consulté, et l'absence se voit.
    for b in beats:
        if b.get("etat") == "vert":
            if not storyboard_present:
                return _fail(
                    f"beat « {b.get('id')} » déclaré vert alors que le "
                    "storyboard n'est pas porté. Une preuve sans promesse ne "
                    "prouve rien : le contrat vient d'abord."
                )
            verdict = b.get("verdict_codex")
            if not verdict or not (ROOT / verdict).exists():
                return _fail(
                    f"beat « {b.get('id')} » déclaré vert sans verdict Codex "
                    f"({verdict or 'aucun'}). Lancer `tools/codex_axes.sh` et "
                    "déposer sa sortie avant de fermer."
                )

    ouverts = [b for b in beats if b.get("etat") != "vert"]
    if not ouverts and not portee:
        print(f"STOP lego_lease_guard : les {len(beats)} beats de « {lego} » sont verts.")
        print("  → le Lego est terminé. Rendre la main pour clôture et cadrage")
        print("    du suivant. Un beat terminé ne donne JAMAIS permission")
        print("    d'inventer le suivant.")
        return 1

    # LE BAIL NE PEUT PAS S'ÉLARGIR PENDANT QU'IL TRAVAILLE.
    #
    # Défaut trouvé par un axe adverse le 2026-08-15 : le bail s'autorisait
    # LUI-MÊME et autorisait le GARDE dans ses `allowed_paths`. Un loop pouvait
    # donc étendre sa propre laisse au milieu d'une tâche — ce que j'ai fait
    # trois fois le 14, de bonne foi, sans m'en apercevoir.
    #
    # Le bail reste modifiable, sinon on ne pourrait jamais fermer un beat.
    # Mais SEUL : si le bail ou le garde bougent en même temps que du code, on
    # refuse. Une mise à jour de bail est son propre commit, jamais un
    # élargissement glissé dans un lot.
    meta_exact = {"product/mint_next/lego_lease.json", "tools/checks/lego_lease_guard.py"}
    # Les verdicts Codex appartiennent à la comptabilité du bail, pas au
    # produit : les déposer n'est pas « du code qui bouge ».
    meta_prefixes = (".planning/phases/mint-next-user-twin-foundation-20260808/verdicts/",)
    modifies = set(_changed_paths(portee))
    meta = {c for c in modifies
            if c in meta_exact or c.startswith(meta_prefixes)}
    if meta & meta_exact and modifies - meta:
        print("STOP lego_lease_guard : le bail (ou son garde) bouge EN MÊME TEMPS que du code.")
        for c in sorted(modifies & meta):
            print(f"  bail   · {c}")
        for c in sorted(modifies - meta):
            print(f"  code   · {c}")
        print("  → une mise à jour de bail est son PROPRE commit. Autrement, on")
        print("    élargit sa laisse au milieu d'une tâche sans que personne le voie.")
        return 1

    base = bail.get("base_sha")
    if base:
        anc = subprocess.run(
            ["git", "merge-base", "--is-ancestor", base, "HEAD"],
            cwd=ROOT, capture_output=True,
        )
        if anc.returncode != 0:
            return _fail(
                f"la base déclarée ({base[:9]}) n'est pas un ancêtre de HEAD — "
                "l'historique a bougé sous le bail"
            )

    # Périmètre : ce qui est modifié doit être annoncé par le bail.
    autorises = bail.get("allowed_paths") or []
    hors = [
        c
        for c in _changed_paths(portee)
        if not any(c.startswith(a) for a in autorises)
    ]
    if hors:
        print(f"STOP lego_lease_guard : {len(hors)} chemin(s) hors périmètre du bail.")
        for c in hors[:10]:
            print(f"  · {c}")
        if len(hors) > 10:
            print(f"  … et {len(hors) - 10} autre(s)")
        print("  → soit le bail les autorise explicitement, soit ce travail")
        print("    n'appartient pas à ce Lego et attend son propre cadrage.")
        return 1

    if portee:
        print(f"OK lego_lease_guard --portee — dans le bail « {lego} »")
        return 0

    suivant = ouverts[0]
    print(f"OK lego_lease_guard — Lego « {lego} » ({bail.get('titre','')})")
    print(f"  beats verts   : {len(beats) - len(ouverts)}/{len(beats)}")
    print(f"  BEAT COURANT  : {suivant.get('id')}")
    print(f"  cadrage       : {bail['cadrage']}")
    print(f"  storyboard    : {bail['storyboard']}")
    print("  acceptation   :")
    for cmd in bail.get("acceptation", []):
        print(f"    $ {cmd}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
