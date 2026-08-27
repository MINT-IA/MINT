#!/usr/bin/env python3
"""Réinjecte la colonne « DE base » dans le tableau principal du Price Report COB.

La colonne « DE base » (niveau BASE Allemagne en €/MWh, source EEX via Robotron,
feuille DE du fichier Price_Report_EEX_Yearly.xlsx) existait dans les itérations
du 26.08.2026 jusqu'à 18h39, puis a été retirée au profit des seuls spreads.
Ce script la restaure dans le HTML final, sans toucher au reste du rapport :

  1. le <th> de groupe « SPREADS » passe de colspan=2 à colspan=3 ;
  2. un sous-en-tête « DE base » est ajouté après « PK−BL » ;
  3. chaque ligne produit reçoit une cellule « DE base » clonée sur le style de
     sa cellule PK−BL (fond alterné, bordures, gris #6b6b6b — identique à la
     colonne telle qu'elle apparaissait dans la version 18h39 du 26.08.2026).

Attention : chaque ligne produit contient un tableau imbriqué (la barre de
position bas→haut) ; la cellule doit être insérée avant le </tr> EXTERNE de la
ligne, c'est-à-dire le premier </tr> qui n'est pas suivi de </table>.

Usage : add_de_base.py rapport.html valeurs_de.json > rapport_avec_de.html
        où valeurs_de.json = {"Sep 26": 136.55, "Oct 26": 139.59, ...}
"""
import json
import re
import sys


def fr(v: float) -> str:
    return f"{v:.2f}".replace(".", ",")


def outer_tr_end(html: str, start: int) -> int:
    """Position du </tr> externe suivant `start` (saute les </tr> imbriqués,
    reconnaissables à leur </table> immédiat)."""
    pos = start
    while True:
        i = html.index("</tr>", pos)
        if html[i + 5 : i + 13] == "</table>":
            pos = i + 5
            continue
        return i


def inject(html: str, de_values: dict) -> str:
    # 1. Élargir le groupe SPREADS (ou VALEUR RELATIVE selon l'itération).
    html, n = re.subn(
        r'(<th\s+colspan=")2("[^>]*>\s*(?:SPREADS|VALEUR RELATIVE)\s*</th>)',
        r"\g<1>3\g<2>",
        html,
        count=1,
    )
    if n != 1:
        raise SystemExit("groupe SPREADS colspan=2 introuvable — layout inattendu")

    # 2. Sous-en-tête « DE base » après « PK−BL » (en clonant son style).
    m = re.search(r"<th[^>]*>PK−BL</th>", html)
    if not m:
        raise SystemExit("sous-en-tête PK−BL introuvable")
    html = html[: m.end()] + m.group(0).replace("PK−BL", "DE base") + html[m.end():]

    # 3. Une cellule par ligne produit, clonée sur la cellule PK−BL
    #    (la dernière cellule simple avant le </tr> externe).
    for product, value in de_values.items():
        anchor = re.search(rf"<td[^>]*><b>{re.escape(product)}</b></td>", html)
        if not anchor:
            raise SystemExit(f"ligne produit introuvable : {product}")
        end = outer_tr_end(html, anchor.end())
        last_td = re.search(r'<td ([^>]*)>[^<]*</td>\s*$', html[: end])
        if not last_td:
            raise SystemExit(f"cellule PK−BL introuvable pour {product}")
        style = re.search(r'style="[^"]*"', last_td.group(1)).group(0)
        html = html[:end] + f"<td {style}>{fr(value)}</td>" + html[end:]
    return html


if __name__ == "__main__":
    html = open(sys.argv[1]).read()
    values = json.load(open(sys.argv[2]))
    sys.stdout.write(inject(html, values))
