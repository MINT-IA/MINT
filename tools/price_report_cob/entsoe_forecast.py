#!/usr/bin/env python3
"""Prévisions ENTSO-E pour la ligne « Prévu aujourd'hui » du Price Report COB.

Récupère sur la Transparency Platform (web-api.tp.entsoe.eu), pour le jour de
livraison courant :
  - éolien + solaire DE prévu (A69, day-ahead A01, somme B16+B18+B19) ;
  - charge DE prévue (A65, day-ahead A01) ;
  - charge CH prévue (A65, day-ahead A01) — optionnelle, échec non bloquant.

Chaque série est moyennée sur la journée et rendue en GW (1 décimale).
La dispo nucléaire FR (agrégation des indisponibilités A80/A77, documents
zippés par unité) n'est pas encore implémentée — voir README §5.

Le jeton est lu dans la variable d'environnement ENTSOE_TOKEN — il ne doit
JAMAIS apparaître dans le code ni dans git. Day-ahead publié la veille vers
18h, donc toujours disponible au run de 05h40.

Usage : ENTSOE_TOKEN=... entsoe_forecast.py [AAAA-MM-JJ]   (défaut : aujourd'hui UTC)
Sortie : une ligne texte prête pour le rapport + un JSON sur stderr.
"""
import datetime as dt
import json
import os
import sys
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

API = "https://web-api.tp.entsoe.eu/api"
ZONES = {"DE": "10Y1001A1001A82H", "CH": "10YCH-SWISSGRIDZ"}


def fetch(token: str, **params) -> ET.Element:
    query = urllib.parse.urlencode({"securityToken": token, **params})
    with urllib.request.urlopen(f"{API}?{query}", timeout=60) as resp:
        body = resp.read()
    root = ET.fromstring(body)
    if root.tag.endswith("Acknowledgement_MarketDocument"):
        reason = root.findtext(".//{*}Reason/{*}text") or "raison inconnue"
        raise RuntimeError(f"ENTSO-E refuse la requête : {reason}")
    return root


RESOLUTIONS_MIN = {"PT15M": 15, "PT30M": 30, "PT60M": 60, "P1D": 1440}


def _expand_period(period: ET.Element, ns: dict) -> list:
    """Développe un Period en liste de valeurs par pas de temps.

    ENTSO-E livre du curveType A03 : un point dont la valeur répète celle du
    point précédent est OMIS. Moyenner les points bruts surpondère donc les
    heures qui varient (le solaire compresse ses zéros nocturnes). On
    reconstruit la grille complète start→end à la résolution donnée, en
    propageant chaque valeur jusqu'au point suivant (et jusqu'à la fin).
    """
    start = dt.datetime.fromisoformat(period.findtext(".//g:start", namespaces=ns).replace("Z", "+00:00"))
    end = dt.datetime.fromisoformat(period.findtext(".//g:end", namespaces=ns).replace("Z", "+00:00"))
    step = RESOLUTIONS_MIN[period.findtext("g:resolution", namespaces=ns)]
    n = int((end - start).total_seconds() // 60) // step
    points = sorted(
        (int(p.findtext("g:position", namespaces=ns)), float(p.findtext("g:quantity", namespaces=ns)))
        for p in period.findall("g:Point", ns)
    )
    grid, value, i = [], 0.0, 0
    for slot in range(1, n + 1):
        if i < len(points) and points[i][0] == slot:
            value = points[i][1]
            i += 1
        grid.append(value)
    return grid


def daily_avg_mw(doc: ET.Element) -> float:
    """Moyenne journalière du document, en MW.

    Les séries A69 sont par filière (B16 solaire, B18/B19 éolien) : les
    moyennes par série s'ADDITIONNENT. Pour A65 il n'y a qu'une série.
    """
    ns = {"g": doc.tag.split("}")[0][1:]}
    total = 0.0
    for ts in doc.findall("g:TimeSeries", ns):
        slots = []
        for period in ts.findall(".//g:Period", ns):
            slots += _expand_period(period, ns)
        if slots:
            total += sum(slots) / len(slots)
    if total == 0.0:
        raise RuntimeError("document sans points de mesure")
    return total


def forecasts(token: str, day: dt.date) -> dict:
    start = day.strftime("%Y%m%d0000")
    end = (day + dt.timedelta(days=1)).strftime("%Y%m%d0000")
    out = {"date": day.isoformat()}
    out["eolien_solaire_de_gw"] = round(daily_avg_mw(fetch(
        token, documentType="A69", processType="A01",
        in_Domain=ZONES["DE"], periodStart=start, periodEnd=end)) / 1000, 1)
    out["charge_de_gw"] = round(daily_avg_mw(fetch(
        token, documentType="A65", processType="A01",
        outBiddingZone_Domain=ZONES["DE"], periodStart=start, periodEnd=end)) / 1000, 1)
    try:
        out["charge_ch_gw"] = round(daily_avg_mw(fetch(
            token, documentType="A65", processType="A01",
            outBiddingZone_Domain=ZONES["CH"], periodStart=start, periodEnd=end)) / 1000, 1)
    except Exception as e:
        out["charge_ch_gw"] = None
        out["charge_ch_erreur"] = str(e)
    return out


def fr(v: float) -> str:
    return f"{v:.1f}".replace(".", ",")


if __name__ == "__main__":
    token = os.environ.get("ENTSOE_TOKEN")
    if not token:
        sys.exit("ENTSOE_TOKEN absent de l'environnement")
    day = dt.date.fromisoformat(sys.argv[1]) if len(sys.argv) > 1 else dt.datetime.now(dt.timezone.utc).date()
    data = forecasts(token, day)
    ligne = (f"Prévu aujourd'hui (ENTSO-E) : éolien + solaire DE {fr(data['eolien_solaire_de_gw'])} GW"
             f" · charge DE {fr(data['charge_de_gw'])} GW")
    if data.get("charge_ch_gw"):
        ligne += f" · charge CH {fr(data['charge_ch_gw'])} GW"
    print(ligne)
    print(json.dumps(data, ensure_ascii=False), file=sys.stderr)
