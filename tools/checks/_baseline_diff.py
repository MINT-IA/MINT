#!/usr/bin/env python3
"""Comparaison de baseline insensible aux déplacements de lignes.

POURQUOI CE MODULE EXISTE

Les cinq lints du design system (`prefer_mint_cta`, `prefer_mint_text_style`,
`prefer_mint_fonts`, `prefer_mint_radius`, `prefer_mint_color_token`) gèlent
979 violations héritées dans des fichiers de baseline dont chaque entrée a la
forme `chemin:ligne: extrait`. Ils comparaient ensuite par
`set(current) - baseline` — le NUMÉRO DE LIGNE faisant partie de la clé.

Conséquence : toute édition en amont d'une entrée décale la ligne, et la même
violation, inchangée, est signalée comme NEUVE. Le 2026-07-26, déplacer un
unique `FilledButton` dans une autre classe a produit deux échecs de CI
successifs sur la même PR, plus sept recalages manuels sur une autre baseline.

Le coût n'est pas seulement le temps perdu. Un lint qui crie au loup à chaque
déplacement pousse à écrire `// lint-ignore` pour avoir la paix, ou à lancer
`--update-baseline` qui réécrit des entrées hors périmètre. Dans les deux cas
l'instrument cesse de protéger ce qu'il était censé protéger.

CE QUE FAIT CE MODULE

La clé devient `(chemin, extrait)` et la comparaison porte sur le NOMBRE
d'occurrences par clé. Une violation n'est neuve que si son nombre dépasse
celui de la baseline. Donc :

  - une violation déplacée      -> même clé, même compte -> NON signalée ;
  - une violation vraiment neuve -> compte supérieur      -> signalée ;
  - une violation supprimée      -> compte inférieur      -> rien à signaler.

Ce que cela n'attrape pas, et c'est assumé : remplacer une violation par une
autre du même extrait dans le même fichier laisse le compte inchangé. Le gel
reste donc au niveau « ce fichier a droit à N occurrences de cet extrait »,
ce qui est exactement la granularité voulue par un mode baseline-only.
"""
from __future__ import annotations

import re
import sys
from collections import Counter

# `lib/x/y.dart:227: FilledButton(` — le chemin peut contenir des « : » sous
# Windows, mais les baselines sont écrites en chemins POSIX relatifs.
_ROW = re.compile(r"^(?P<path>.+?):(?P<line>\d+):\s?(?P<snippet>.*)$")


def row_key(row: str) -> tuple[str, str]:
    """Clé stable d'une entrée : (chemin, extrait), sans le numéro de ligne."""
    m = _ROW.match(row.strip())
    if not m:
        # Entrée de forme inattendue : on la garde telle quelle plutôt que de
        # l'ignorer silencieusement, sinon une baseline malformée désarmerait
        # le lint sans que personne le voie.
        return (row.strip(), "")
    return (m.group("path"), m.group("snippet").strip())


def new_violations(current: list[str], baseline: set[str] | list[str]) -> list[str]:
    """Entrées de `current` qui dépassent le compte autorisé par `baseline`."""
    allowed = Counter(row_key(r) for r in baseline)
    seen: Counter[tuple[str, str]] = Counter()
    out: list[str] = []
    for row in sorted(current):
        key = row_key(row)
        seen[key] += 1
        if seen[key] > allowed.get(key, 0):
            out.append(row)
    return out


def self_test() -> int:
    """Prouve que la distinction « déplacé » / « nouveau » tient encore.

    Sans cet auto-test, une régression rendrait le lint permissif tout en le
    laissant sortir 0 — c'est-à-dire vert et inutile.
    """
    cases = [
        (
            "une violation déplacée n'est pas neuve",
            ["lib/a.dart:253: FilledButton("],
            {"lib/a.dart:227: FilledButton("},
            [],
        ),
        (
            "une violation vraiment neuve est signalée",
            ["lib/a.dart:227: FilledButton(", "lib/b.dart:10: TextButton("],
            {"lib/a.dart:227: FilledButton("},
            ["lib/b.dart:10: TextButton("],
        ),
        (
            "une SECONDE occurrence du même extrait est signalée",
            ["lib/a.dart:227: FilledButton(", "lib/a.dart:300: FilledButton("],
            {"lib/a.dart:227: FilledButton("},
            ["lib/a.dart:300: FilledButton("],
        ),
        (
            "une violation supprimée ne fait rien remonter",
            ["lib/a.dart:227: FilledButton("],
            {"lib/a.dart:227: FilledButton(", "lib/b.dart:10: TextButton("},
            [],
        ),
        (
            "le même extrait dans un AUTRE fichier est neuf",
            ["lib/b.dart:227: FilledButton("],
            {"lib/a.dart:227: FilledButton("},
            ["lib/b.dart:227: FilledButton("],
        ),
        (
            "deux occurrences gelées restent deux occurrences déplaçables",
            ["lib/a.dart:50: FilledButton(", "lib/a.dart:80: FilledButton("],
            {"lib/a.dart:10: FilledButton(", "lib/a.dart:20: FilledButton("},
            [],
        ),
        (
            "une entrée malformée reste comparée telle quelle",
            ["ligne sans forme attendue"],
            {"ligne sans forme attendue"},
            [],
        ),
    ]
    failures = 0
    for label, current, baseline, expected in cases:
        got = new_violations(current, baseline)
        if got != expected:
            print(f"_baseline_diff self-test FAIL [{label}]\n"
                  f"  attendu : {expected}\n  obtenu  : {got}", file=sys.stderr)
            failures += 1
    if failures:
        return 1
    print(f"_baseline_diff self-test OK ({len(cases)} cas)")
    return 0


if __name__ == "__main__":
    sys.exit(self_test())
