#!/usr/bin/env python3
"""Refuse un envoi dont l'arbre n'a pas été vérifié en entier.

Ce garde existe parce qu'une promesse de rigueur ne tient pas. Le 2026-08-13,
deux fois dans la même session, j'ai annoncé « tests verts » après avoir lancé
les tests des seuls fichiers que je venais d'écrire ; la suite complète a
ensuite montré 9 échecs, dont 7 miens, dans des fichiers que je n'avais pas
ouverts. Le périmètre de vérification était mon choix, et je l'ai mal choisi.

Ce fichier retire le choix. `tools/verify_full.sh` écrit un reçu portant
l'identifiant de l'arbre Git qu'il a vérifié. Ici, on compare cet identifiant à
celui de l'arbre qu'on s'apprête à envoyer. S'ils diffèrent, l'envoi est
refusé — pas parce que quelqu'un a oublié une règle, mais parce que la preuve
ne correspond pas à l'objet.

Contourner reste possible avec `git push --no-verify` : c'est un acte explicite
et visible dans l'historique du terminal, pas un oubli silencieux.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RECEIPT = REPO / ".planning/.verify/receipt.json"

# Branches partagées : c'est là que la preuve compte.
PROTECTED_PREFIXES = ("refs/heads/dev", "refs/heads/staging", "refs/heads/main")


def head_tree() -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", "HEAD^{tree}"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def main() -> int:
    tree = head_tree()
    if tree is None:
        print("verify_receipt_gate : dépôt sans HEAD, rien à contrôler.")
        return 0

    if not RECEIPT.exists():
        print(
            "ENVOI REFUSÉ — aucun reçu de vérification.\n"
            "\n"
            "  L'arbre que tu envoies n'a pas été vérifié EN ENTIER. Lancer les\n"
            "  tests des fichiers modifiés ne suffit pas : un test d'architecture\n"
            "  lit le code source comme du texte, une référence visuelle dépend\n"
            "  d'un rendu, un écran d'administration compte les valeurs d'une\n"
            "  enum. Aucun de ces liens n'apparaît dans un graphe d'appels.\n"
            "\n"
            "  Lancer :  tools/verify_full.sh\n",
            file=sys.stderr,
        )
        return 1

    try:
        receipt = json.loads(RECEIPT.read_text(encoding="utf-8"))
    except (ValueError, OSError) as error:
        print(f"ENVOI REFUSÉ — reçu illisible : {error}", file=sys.stderr)
        return 1

    verified = receipt.get("arbre")
    if verified != tree:
        print(
            "ENVOI REFUSÉ — le reçu ne porte pas sur cet arbre.\n"
            "\n"
            f"  vérifié : {verified}\n"
            f"  envoyé  : {tree}\n"
            "\n"
            "  Quelque chose a changé depuis la dernière vérification complète.\n"
            "  Relancer :  tools/verify_full.sh\n",
            file=sys.stderr,
        )
        return 1

    failed = {name: code for name, code in receipt.get("gates", {}).items() if code != 0}
    if failed:
        print(
            "ENVOI REFUSÉ — le reçu enregistre des échecs :\n"
            + "\n".join(f"  {name} → {code}" for name, code in failed.items()),
            file=sys.stderr,
        )
        return 1

    print(
        f"verify_receipt_gate : arbre {tree[:12]} vérifié le "
        f"{receipt.get('verifie_le')} — {len(receipt.get('gates', {}))} gates à 0."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
