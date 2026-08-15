#!/usr/bin/env python3
"""Refuse un envoi dont le contenu envoyé n'a pas été vérifié en entier.

Ce garde existe parce qu'une promesse de rigueur ne tient pas. Le 2026-08-13,
deux fois dans la même session, j'ai annoncé « tests verts » après avoir lancé
les tests des seuls fichiers que je venais d'écrire ; la suite complète a
ensuite montré 9 échecs, dont 7 miens, dans des fichiers que je n'avais pas
ouverts. Le périmètre de vérification était mon choix, et je l'ai mal choisi.

PREMIÈRE VERSION, ET SA FAILLE. J'avais comparé le reçu à `HEAD^{tree}`. Une
relecture adversariale l'a cassée en une ligne : un crochet `pre-push` reçoit
sur son entrée standard les références réellement envoyées, et je ne les lisais
pas. `git push origin <autre-sha>:refs/heads/dev` passait donc le garde en
envoyant un arbre jamais vérifié, sans le moindre `--no-verify`. Le poussé de
plusieurs références était pire encore : une seule pointe était contrôlée.

Cette version lit l'entrée standard et exige que CHAQUE référence envoyée porte
l'arbre attesté par le reçu.

Contourner reste possible avec `git push --no-verify` : c'est un acte explicite.
Ce qui n'est PAS couvert, et doit être dit : un crochet local n'est pas une
garantie de dépôt. Un clone sans lefthook installé, un `core.hooksPath`
détourné, un robot ou le bouton de fusion de la forge poussent sans passer ici.
La seule barrière qui tienne pour `dev`, `staging` et `main` est un contrôle
obligatoire côté serveur.
"""

from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
RECEIPT = REPO / ".planning/.verify/receipt.json"

ZERO_SHA = "0" * 40

# Les gates que le reçu DOIT porter. Un reçu qui n'en déclare que trois n'est
# pas un reçu partiel : c'est un reçu d'autre chose.
REQUIRED_GATES = {
    "analyse statique mobile",
    "suite mobile COMPLÈTE",
    "suite backend",
    "garde Journey OS",
    "lint du wiki",
    "intégrité du registre des communes",
    "discipline d'écriture du jumeau",
    "couverture des tests par la CI",
    "auto-test du garde de reçu",
    "parité des 6 fichiers de langue",
}


def tree_of(commit: str) -> str | None:
    result = subprocess.run(
        ["git", "rev-parse", f"{commit}^{{tree}}"],
        cwd=REPO,
        capture_output=True,
        text=True,
    )
    return result.stdout.strip() if result.returncode == 0 else None


def pushed_commits(stdin_text: str) -> list[tuple[str, str]]:
    """Les couples (référence locale, sha local) réellement envoyés.

    Format d'entrée d'un crochet pre-push, une ligne par référence :
        <ref locale> <sha local> <ref distante> <sha distant>

    Un sha local à zéro est une SUPPRESSION de branche : rien n'est envoyé,
    donc rien à vérifier.
    """
    refs: list[tuple[str, str]] = []
    for line in stdin_text.splitlines():
        parts = line.split()
        if len(parts) < 4:
            continue
        local_ref, local_sha = parts[0], parts[1]
        if local_sha == ZERO_SHA or set(local_sha) == {"0"}:
            continue
        refs.append((local_ref, local_sha))
    return refs


def refuse(message: str) -> int:
    print(f"ENVOI REFUSÉ — {message}", file=sys.stderr)
    print(
        "\n  Lancer :  tools/verify_full.sh\n"
        "  (la vérification porte sur TOUT : lancer les tests des fichiers\n"
        "   modifiés ne suffit pas — un test d'architecture lit le source\n"
        "   comme du texte, une référence visuelle dépend d'un rendu, un\n"
        "   écran d'administration compte les valeurs d'une enum.)\n",
        file=sys.stderr,
    )
    return 1


def main() -> int:
    stdin_text = "" if sys.stdin.isatty() else sys.stdin.read()
    refs = pushed_commits(stdin_text)

    if not stdin_text.strip():
        # Appel hors crochet (essai manuel) : on contrôle HEAD, en le disant.
        head = tree_of("HEAD")
        if head is None:
            print("verify_receipt_gate : dépôt sans HEAD, rien à contrôler.")
            return 0
        refs = [("HEAD (hors crochet)", "HEAD")]

    if not refs:
        print("verify_receipt_gate : suppression de référence, rien à vérifier.")
        return 0

    if not RECEIPT.exists():
        return refuse("aucun reçu de vérification.")

    try:
        receipt = json.loads(RECEIPT.read_text(encoding="utf-8"))
    except (ValueError, OSError) as error:
        return refuse(f"reçu illisible : {error}")

    verified = receipt.get("arbre")
    if not isinstance(verified, str) or len(verified) != 40:
        return refuse("le reçu ne porte pas d'identifiant d'arbre exploitable.")

    gates = receipt.get("gates")
    if not isinstance(gates, dict):
        return refuse("le reçu ne porte pas de relevé de gates.")

    missing = REQUIRED_GATES - set(gates)
    if missing:
        return refuse(
            "le reçu n'atteste pas tous les gates obligatoires.\n"
            + "\n".join(f"    absent : {name}" for name in sorted(missing))
        )

    # « absent » n'est PAS un échec — mais il n'est pas un succès non plus.
    #
    # Le harnais et ce garde portaient deux définitions contradictoires de la
    # même notion : le harnais déclarait « un contrôle absent n'est pas un
    # contrôle échoué », ce garde comptait tout code ≠ 0 comme un échec. Une
    # moitié enseignée, l'autre laissée en arrière — la forme exacte du défaut
    # trouvé le même jour sur la bascule 2.
    #
    # L'absence n'est acceptée que DÉCLARÉE (tools/checks/verify_absents.txt),
    # et le garde la dit à voix haute plutôt que de la laisser passer en
    # silence : un reçu doit refléter la couverture réelle, jamais la
    # suggérer.
    failed, absents = classify_gates(gates)
    if failed:
        return refuse(
            "le reçu enregistre des échecs :\n"
            + "\n".join(f"    {name} → {code}" for name, code in failed.items())
        )
    if absents:
        print(
            "Reçu accepté AVEC des contrôles absents (déclarés) :\n"
            + "\n".join(f"    absent : {name}" for name in sorted(absents))
        )

    for ref, sha in refs:
        tree = tree_of(sha)
        if tree is None:
            return refuse(f"référence {ref} illisible ({sha}).")
        if tree != verified:
            return refuse(
                f"le reçu ne porte pas sur le contenu envoyé.\n"
                f"    référence : {ref}\n"
                f"    vérifié   : {verified}\n"
                f"    envoyé    : {tree}"
            )

    print(
        f"verify_receipt_gate : {len(refs)} référence(s), arbre {verified[:12]} "
        f"vérifié le {receipt.get('verifie_le')} — "
        f"{len(gates) - len(absents)} gate(s) à 0, {len(absents)} absent(s)."
    )
    return 0


def classify_gates(gates: dict) -> tuple[dict, list]:
    """Trie les gates du reçu en ÉCHECS et ABSENCES.

    Extrait de `main()` pour pouvoir être mis à l'épreuve : la règle vivait en
    ligne, donc l'auto-test ne la touchait pas. Un tri qu'on ne peut pas tester
    est un tri qu'on croit juste.

    Seule la chaîne exacte « absent » vaut absence. Un code inconnu est un
    ÉCHEC : mieux vaut refuser un reçu qu'on ne sait pas lire que l'accepter
    parce qu'il n'entre dans aucune case.
    """
    absents = [name for name, code in gates.items() if code == "absent"]
    failed = {
        name: code
        for name, code in gates.items()
        if code != 0 and code != "absent"
    }
    return failed, absents


def self_test() -> int:
    """Les deux failles trouvées par la relecture, converties en contrôles.

    Règle de conversion : tout défaut trouvé par une relecture payante et
    mécaniquement détectable devient un contrôle gratuit, pour ne plus jamais
    être payé deux fois.
    """
    cases = [
        # (entrée standard, références attendues)
        ("refs/heads/x abc123 refs/heads/dev def456\n", [("refs/heads/x", "abc123")]),
        # Poussée multiple : les DEUX pointes doivent être contrôlées — la
        # première version n'en contrôlait aucune, elle regardait HEAD.
        (
            "refs/heads/a aaa refs/heads/a 111\nrefs/heads/b bbb refs/heads/b 222\n",
            [("refs/heads/a", "aaa"), ("refs/heads/b", "bbb")],
        ),
        # Suppression de branche : rien n'est envoyé, rien à vérifier.
        (f"(delete) {ZERO_SHA} refs/heads/vieux ccc\n", []),
        # Ligne tronquée : ignorée plutôt qu'interprétée de travers.
        ("refs/heads/x abc\n", []),
        ("", []),
    ]
    failures = 0
    for stdin_text, expected in cases:
        got = pushed_commits(stdin_text)
        if got != expected:
            print(f"ÉCHEC self-test : {stdin_text!r} → {got}, attendu {expected}")
            failures += 1

    if not REQUIRED_GATES:
        print("ÉCHEC self-test : aucun gate obligatoire déclaré")
        failures += 1

    # Le tri échec / absence. Ajouté le 2026-08-15 : le harnais et ce garde
    # portaient deux définitions contradictoires de « absent », et rien ne
    # l'avait vu parce que rien ne le mesurait.
    tris = [
        ({"a": 0, "b": 0}, {}, []),
        ({"a": 0, "b": "absent"}, {}, ["b"]),
        ({"a": 1}, {"a": 1}, []),
        ({"a": "absent", "b": 2}, {"b": 2}, ["a"]),
        # Un code inconnu n'est PAS une absence : on refuse ce qu'on ne sait
        # pas lire plutôt que de le laisser passer par défaut.
        ({"a": "ABSENT"}, {"a": "ABSENT"}, []),
        ({"a": "skipped"}, {"a": "skipped"}, []),
        ({"a": None}, {"a": None}, []),
    ]
    for gates, att_failed, att_absents in tris:
        got_failed, got_absents = classify_gates(gates)
        if got_failed != att_failed or sorted(got_absents) != sorted(att_absents):
            print(
                f"ÉCHEC self-test classify_gates : {gates} → "
                f"({got_failed}, {got_absents}), attendu "
                f"({att_failed}, {att_absents})"
            )
            failures += 1

    if failures:
        return 1
    print(f"OK verify_receipt_gate --self-test ({len(cases)} cas d'entrée, {len(tris)} cas de tri)")
    return 0


if __name__ == "__main__":
    if "--self-test" in sys.argv:
        sys.exit(self_test())
    sys.exit(main())
