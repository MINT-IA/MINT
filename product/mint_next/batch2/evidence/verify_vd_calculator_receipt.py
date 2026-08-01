#!/usr/bin/env python3
"""Verify the committed normalized receipt; optionally replay the public VD form.

Network replay is manual evidence collection only. It is not a supported API,
not a CI dependency, and must never be used by product runtime.
"""
from __future__ import annotations
import argparse, hashlib, html, json, re, urllib.parse, urllib.request
from decimal import Decimal
from pathlib import Path

URL = "https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/calculer-mes-impots"
RECEIPT = Path(__file__).with_name("vd-calculator-normalized-receipt-20260801.json")
SHA256 = "5ed976cb07688a6d08cba29f96e9c2a451fb3546f5daf6cc5fe58a4348832293"
PFX = "tx_vdsqlicalculetteaci_pi1"
IDS = {
 "family_share":"res_part_familiale", "taxable_income_displayed_chf":"res_revenu_montant_imp",
 "icc_base_chf":"res_revenu_impot_base", "cantonal_coefficient":"res_revenu_coef_cant",
 "cantonal_charge_chf":"res_revenu_cf_cant", "municipal_coefficient":"res_revenu_coef_comm",
 "municipal_charge_chf":"res_revenu_cf_comm", "icc_total_chf":"res_total_icc",
 "ifd_base_chf":"res_revenu_base_ifd", "ifd_total_chf":"res_total_ifd", "total_chf":"res_total_icc_ifd",
}

def value(page: str, suffix: str) -> str:
    tag = re.search(rf'<[^>]+id=["\']{re.escape(PFX+"_"+suffix)}["\'][^>]*>', page)
    if not tag: raise ValueError(f"missing official output {suffix}")
    raw = re.search(r'value="([^"]*)"', tag.group())
    if not raw: raise ValueError(f"missing value for {suffix}")
    cleaned = html.unescape(raw.group(1)).replace("’", "").replace("'", "").replace(" ", "")
    return format(Decimal(cleaned), "f")

def replay(receipt: dict) -> dict:
    get = urllib.request.Request(URL, headers={"User-Agent":"MINT-evidence-verifier/1.0"})
    page = urllib.request.urlopen(get, timeout=30).read().decode("utf-8", "replace")
    option = re.search(r'<option id="commune3260" value="lausanne" data-periode="2026"[^>]*>Lausanne</option>', page)
    if not option: raise ValueError("official Lausanne 2026 option identity changed")
    captures = {}
    for name, income in (("baseline","80000"),("counterfactual","72742")):
        pairs=[(f"{PFX}[calculICC]","on"),(f"{PFX}[calculIFD]","on"),(f"{PFX}[periode]","2026"),(f"{PFX}[commune]","lausanne"),(f"{PFX}[etatCivil]","1"),(f"{PFX}[noEnfants]","0"),(f"{PFX}[noEnfantsDemiQuotient]","0"),(f"{PFX}[noEnfantsMenage]","0"),(f"{PFX}[revenuImposableICC]",income),(f"{PFX}[fortuneImposableICC]","0"),(f"{PFX}[revenuImposableIFD]",income),(f"{PFX}[afficher]","Afficher le résultat")]
        req=urllib.request.Request(URL, urllib.parse.urlencode(pairs).encode(), {"User-Agent":"MINT-evidence-verifier/1.0"}, method="POST")
        response=urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
        expected=receipt["captures"][name].copy()
        actual={k:value(response,s) for k,s in IDS.items()}
        for k in actual:
            if Decimal(actual[k]) != Decimal(expected[k]): raise ValueError(f"{name}.{k}: live {actual[k]} != receipt {expected[k]}")
        captures[name]=actual
    return captures

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("--live",action="store_true"); args=ap.parse_args()
    raw=RECEIPT.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=SHA256: raise SystemExit("receipt SHA-256 mismatch")
    receipt=json.loads(raw)
    canonical=(json.dumps(receipt,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode()
    if canonical!=raw: raise SystemExit("receipt is not canonical sorted JSON")
    if args.live: replay(receipt)
    print("OK normalized VD receipt" + (" and manual live replay" if args.live else " (offline)"))
    return 0
if __name__ == "__main__": raise SystemExit(main())
