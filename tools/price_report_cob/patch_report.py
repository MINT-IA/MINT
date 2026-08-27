#!/usr/bin/env python3
"""Patchs de référence pour le Price Report COB (spec des changements à
reporter dans le générateur du Mac mini, utilisable aussi en post-traitement).

1. Colonne « DE base » — niveau BASE Allemagne en €/MWh (feuille DE du fichier
   Price_Report_EEX_Yearly.xlsx). Présente dans les itérations du 26.08.2026
   jusqu'à 18h39, retirée ensuite ; restaurée ici :
     - le <th> de groupe « SPREADS » passe de colspan=2 à colspan=3 ;
     - un sous-en-tête « DE base » est ajouté après « PK−BL » ;
     - chaque ligne produit reçoit une cellule clonée sur le style de sa
       cellule PK−BL (fond alterné, bordures, gris #6b6b6b).
   Attention : chaque ligne contient un tableau imbriqué (la barre de position
   bas→haut) ; la cellule s'insère avant le </tr> EXTERNE de la ligne, le
   premier </tr> qui n'est pas immédiatement suivi de </table>.

2. Tendance EUR/CHF dans l'en-tête — « EUR/CHF 0,9379 » devient
   « EUR/CHF 0,9379 · 1j +0,14 % · 1m +0,87 % · 1an +0,09 % ».
   Références : veille cotée, même date −1 mois, même date −1 an (feuille FX,
   jours calendaires avec week-ends reportés — prendre la valeur au plus
   proche à date ≤ cible).

Usage : patch_report.py rapport.html valeurs_de.json [fx.json] > rapport_patché.html
        valeurs_de.json = {"Sep 26": 136.55, "Oct 26": 139.59, ...}
        fx.json = {"1 jour": {"pct": 0.14}, "1 mois": {"pct": 0.87}, "1 an": {"pct": 0.09}}
"""
import json
import re
import sys


def fr(v: float, dec: int = 2) -> str:
    return f"{v:.{dec}f}".replace(".", ",")


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


def add_de_base(html: str, de_values: dict) -> str:
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


def add_fx_trend(html: str, fx: dict) -> str:
    trend = " · ".join(
        f"{label} {'+' if fx[key]['pct'] >= 0 else '−'}{fr(abs(fx[key]['pct']))} %"
        for label, key in (("1j", "1 jour"), ("1m", "1 mois"), ("1an", "1 an"))
    )
    html, n = re.subn(
        r"(EUR/CHF (?:\d+,\d+))(</div>)",
        rf"\g<1> · {trend}\g<2>",
        html,
        count=1,
    )
    if n != 1:
        raise SystemExit("en-tête EUR/CHF introuvable — layout inattendu")
    return html


if __name__ == "__main__":
    html = open(sys.argv[1]).read()
    html = add_de_base(html, json.load(open(sys.argv[2])))
    if len(sys.argv) > 3:
        html = add_fx_trend(html, json.load(open(sys.argv[3])))
    sys.stdout.write(html)
