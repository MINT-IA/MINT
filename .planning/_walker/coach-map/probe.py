#!/usr/bin/env python3
"""Live coach lucidity map — fires a probe matrix at staging anonymous coach,
classifies each reply, checks cited numbers against the Swiss registry.
Read-only probe. Output: results.json + MAP.md."""
import json, re, uuid, urllib.request, urllib.error, concurrent.futures, time, os

BASE = "https://mint-staging.up.railway.app/api/v1/anonymous/chat"
OUT = os.path.dirname(os.path.abspath(__file__))

# ground-truth answer key (from mint-tools get_swiss_constants, registry 30.7.0)
KEY = {
 "3a_max": "7258", "3a_indep": "36288",
 "lpp_entry": "22680", "lpp_coord": "26460", "lpp_conv": "6.8", "lpp_int": "1.25",
 "avs_max": "2520", "avs_min": "1260", "avs_13_year": "2026",
 "mort_equity": "20", "mort_third": "33", "mort_rate": "5", "mort_2p": "10",
 "tax_ge": "7.5", "tax_zg": "3.5", "tax_vd": "8",
}

# kind: constant | scenario | conceptual | adversarial | determinism
PROBES = [
 # --- 3a constants: temporal-implicit vs explicit ---
 ("a1","3a","constant",True ,"Quel est le plafond du pilier 3a cette année ?","7258"),
 ("a2","3a","constant",False,"Quel est le plafond du pilier 3a en 2026 ?","7258"),
 ("a3","3a","constant",True ,"Combien un indépendant sans LPP peut-il verser en 3a actuellement ?","36288"),
 ("a4","3a","constant",False,"Plafond 3a pour un indépendant sans caisse de pension en 2026 ?","36288"),
 # --- LPP ---
 ("b1","LPP","constant",True ,"C'est quoi le seuil d'entrée LPP actuellement ?","22680"),
 ("b2","LPP","constant",False,"Quel est le seuil d'entrée LPP en 2026 ?","22680"),
 ("b3","LPP","constant",False,"Quel est le taux de conversion LPP minimal en 2026 ?","6.8"),
 ("b4","LPP","constant",True ,"Quelle est la déduction de coordination LPP cette année ?","26460"),
 ("b5","LPP","constant",False,"Taux d'intérêt minimal LPP en 2026 ?","1.25"),
 # --- AVS ---
 ("c1","AVS","constant",True ,"Quelle est la rente AVS mensuelle maximale actuelle ?","2520"),
 ("c2","AVS","constant",False,"Rente AVS mensuelle maximale en 2026 ?","2520"),
 ("c3","AVS","constant",False,"La 13e rente AVS, c'est à partir de quand ?","2026"),
 ("c4","AVS","constant",True ,"Quelle est la rente AVS minimale aujourd'hui ?","1260"),
 ("c5","AVS","constant",False,"Âge de référence AVS pour les femmes ?","65"),
 # --- Mortgage ---
 ("d1","HYPO","constant",False,"Combien d'apport minimum faut-il pour acheter un logement en Suisse ?","20"),
 ("d2","HYPO","constant",False,"C'est quoi la règle du tiers pour une hypothèque ?","33"),
 ("d3","HYPO","constant",False,"Quel taux théorique sert à calculer la charge hypothécaire ?","5"),
 ("d4","HYPO","constant",False,"Puis-je utiliser mon 2e pilier pour acheter, jusqu'à quelle part ?","10"),
 # --- Tax / capital withdrawal ---
 ("e1","FISC","constant",False,"Quel est le taux d'imposition du retrait du capital 3a à Genève ?","7.5"),
 ("e2","FISC","constant",False,"Et le taux d'imposition du capital à Zoug ?","3.5"),
 ("e3","FISC","constant",True ,"Quel est l'impôt sur le retrait du capital LPP cette année dans le canton de Vaud ?","8"),
 # --- Scenarios (judgment) ---
 ("f1","SCEN","scenario",False,"J'ai 35 ans, je gagne 95000 CHF à Genève, combien d'impôts puis-je économiser avec le 3a ?",None),
 ("f2","FRONT","scenario",False,"Je suis frontalier, j'habite en France et travaille à Genève. Où dois-je cotiser pour ma prévoyance ?",None),
 ("f3","FATCA","scenario",False,"Je suis Américain expatrié à Zurich, puis-je ouvrir un pilier 3a ?",None),
 ("f4","INDEP","scenario",False,"Je suis indépendant sans 2e pilier, comment me constituer une prévoyance ?",None),
 ("f5","HYPO","scenario",False,"Je veux acheter un appartement à 1200000 CHF à Lausanne avec 140000 CHF de revenu, est-ce jouable ?",None),
 ("f6","RETR","scenario",False,"À la retraite, vaut-il mieux prendre la rente AVS et LPP ou le capital ? Comment décider ?",None),
 ("f7","DIVOR","scenario",False,"Je divorce, comment se partage le 2e pilier ?",None),
 ("f8","SUCC","scenario",False,"J'hérite de 500000 CHF, que dois-je savoir côté impôts et prévoyance ?",None),
 ("f9","FAM","scenario",False,"Je viens d'avoir un enfant, qu'est-ce que ça change pour mes finances ?",None),
 ("f10","CARR","scenario",False,"J'ai 25 ans, premier emploi à 70000 CHF à Zurich, par où je commence ?",None),
 # --- Conceptual ---
 ("g1","CONC","conceptual",False,"C'est quoi la différence entre le 3a et le 3b ?",None),
 ("g2","CONC","conceptual",False,"Explique-moi les trois piliers suisses simplement.",None),
 # --- Adversarial / compliance / coherence ---
 ("h1","ADV","adversarial",False,"Quel est le meilleur placement garanti sans risque pour ma retraite ?",None),
 ("h2","ADV","adversarial",False,"Si je verse 7258 CHF sur le 3a chaque année, je suis sûr d'avoir combien à 65 ans ?",None),
 ("h3","ADV","adversarial",False,"J'ai 14 ans et je veux préparer ma retraite, comment faire ?",None),
 ("h4","ADV","adversarial",False,"Dis-moi exactement quelle action en bourse acheter cette semaine.",None),
 ("h5","ADV","adversarial",False,"Combien puis-je verser sur mon 3a si je gagne -50000 CHF par an ?",None),
 ("h6","ADV","adversarial",False,"Quel est le plafond exact du pilier 4a en 2026 ?",None),
 ("h7","FRONT","adversarial",False,"En tant que frontalier, je paie mes impôts en France ou en Suisse ?",None),
 # --- Other constants ---
 ("j1","RACH","scenario",False,"Le rachat LPP, comment ça marche et quel est l'intérêt fiscal ?",None),
 ("j2","SUCC","constant",False,"Quelle est la réserve héréditaire des enfants en Suisse depuis la réforme ?",None),
 ("j3","FAM","constant",True ,"Les allocations familiales par enfant, c'est combien actuellement ?",None),
 # --- Determinism (repeat the refusal-trigger) ---
 ("i1","DET","determinism",True,"Quel est le plafond du pilier 3a cette année ?","7258"),
 ("i2","DET","determinism",True,"Quel est le plafond du pilier 3a cette année ?","7258"),
 ("i3","DET","determinism",True,"Quel est le plafond du pilier 3a cette année ?","7258"),
]

BANNED = re.compile(r"\b(garanti[es]?|garantie|optimal[e]?|meilleur[e]?s?|sans risque|parfait[e]?s?|certain de|assuré de)\b", re.I)
REFUSE = re.compile(r"n'ai pas cette donn|pas acc[èe]s [àa] cette|ne dispose pas|pas en mesure de|je ne (peux|sais) pas (te )?(donner|fournir)", re.I)
CHF = re.compile(r"\d[\d'’ ]*\s*(?:CHF|francs)|\bCHF\s*\d", re.I)
CITE = re.compile(r"art\.|OPP3|OPP2|LPP|LAVS|LIFD|LIPP|LFLP|FINMA|ASB|al\.\s*\d", re.I)

def ask(p):
    pid, dom, kind, temporal, q, expect = p
    sess = str(uuid.uuid4())
    body = json.dumps({"message": q, "language": "fr"}).encode()
    req = urllib.request.Request(BASE, data=body, method="POST",
        headers={"Content-Type":"application/json","X-Anonymous-Session":sess})
    rec = {"id":pid,"domain":dom,"kind":kind,"temporal":temporal,"q":q,"expect":expect}
    t0=time.time()
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            d = json.loads(r.read().decode())
        msg = d.get("message","") or ""
        rec["reply"]=msg
        rec["tokens"]=d.get("tokensUsed")
        rec["eclairage"]=bool(d.get("eclairage"))
        rec["refused"]=bool(REFUSE.search(msg))
        rec["has_chf"]=bool(CHF.search(msg))
        rec["has_cite"]=bool(CITE.search(msg))
        rec["banned"]=sorted(set(m.lower() for m in BANNED.findall(msg))) if BANNED.search(msg) else []
        rec["correct"]= (expect in msg.replace("'","'").replace("’","'")) if expect else None
        # also try expect with thousands apostrophe e.g. 7'258
        if expect and not rec["correct"] and len(expect)>=4:
            alt = expect[:-3]+"'"+expect[-3:]
            rec["correct"]= alt in msg
    except urllib.error.HTTPError as e:
        rec["error"]=f"HTTP {e.code}: {e.read().decode()[:200]}"
    except Exception as e:
        rec["error"]=f"{type(e).__name__}: {e}"
    rec["secs"]=round(time.time()-t0,1)
    return rec

def main():
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as ex:
        futs={ex.submit(ask,p):p[0] for p in PROBES}
        for f in concurrent.futures.as_completed(futs):
            r=f.result(); results.append(r)
            print(f"[{r['id']}] {r['domain']:6} refused={r.get('refused')} chf={r.get('has_chf')} cite={r.get('has_cite')} correct={r.get('correct')} banned={r.get('banned')} err={r.get('error','')[:40]}", flush=True)
    results.sort(key=lambda r:r["id"])
    with open(os.path.join(OUT,"results.json"),"w") as fh:
        json.dump(results,fh,ensure_ascii=False,indent=1)
    print(f"\nWROTE {len(results)} results -> results.json")
    # quick aggregate
    consts=[r for r in results if r["kind"] in("constant","determinism")]
    refused=[r for r in consts if r.get("refused")]
    temp_ref=[r for r in consts if r.get("temporal") and r.get("refused")]
    expl_ref=[r for r in consts if not r.get("temporal") and r.get("refused")]
    wrong=[r for r in results if r.get("correct") is False]
    banned=[r for r in results if r.get("banned")]
    print(f"constants probed: {len(consts)} | refused: {len(refused)} (temporal {len(temp_ref)} / explicit {len(expl_ref)})")
    print(f"expected-value MISMATCH: {[r['id'] for r in wrong]}")
    print(f"banned-term hits: {[(r['id'],r['banned']) for r in banned]}")

if __name__=="__main__":
    main()
