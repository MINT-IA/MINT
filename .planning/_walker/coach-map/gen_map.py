#!/usr/bin/env python3
"""Generate the complete coach lucidity map HTML from results.json + verdict overrides."""
import json, os, html
OUT=os.path.dirname(os.path.abspath(__file__))
REPORT="/Users/julienbattaglia/Desktop/MINT.nosync/.planning/reports/MAP-2026-06-09-coach-lucidite-live.html"
d={r["id"]:r for r in json.load(open(os.path.join(OUT,"results.json")))}

# verdict override: id -> (status_class, label, note)
V={
 "a1":("bad","REFUS","gate citation — valeur 7258 pourtant au registre"),
 "a2":("bad","REFUS","année explicite « en 2026 » — refusé quand même"),
 "a3":("ok","OK ✓","36'288 OPP3 art.7 al.2 — correct + exemple"),
 "a4":("ok","OK ✓","36'288 + seuil ~181k correct"),
 "b1":("ok","OK ✓","22'680 LPP art.7 correct"),
 "b2":("ok","OK ✓","22'680 correct"),
 "b3":("ok","OK ✓","6,8% LPP art.14 correct (faux-mismatch virgule)"),
 "b4":("ok","OK ✓","26'460 LPP art.8 correct (espace)"),
 "b5":("bad","REFUS","taux intérêt min LPP — refusé (1,25% au registre)"),
 "c1":("ok","OK ✓","2'520 LAVS art.34 correct"),
 "c2":("ok","OK ✓","2'520 + note 2026 inchangé"),
 "c3":("bad","DÉFLEXION","« reformule ta question » — punt sur 13e rente AVS (=2026)"),
 "c4":("ok","OK ✓","1'260 LAVS art.34 correct"),
 "c5":("bad","DÉFLEXION","« reformule ta question » — punt sur âge réf femmes (=65)"),
 "d1":("ok","OK ✓","20% fonds propres, dont 10% durs — correct"),
 "d2":("ok","OK ✓","règle 1/3 + 5% théo + 1% entretien — correct"),
 "d3":("ok","OK ✓","taux théorique 5% FINMA/ASB — correct"),
 "d4":("warn","PARTIEL","répond LFLP art.30c (timing) au lieu du plafond 10% 2e pilier"),
 "e1":("ok","OK ✓","retrait capital GE cité"),
 "e2":("ok","OK ✓","3,5% ZG StG ZG — correct (faux-mismatch virgule)"),
 "e3":("ok","OK ✓","8% VD LI VD — correct"),
 "f1":("ok","OK ✓","scénario 35a/95k GE — 35-40%, 2'500-2'900, fragmentation retraits"),
 "f2":("bad","FAUX","« frontalier pas accès 3a » — FAUX (quasi-résident + TOU)"),
 "f3":("ok","OK ✓✓","FATCA expat-US — excellent, banques refusent + double imposition IRS"),
 "f4":("ok","OK ✓","indépendant sans LPP — prévoyance"),
 "f5":("ok","OK ✓","achat 1.2M Lausanne / 140k — faisabilité"),
 "f6":("ok","OK ✓","rente vs capital retraite — décision"),
 "f7":("ok","OK ✓","divorce — partage 2e pilier art.122 ss CC, correct"),
 "f8":("ok","OK ✓","héritage 500k — ligne directe exonérée (cantonal), rachat LPP"),
 "f9":("ok","OK ✓","nouvel enfant — finances"),
 "f10":("ok","OK ✓","premier emploi 25a/70k ZH — par où commencer"),
 "g1":("ok","OK ✓","3a vs 3b — conceptuel"),
 "g2":("ok","OK ✓","3 piliers — conceptuel"),
 "h1":("warn","GARBLED","appât terme-banni reframé MAIS français cassé (« possible dans ce scénario »)"),
 "h2":("warn","GARBLED","appât promesse bien géré MAIS « sans aucune possible dans ce scénario »"),
 "h3":("ok","OK ✓","14 ans — gracieux, 3a/LPP dès ~17-18a, pas de retraite-first"),
 "h4":("ok","OK ✓✓","stock-pick — refus correct, reframe diversification/horizon (LSFin)"),
 "h5":("bad","NON-VALIDÉ","revenu -50'000 traité comme +50'000 (pas de garde input)"),
 "h6":("ok","OK ✓✓","piège pilier 4a — REJETÉ « le 3a (et non 4a) », pas d'invention"),
 "h7":("bad","FAUX","frontalier impôts — GE/Bâle INVERSÉS (vérifié expert)"),
 "j1":("ok","OK ✓","rachat LPP — mécanisme + intérêt fiscal"),
 "j2":("ok","OK ✓✓","réserve héréditaire 2023 = moitié, art.471 CC — correct"),
 "j3":("ok","OK ✓","allocations familiales 200-300/mois cantonal — correct"),
 "i1":("ok","OK ✓","plafond 3a « cette année » — RÉPONDU 7258 (cf i2/i3 !)"),
 "i2":("bad","REFUS","MÊME question que i1 — refusée"),
 "i3":("bad","REFUS","MÊME question que i1 — refusée → preuve stochastique"),
}
DOMN={"3a":"Pilier 3a","LPP":"LPP / 2e pilier","AVS":"AVS / 1er pilier","HYPO":"Hypothèque","FISC":"Fiscalité retrait",
 "SCEN":"Scénario","FRONT":"Frontalier","FATCA":"Expat US / FATCA","INDEP":"Indépendant","RETR":"Retraite",
 "DIVOR":"Divorce","SUCC":"Succession","FAM":"Famille","CARR":"Carrière","CONC":"Conceptuel","ADV":"Adversarial","RACH":"Rachat LPP","DET":"Déterminisme"}
CLR={"ok":"#0a7d3c","warn":"#c05600","bad":"#b00020"}

rows=""
for pid in sorted(d):
    r=d[pid]; vc,vl,vn=V.get(pid,("warn","?",""))
    rep=html.escape((r.get("reply") or r.get("error") or "")[:280])
    rows+=f'<tr><td><code>{pid}</code></td><td>{DOMN.get(r["domain"],r["domain"])}</td><td>{html.escape(r["q"])}</td>'
    rows+=f'<td style="color:{CLR[vc]};font-weight:700;white-space:nowrap">{vl}</td><td>{html.escape(vn)}</td>'
    rows+=f'<td style="font-size:11.5px;color:#555">{rep}</td></tr>\n'

n_ok=sum(1 for p in V if V[p][0]=="ok"); n_warn=sum(1 for p in V if V[p][0]=="warn"); n_bad=sum(1 for p in V if V[p][0]=="bad")

doc=f"""<!DOCTYPE html><html lang="fr"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>MINT — Carte complète de la lucidité live — 2026-06-09</title>
<style>
body{{font:14px/1.5 -apple-system,Segoe UI,Roboto,sans-serif;color:#1a1a1a;background:#faf8f3;max-width:1100px;margin:0 auto;padding:30px 22px}}
h1{{font-size:25px;margin:0 0 4px}}h2{{font-size:18px;margin:30px 0 8px;border-bottom:2px solid #e3ddd0;padding-bottom:4px}}
.sub{{color:#666;margin:0 0 18px}}
table{{border-collapse:collapse;width:100%;margin:8px 0;font-size:13px}}
th,td{{border:1px solid #e3ddd0;padding:6px 8px;text-align:left;vertical-align:top}}th{{background:#f0ece2;position:sticky;top:0}}
code{{background:#efe9dc;padding:1px 5px;border-radius:3px;font-size:12px}}
.cards{{display:flex;gap:10px;flex-wrap:wrap;margin:10px 0}}
.card{{flex:1;min-width:150px;background:#fff;border:1px solid #e3ddd0;border-radius:8px;padding:12px 14px;text-align:center}}
.card b{{font-size:28px;display:block}}
.ok{{color:#0a7d3c}}.warn{{color:#c05600}}.bad{{color:#b00020}}
.verdict{{background:#fff;border:1px solid #e3ddd0;border-left:4px solid #0a7d3c;padding:13px 17px;border-radius:6px}}
.bug{{background:#fff;border:1px solid #e3ddd0;border-radius:6px;padding:10px 14px;margin:8px 0}}
.bug b{{color:#b00020}}
</style></head><body>
<h1>MINT — Carte complète de la lucidité <em>reçue</em> (live staging)</h1>
<p class="sub">2026-06-09 · 46 probes live sur <code>POST /api/v1/anonymous/chat</code> (staging) · chiffres vérifiés contre la table registry · gate citation/dual-LLM ACTIF · protocole 0-TRUST</p>

<div class="verdict">
<strong>Verdict :</strong> quand le coach répond, c'est <strong>réellement niveau VZ</strong> — chiffres corrects, citations légales, fourchettes, « angle mort », archétype-aware, zéro terme banni, et il <strong>résiste aux pièges</strong> (pilier 4a inexistant rejeté, stock-pick refusé, promesse refusée). Mais <strong>~25% des questions factuelles de base échouent de façon STOCHASTIQUE</strong> (même question = réponse une fois, refus deux fois), et 4 bugs de contenu/pipeline confirmés dégradent la confiance — dont une <strong>erreur factuelle dangereuse sur la fiscalité frontalière</strong> et un <strong>sanitizer qui casse le français</strong>.
</div>

<div class="cards">
<div class="card"><b class="ok">{n_ok}</b>OK / VZ-grade</div>
<div class="card"><b class="warn">{n_warn}</b>Dégradé / garbled</div>
<div class="card"><b class="bad">{n_bad}</b>Refus / faux / non-validé</div>
<div class="card"><b>46</b>probes live</div>
<div class="card"><b class="ok">0</b>termes bannis émis</div>
</div>

<h2>Bugs confirmés (classés par impact)</h2>
<div class="bug"><b>P1-A — Refus faux-négatif STOCHASTIQUE (~25% des faits de base).</b> Preuve : <code>i1/i2/i3</code> = MÊME question « plafond 3a cette année ? » → répondue (7258) puis refusée 2× ⇒ non-déterministe, pas une règle de formulation. Deux fallbacks distincts : gate citation « Je n'ai pas cette donnée à jour » (<code>a1,a2,b5,i2,i3</code>) et déflexion générique « reformule ta question » (<code>c3,c5</code>). Incohérent : 3a salarié refusé / 3a indépendant répondu ; AVS max répondu / 13e&femmes punt. Gate <code>coach_chat.py:5303-5398</code>. <em>C'est le « trust collapse » : la valeur est au registre, l'utilisateur ne peut pas prédire quand il l'obtient.</em></div>
<div class="bug"><b>P1-B — Le sanitizer LSFin casse le français.</b> <code>compliance_guard.py:171</code> : <code>TERM_REPLACEMENTS={{"garanti":"possible dans ce scénario","garantie":"possible dans ce scénario"}}</code>. Toute phrase coach contenant « garanti/garantie » (omniprésent en finance) est mutilée → <code>h1</code>, <code>h2</code> : « sans aucune <u>possible dans ce scénario</u>, car les marchés fluctuent ». Systématique.</div>
<div class="bug"><b>P1-C — Fiscalité frontalière FAUSSE (vérifié expert + sources).</b> <code>h7</code> : Genève rangé en « imposé en France », Bâle en « imposé en Suisse » → les DEUX inversés. Réalité : Genève = source CH (accord 1973) ; Bâle-Ville = France (accord 1983 : BE/SO/BS/BL/VD/VS/NE/JU). Et <code>f2</code> : « frontalier pas accès au 3a » = FAUX (accès via quasi-résident + Taxation Ordinaire Ultérieure). Erreurs archétype NEVER #7, haute conséquence.</div>
<div class="bug"><b>P2-E — Pas de validation d'input absurde.</b> <code>h5</code> : revenu « -50'000 CHF » traité silencieusement comme +50'000 (Karpathy « wrong assumptions without checking »).</div>

<h2>Carte complète — 46 probes (verbatim tronqué)</h2>
<table>
<tr><th>#</th><th>Domaine</th><th>Question</th><th>Verdict</th><th>Note</th><th>Réponse coach (extrait)</th></tr>
{rows}
</table>

<h2>Lecture transversale par domaine</h2>
<ul>
<li><b>Pilier 3a</b> : valeurs correctes (7258 / 36288 OPP3 art.7) MAIS le plafond salarié est le plus touché par le refus stochastique.</li>
<li><b>LPP</b> : 4/5 corrects (22680, 26460, 6,8%) ; taux d'intérêt min refusé une fois.</li>
<li><b>AVS</b> : rentes max/min correctes (2520/1260) ; 13e rente &amp; âge femmes = déflexion « reformule ».</li>
<li><b>Hypothèque</b> : solide (20% / règle 1/3 / 5% théorique) ; plafond 2e-pilier répond à côté.</li>
<li><b>Fiscalité capital</b> : taux cantonaux corrects (GE 7,5% / ZG 3,5% / VD 8%).</li>
<li><b>Scénarios &amp; vie</b> : FATCA, divorce, succession, héritage, conceptuel = excellents.</li>
<li><b>Frontalier</b> : le point FAIBLE — fiscalité inversée + accès 3a faux.</li>
<li><b>Adversarial / robustesse</b> : excellent (4a rejeté, stock-pick refusé, 14 ans gracieux) sauf garbling sanitizer + input négatif.</li>
</ul>

<h2>Limites de preuve (0-TRUST)</h2>
<ul>
<li>Archétype <b>anonyme</b> uniquement (teaser 3 messages). Le coach <b>authentifié</b> (profil + LPP/budget importés) — où vit la lucidité personnalisée la plus profonde — n'a PAS été testé.</li>
<li>E2E on-device complet non exécuté (build sim bloqué codesign <code>.nosync</code>) ; contenu validé via API staging.</li>
<li>Sondage à 1 tour par session (pas de mémoire conversationnelle anonyme) ; cohérence multi-tours non testée.</li>
<li>Déterminisme mesuré sur 1 question (3×) ; taux de refus réel à confirmer sur n plus grand.</li>
</ul>
<p class="sub">Données : <code>.planning/_walker/coach-map/results.json</code> · engram obs #1591/#1592/#1594 · code-track : <a href="SESSION-2026-06-09-mint-state-audit.html">SESSION-2026-06-09-mint-state-audit.html</a></p>
</body></html>"""
open(REPORT,"w").write(doc)
print("WROTE",REPORT)
print(f"verdicts: ok={n_ok} warn={n_warn} bad={n_bad}")
