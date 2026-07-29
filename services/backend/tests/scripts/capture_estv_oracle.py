"""ESTV oracle capture — points HORS-NŒUD, API JSON officielle (réveillé 2026-07-28).

Ce que fait ce script
---------------------
Collecte, pour les 26 chefs-lieux, des points d'impôt situés ENTRE les nœuds des
tables calibrées `CANTONAL_COMMUNAL_TAX_CHF` (revenu) et `CANTONAL_CAPITAL_TAX_CHF`
(capital, célibataire), afin de mesurer l'erreur d'INTERPOLATION vue par
l'utilisateur (les nœuds eux-mêmes sont déjà reproductibles à 0 écart).

Il produit / met à jour `services/backend/tests/fixtures/estv_oracle_2025.jsonl`
(schéma : `tests/fixtures/estv_oracle.SCHEMA.md`) consommé par
`tests/test_estv_oracle.py`.

Pourquoi l'API JSON (pas Playwright)
------------------------------------
Le simulateur ESTV expose la MÊME API JSON que son SPA
(`.../lg-proxy/operation/c3b67379_ESTV/API_calculateSimpleTaxes` pour le revenu,
`.../API_calculateManyCapitalTaxes` pour le capital). C'est l'endpoint qui a servi
à calibrer les tables committées et à collecter le capital marié. urllib (stdlib)
suffit — aucune dépendance Playwright. WebFetch ne marche pas (GET only) ; l'API
exige POST.

Porte d'intégrité 0-trust
-------------------------
Pour CHAQUE canton, AVANT d'émettre le moindre point hors-nœud, le script
reproduit les 5 nœuds committés (`cantonal_communal`) à ±1 CHF. Un canton qui ne
reproduit pas ses nœuds (profil/année/endpoint faux, ou barème ESTV changé) est
ABANDONNÉ — aucune donnée inventée. C'est la même méthode que la collecte capital
marié (`consolidated.json`).

Usage (depuis services/backend, cadence annuelle manuelle nov.-déc.) :
  python3 -m tests.scripts.capture_estv_oracle \
    --output tests/fixtures/estv_oracle_2025.jsonl
  python3 -m tests.scripts.capture_estv_oracle --dry-run   # capture sans écrire

Après capture, committer avec le préfixe dédié `fix(estv-oracle):` (cf. SCHEMA.md).
Si l'API ESTV est indisponible : le script signale l'échec par canton et n'écrit
RIEN d'inventé.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

# Fonctions + tables canoniques (étalon MINT). Ne JAMAIS ré-implémenter ici.
from app.services.fiscal.cantonal_comparator import (
    CANTONAL_CAPITAL_TAX_CHF,
    CANTONAL_COMMUNAL_TAX_CHF,
    estimate_capital_withdrawal_tax,
    estimate_income_tax_parts,
)

BASE = (
    "https://swisstaxcalculator.estv.admin.ch"
    "/delegate/ost-integration/v1/lg-proxy/operation/c3b67379_ESTV"
)
INCOME_URL = BASE + "/API_calculateSimpleTaxes"
CAPITAL_URL = BASE + "/API_calculateManyCapitalTaxes"
SOURCE_URL = "https://swisstaxcalculator.estv.admin.ch/#/calculator/income-wealth-tax"

HEADERS = {
    "User-Agent": "Mozilla/5.0 MINT-OracleCapture/1.0 (julien.battaglia@gmail.com)",
    "Content-Type": "application/json;charset=UTF-8",
    "Origin": "https://swisstaxcalculator.estv.admin.ch",
    "Referer": "https://swisstaxcalculator.estv.admin.ch/",
    "Accept": "application/json, text/plain, */*",
}

# TaxLocationID du chef-lieu par canton (résolus via API_searchLocation, écho
# Location vérifié à la collecte 2026-07-23 ; identiques à capital_tax_2026/).
TAX_LOCATION_ID: dict[str, int] = {
    "AG": 500000000, "AI": 905000000, "AR": 910000000, "BE": 300000000,
    "BL": 441000000, "BS": 400000000, "FR": 170000000, "GE": 120000000,
    "GL": 875000000, "GR": 700000000, "JU": 280000000, "LU": 600000000,
    "NE": 200000000, "NW": 637000000, "OW": 606000000, "SG": 900000000,
    "SH": 820000000, "SO": 450000000, "SZ": 643000000, "TG": 850000000,
    "TI": 650000000, "UR": 646000000, "VD": 100000000, "VS": 195000000,
    "ZG": 630000000, "ZH": 800000000,
}
CANTONS = list(TAX_LOCATION_ID)

# Grilles committées (nœuds) — pour la porte d'intégrité.
INCOME_NODES = [40_000, 70_000, 100_000, 150_000, 250_000]
CAPITAL_NODES = [100_000, 250_000, 500_000, 750_000, 1_000_000]

# Points HORS-NŒUD (ce que l'utilisateur voit interpolé).
INCOME_OFFNODE = [55_000, 85_000, 125_000, 175_000, 225_000, 300_000]
CAPITAL_OFFNODE = [175_000, 350_000, 620_000, 880_000]

# Année fiscale par canton. 2026 partout SAUF revenu SG/TI (ESTV n'a pas publié
# leur 2026 ; table committée = 2025). Capital : 2026 partout.
INCOME_YEAR = {c: 2026 for c in CANTONS}
INCOME_YEAR["SG"] = 2025
INCOME_YEAR["TI"] = 2025
CAPITAL_YEAR = {c: 2026 for c in CANTONS}

NODE_TOL_CHF = 1.0  # porte d'intégrité des nœuds committés


def _post(url: str, payload: dict[str, Any], retries: int = 3) -> dict[str, Any]:
    data = json.dumps(payload).encode("utf-8")
    last = ""
    for attempt in range(retries):
        try:
            req = urllib.request.Request(url, data=data, headers=HEADERS, method="POST")
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as exc:
            last = f"HTTP {exc.code}: {exc.read().decode('utf-8', 'replace')[:200]}"
        except Exception as exc:  # noqa: BLE001 — réseau : on veut tout capter proprement
            last = repr(exc)
        if attempt < retries - 1:
            time.sleep(1.5)
    return {"__error__": last}


def _income(canton: str, taxable: int, year: int) -> dict[str, Any] | None:
    payload = {
        "SimKey": None, "TaxYear": year, "TaxLocationID": TAX_LOCATION_ID[canton],
        "Relationship": 1, "Confession1": 4, "Children": [], "Confession2": 0,
        "TaxableIncomeCanton": taxable, "TaxableIncomeFed": taxable, "TaxableFortune": 0,
    }
    resp = _post(INCOME_URL, payload)
    if "__error__" in resp:
        return {"__error__": resp["__error__"]}
    r = resp["response"]
    cc = r["IncomeTaxCanton"] + r["IncomeTaxCity"] + r["PersonalTax"] + r["IncomeTaxChurch"]
    return {
        "cantonal_communal": float(cc),
        "ifd": float(r["IncomeTaxFed"]),
        "total": float(cc + r["IncomeTaxFed"]),
        "loc": r["Location"]["Canton"],
    }


def _capital(canton: str, amount: int, year: int) -> dict[str, Any] | None:
    payload = {
        "SimKey": None, "TaxYear": year, "TaxGroupID": TAX_LOCATION_ID[canton],
        "Relationship": 1, "Confession1": 4, "Confession2": 0,
        "NumberOfChildren": 0, "Gender": 1, "AgeAtPayment": 65, "Capital": amount,
    }
    resp = _post(CAPITAL_URL, payload)
    if "__error__" in resp:
        return {"__error__": resp["__error__"]}
    r = resp["response"][0]
    cc = r["TaxCanton"] + r["TaxCity"] + r["TaxChurch"]
    return {
        "cantonal_communal": float(cc),
        "ifd": float(r["TaxFed"]),
        "total": float(cc + r["TaxFed"]),
        "loc": r["Location"]["Canton"],
    }


def _rel(a: float, b: float) -> float:
    return abs(a - b) / b if b else 0.0


def _band(measured: float) -> float:
    """Tolérance juste au-dessus de l'erreur mesurée, arrondie à 0.5 %, plancher 2 %."""
    raw = max(0.02, measured * 1.20 + 0.003)
    return round(math.ceil(raw / 0.005) * 0.005, 4)


def _node_gate(canton: str, engine: str, sleep: float) -> tuple[bool, list[str]]:
    """Reproduit les 5 nœuds committés du canton à ±1 CHF. Renvoie (ok, détails)."""
    if engine == "income":
        nodes, committed, year, query = INCOME_NODES, CANTONAL_COMMUNAL_TAX_CHF[canton], INCOME_YEAR[canton], _income
    else:
        nodes, committed, year, query = CAPITAL_NODES, CANTONAL_CAPITAL_TAX_CHF[canton], CAPITAL_YEAR[canton], _capital
    ok = True
    detail = []
    for i, node in enumerate(nodes):
        est = query(canton, node, year)
        time.sleep(sleep)
        if est is None or "__error__" in est:
            ok = False
            detail.append(f"{node}:CAPTURE_FAIL({est.get('__error__') if est else 'none'})")
            continue
        diff = est["cantonal_communal"] - committed[i]
        if abs(diff) > NODE_TOL_CHF or est["loc"] != canton:
            ok = False
            detail.append(f"{node}:MISMATCH(estv={est['cantonal_communal']:.0f} vs {committed[i]} loc={est['loc']})")
        else:
            detail.append(f"{node}:ok")
    return ok, detail


def _income_note(segment: str, measured: float) -> str:
    if measured > 0.02:
        return (
            f"Erreur d'interpolation {measured * 100:.2f}% > 2% dans le segment "
            f"{segment} (courbure du bareme cantonal non captee par la grille "
            f"5 points). Finding oracle documente."
        )
    return ""


def _capital_note(segment: str, measured: float, cc_measured: float, over: bool) -> str:
    if measured > 0.02:
        return (
            f"Erreur d'interpolation totale {measured * 100:.2f}% > 2% (composante "
            f"cantonale {cc_measured * 100:.2f}%) dans le segment {segment} : le "
            f"bareme capital cantonal est fortement convexe entre noeuds, la grille "
            f"5 points + interpolation lineaire {'sur' if over else 'sous'}estime. "
            f"Finding oracle documente."
        )
    return ""


def capture(sleep: float) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    """Capture tous les points hors-nœud ; renvoie (vecteurs, rapport de porte)."""
    capture_date = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    vectors: list[dict[str, Any]] = []
    gate: dict[str, Any] = {}

    for canton in CANTONS:
        gate[canton] = {}
        # ---- REVENU ----
        year = INCOME_YEAR[canton]
        ok, detail = _node_gate(canton, "income", sleep)
        gate[canton]["income"] = {"year": year, "ok": ok, "detail": detail}
        if ok:
            for x in INCOME_OFFNODE:
                est = _income(canton, x, year)
                time.sleep(sleep)
                if est is None or "__error__" in est:
                    gate[canton]["income"].setdefault("offnode_fail", []).append(x)
                    continue
                ifd_mint, cc_mint = estimate_income_tax_parts(float(x), canton)
                measured = _rel(cc_mint, est["cantonal_communal"])
                seg = _income_segment(x)
                vectors.append({
                    "id": f"income__{canton}__{x}", "engine": "income", "canton": canton,
                    "marital_status": "single", "input_chf": x, "segment": seg,
                    "off_node": True, "tax_year": year,
                    "expected_cantonal_communal_chf": est["cantonal_communal"],
                    "expected_ifd_chf": est["ifd"], "expected_total_chf": est["total"],
                    "measured_rel_err": round(measured, 5), "tol_rel": _band(measured),
                    "tol_note": _income_note(seg, measured),
                    "expected_capture_date": capture_date, "source_url": SOURCE_URL,
                    "source_operation": "API_calculateSimpleTaxes",
                })

        # ---- CAPITAL (célibataire) ----
        year = CAPITAL_YEAR[canton]
        ok, detail = _node_gate(canton, "capital", sleep)
        gate[canton]["capital"] = {"year": year, "ok": ok, "detail": detail}
        if ok:
            for x in CAPITAL_OFFNODE:
                est = _capital(canton, x, year)
                time.sleep(sleep)
                if est is None or "__error__" in est:
                    gate[canton]["capital"].setdefault("offnode_fail", []).append(x)
                    continue
                total_mint = estimate_capital_withdrawal_tax(float(x), canton, is_married=False)
                measured = _rel(total_mint, est["total"])
                cc_measured = _rel(total_mint - est["ifd"], est["cantonal_communal"])
                seg = _capital_segment(x)
                vectors.append({
                    "id": f"capital__{canton}__{x}", "engine": "capital", "canton": canton,
                    "marital_status": "single", "input_chf": x, "segment": seg,
                    "off_node": True, "tax_year": year,
                    "expected_cantonal_communal_chf": est["cantonal_communal"],
                    "expected_ifd_chf": est["ifd"], "expected_total_chf": est["total"],
                    "measured_rel_err": round(measured, 5),
                    "measured_rel_err_cantonal": round(cc_measured, 5),
                    "tol_rel": _band(measured),
                    "tol_note": _capital_note(seg, measured, cc_measured, total_mint > est["total"]),
                    "expected_capture_date": capture_date, "source_url": SOURCE_URL,
                    "source_operation": "API_calculateManyCapitalTaxes",
                })
        print(
            f"{canton}: income_gate={gate[canton]['income']['ok']} "
            f"capital_gate={gate[canton]['capital']['ok']}",
            file=sys.stderr,
        )
    return vectors, gate


def _income_segment(x: int) -> str:
    if x < INCOME_NODES[0]:
        return "extrap-low(<40k)"
    if x > INCOME_NODES[-1]:
        return "extrap-high(>250k)"
    for i in range(len(INCOME_NODES) - 1):
        if INCOME_NODES[i] <= x <= INCOME_NODES[i + 1]:
            return f"{INCOME_NODES[i] // 1000}k-{INCOME_NODES[i + 1] // 1000}k"
    return "?"


def _capital_segment(x: int) -> str:
    if x > CAPITAL_NODES[-1]:
        return "extrap-high(>1M)"
    for i in range(len(CAPITAL_NODES) - 1):
        if CAPITAL_NODES[i] <= x <= CAPITAL_NODES[i + 1]:
            return f"{CAPITAL_NODES[i] // 1000}k-{CAPITAL_NODES[i + 1] // 1000}k"
    return "?"


def _write_jsonl(path: Path, vectors: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "".join(json.dumps(v, ensure_ascii=True) + "\n" for v in vectors),
        encoding="utf-8",
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="ESTV oracle off-node capture (manual annual).")
    parser.add_argument(
        "--output", type=Path,
        default=Path("services/backend/tests/fixtures/estv_oracle_2025.jsonl"),
    )
    parser.add_argument("--sleep", type=float, default=0.3, help="Pause entre requêtes ESTV (politesse).")
    parser.add_argument("--dry-run", action="store_true", help="Capture + rapport, sans écrire le JSONL.")
    parser.add_argument(
        "--allow-partial", action="store_true",
        help="Autorise l'écriture d'une capture incomplète (défaut : refus — "
        "une panne transitoire ne doit pas réduire silencieusement la "
        "couverture de l'oracle, revue Codex).",
    )
    args = parser.parse_args()

    vectors, gate = capture(args.sleep)

    gated_out = [c for c in CANTONS if not (gate[c]["income"]["ok"] and gate[c]["capital"]["ok"])]
    if gated_out:
        print(
            f"[capture] ATTENTION — {len(gated_out)} canton(s) hors porte d'intégrité "
            f"(nœuds non reproduits, aucun point émis) : {gated_out}",
            file=sys.stderr,
        )
        for c in gated_out:
            print(f"  {c} income={gate[c]['income']['detail']} capital={gate[c]['capital']['detail']}", file=sys.stderr)

    if not vectors:
        print(
            "[capture] ÉCHEC — 0 vecteur capturé (API ESTV indisponible ou tous les "
            "cantons hors porte). Rien écrit. Ré-essayer plus tard.",
            file=sys.stderr,
        )
        return 2

    inc = sum(1 for v in vectors if v["engine"] == "income")
    cap = sum(1 for v in vectors if v["engine"] == "capital")
    over = sum(1 for v in vectors if v["measured_rel_err"] > 0.02)
    print(
        f"[capture] {len(vectors)} vecteurs ({inc} revenu + {cap} capital), "
        f"{over} avec erreur d'interpolation > 2% (documentés dans tol_note), "
        f"{26 - len(gated_out)}/26 cantons dans la porte.",
        file=sys.stderr,
    )

    if args.dry_run:
        print("[capture] --dry-run : rien écrit.", file=sys.stderr)
        return 0

    # Matrice attendue complète : toute capture partielle est REFUSÉE par
    # défaut — les tests ne paramètrent que les vecteurs présents, donc une
    # fixture partielle réduirait la couverture en silence jusqu'au refresh
    # suivant (revue Codex P1).
    attendu = len(CANTONS) * (len(INCOME_OFFNODE) + len(CAPITAL_OFFNODE))
    if len(vectors) != attendu and not args.allow_partial:
        print(
            f"[capture] REFUS d'écrire : {len(vectors)}/{attendu} vecteurs "
            "capturés (échecs hors-nœud ou cantons hors porte). Relance, ou "
            "force en connaissance de cause avec --allow-partial.",
            file=sys.stderr,
        )
        return 1

    _write_jsonl(args.output, vectors)
    print(f"[capture] écrit {len(vectors)} vecteurs -> {args.output}", file=sys.stderr)
    print("[capture] committer avec le préfixe 'fix(estv-oracle):' (cf. SCHEMA.md).", file=sys.stderr)
    return 0


if __name__ == "__main__":
    sys.exit(main())
