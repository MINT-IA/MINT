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
REDUCTION_URL = "https://www.vd.ch/etat-droit-finances/impots/impots-pour-les-individus/payer-mes-impots"
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

def calculator_version(page: str) -> str:
    match=re.search(r"version\s+(\d+(?:\.\d+)+)",page,re.I)
    if not match: raise ValueError("official calculator version missing")
    return match.group(1)

def validate_echo(page: str, income: str) -> None:
    if not re.search(r'id="periode_2026" value="2026" selected="selected"', page): raise ValueError("tax-year echo changed")
    if not re.search(r'id="commune3260" value="lausanne" selected="selected" data-periode="2026"[^>]*>Lausanne</option>', page): raise ValueError("commune echo changed")
    if not re.search(r'id="etatCivil1" value="1" selected="selected"[^>]*>Personne seule</option>', page): raise ValueError("civil-status echo changed")
    for field, expected_value in (("revenuImposableICC",income),("fortuneImposableICC","0"),("revenuImposableIFD",income)):
        if not re.search(rf'name="{re.escape(PFX+"["+field+"]")}" value="{expected_value}"', page): raise ValueError(f"{field} echo changed")
    for field in ("noEnfants","noEnfantsDemiQuotient","noEnfantsMenage"):
        select=re.search(rf'<select[^>]+name="{re.escape(PFX+"["+field+"]")}"[^>]*>(.*?)</select>',page,re.S)
        if not select or not re.search(r'<option[^>]+value="0" selected="selected"',select.group(1)): raise ValueError(f"{field} echo changed")

def replay(receipt: dict) -> dict:
    get = urllib.request.Request(URL, headers={"User-Agent":"MINT-evidence-verifier/1.0"})
    page = urllib.request.urlopen(get, timeout=30).read().decode("utf-8", "replace")
    if calculator_version(page) != receipt["calculator_version"]: raise ValueError("official calculator version changed")
    option = re.search(r'<option id="commune3260" value="lausanne" data-periode="2026"[^>]*>Lausanne</option>', page)
    if not option: raise ValueError("official Lausanne 2026 option identity changed")
    captures = {}
    for name, income in (("baseline","80000"),("counterfactual","72742")):
        pairs=[(f"{PFX}[calculICC]","on"),(f"{PFX}[calculIFD]","on"),(f"{PFX}[periode]","2026"),(f"{PFX}[commune]","lausanne"),(f"{PFX}[etatCivil]","1"),(f"{PFX}[noEnfants]","0"),(f"{PFX}[noEnfantsDemiQuotient]","0"),(f"{PFX}[noEnfantsMenage]","0"),(f"{PFX}[revenuImposableICC]",income),(f"{PFX}[fortuneImposableICC]","0"),(f"{PFX}[revenuImposableIFD]",income),(f"{PFX}[afficher]","Afficher le résultat")]
        req=urllib.request.Request(URL, urllib.parse.urlencode(pairs).encode(), {"User-Agent":"MINT-evidence-verifier/1.0"}, method="POST")
        response=urllib.request.urlopen(req, timeout=30).read().decode("utf-8", "replace")
        validate_echo(response,income)
        expected=receipt["captures"][name].copy()
        actual={k:value(response,s) for k,s in IDS.items()}
        for k in actual:
            if Decimal(actual[k]) != Decimal(expected[k]): raise ValueError(f"{name}.{k}: live {actual[k]} != receipt {expected[k]}")
        captures[name]=actual
    reduction=urllib.request.urlopen(urllib.request.Request(REDUCTION_URL,headers={"User-Agent":"MINT-evidence-verifier/1.0"}),timeout=30).read().decode("utf-8","replace")
    plain=re.sub(r"\s+"," ",re.sub(r"<[^>]+>"," ",html.unescape(reduction)))
    claim="Pour l’année 2026, une réduction de 5% de l’impôt cantonal sur le revenu des personnes physiques a été adoptée."
    if claim not in plain: raise ValueError("official 2026 cantonal-reduction claim changed")
    return captures

def main() -> int:
    ap=argparse.ArgumentParser(); ap.add_argument("--live",action="store_true"); ap.add_argument("--self-test",action="store_true"); args=ap.parse_args()
    raw=RECEIPT.read_bytes()
    if hashlib.sha256(raw).hexdigest()!=SHA256: raise SystemExit("receipt SHA-256 mismatch")
    receipt=json.loads(raw)
    canonical=(json.dumps(receipt,ensure_ascii=False,sort_keys=True,separators=(",",":"))+"\n").encode()
    if canonical!=raw: raise SystemExit("receipt is not canonical sorted JSON")
    if args.self_test:
        sample='version 10.4.0 <option id="periode_2026" value="2026" selected="selected">2026</option><option id="commune3260" value="lausanne" selected="selected" data-periode="2026">Lausanne</option><option id="etatCivil1" value="1" selected="selected">Personne seule</option>'
        sample+=''.join(f'<input name="{PFX}[{field}]" value="{val}">' for field,val in (("revenuImposableICC","80000"),("fortuneImposableICC","0"),("revenuImposableIFD","80000")))
        sample+=''.join(f'<select name="{PFX}[{field}]"><option value="0" selected="selected">0</option></select>' for field in ("noEnfants","noEnfantsDemiQuotient","noEnfantsMenage"))
        validate_echo(sample,"80000")
        if calculator_version(sample)!="10.4.0": raise SystemExit("version parser self-test failed")
        try: validate_echo(sample.replace('value="lausanne"','value="nyon"'),"80000")
        except ValueError: pass
        else: raise SystemExit("echo negative self-test failed")
    if args.live: replay(receipt)
    print("OK normalized VD receipt" + (" and manual live replay" if args.live else " (offline)"))
    return 0
if __name__ == "__main__": raise SystemExit(main())
