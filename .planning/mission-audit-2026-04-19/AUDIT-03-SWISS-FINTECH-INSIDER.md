# AUDIT-03 — Swiss Fintech Insider

**Persona** : 25 ans UBS Tech pensions / Swissquote / Raiffeisen Romandie. Vu Cleo, VZ, Yuh, Neon, Alpian de l'intérieur.
**Sujet** : salarié/indépendant 40-65 ans, marié + enfants, LPP + 3a + hypothèque, déclaration annuelle.
**Date** : 2026-04-19 · dev tip `f35ec8ff`

---

## 1. Verdict

**MINT n'est pas au niveau 2026.** Ambition VZ (profondeur, 18 life events) mais mécanique de *simulateur*, pas de *dossier vivant*. Les trois moments où un Suisse attend que son app parle — **janvier (certificat LPP)**, **mars-avril (déclaration fiscale)**, **oct-nov (prime LAMal)** — ne déclenchent rien. Seul rappel câblé : 3a oct-déc (`notification_scheduler_service.py`). Pour un 49 ans VD recevant 14 docs officiels/an, MINT est muet 11 mois sur 12. **Très bon sur le calcul ponctuel, mal sur le compagnon annuel.** Julien garde son Excel et paie 290 CHF à VZ.

---

## 2. Top 10 gaps attendus-vs-fourni

| # | Attente | État MINT | Note |
|---|---|---|---|
| 1 | **Certificat LPP janvier** : scan → diff N/N-1 avoir, salaire assuré, bonif., conversion ; alerte changement plan | Parser `lpp_certificate_parser.py` OK. **Aucun diff N/N-1, aucun trigger** | **3/10** |
| 2 | **Déclaration fiscale cantonale** : deadlines VD/GE/BE 15-31.03, ZH 31.03, TI 30.04 ; pré-remplissage 3a/LPP/EPL/rachat | `tax_declaration_parser.py` + `fiscal/commune_service.py` existent. **Aucun calendrier cantonal, aucun pré-remplissage** | **2/10** |
| 3 | **Fiche de salaire mensuelle** : AVS 5.30%/AC 1.1%/LPP selon plan, détecter 13e, signaler erreur employeur | **Rien.** Aucun payslip parser | **0/10** |
| 4 | **Prime LAMal oct-nov** : fenêtre résiliation 30.11, compare franchises + modèles (standard/HMO/tél./pharma), alerte hausse OFSP | `lamal_franchise_screen` = slider statique. **Aucune saisonnalité, aucun comparateur multi-assureurs** | **3/10** |
| 5 | **Allocations LAFam** : CHF 200-440/enfant selon canton, droit conjoint activité principale | `family_service.dart` mentionne. **Aucun calcul cantonal, pas de trigger naissance** | **2/10** |
| 6 | **Rente AVS 8 archétypes** : RAMD, années futures, splitting marié, bonif. éducatives LAVS art. 29sexies | `AvsCalculator.computeCouple()` OK. **Bonif. éducatives absentes** (~+5-8%) | **6/10** |
| 7 | **Hypothèque annuelle** : SARON vs fixe, amortissement indirect 3a vs direct, valeur locative, entretien | `mortgage/` + `imputed_rental_screen` corrects. **Aucun suivi valeur locative annuel, pas d'alerte renouvellement fixe** | **5/10** |
| 8 | **Rachat LPP fiscal** : ATF 142 II 399 (3 ans avant retrait = reprise), étalement pluri-annuel progressif cantonal | W4 swiss-brain a câblé `dateRachats: List<DateTime>`. **Étalement cantonal non optimisé** | **7/10** |
| 9 | **13e AVS 2026 + BVG 21** : rente AVS +8.33%, âge 65F, conversion 6.8%→6.0% proposée | Âge 65F OK. **13e AVS hors projecteur, scénario BVG 21 absent** | **4/10** |
| 10 | **Dossier vivant cross-doc** : LPP + salaire + 3a + LAMal + taxation → timeline + détection incohérences | `documents_screen` + `document_memory_service` existent. **Pas de cross-référencement** | **3/10** |

**Moyenne : 3.5/10.**

---

## 3. 5 événements annuels qui ne déclenchent rien

1. **Janvier — certificat LPP arrive** : aucun trigger, aucun diff N-1.
2. **Mars-avril — déclaration fiscale** : aucun rappel cantonal, aucun pré-remplissage.
3. **Juin-juillet — décompte taxation** : aucune ingestion, aucun "voici comment baisser l'an prochain".
4. **Oct-nov — primes LAMal** : aucune alerte 30.11, aucun comparateur annuel.
5. **Décembre — 13e / bonus** : aucun nudge "marge 3a + 13e → impact fiscal".

---

## 4. 3 features à supprimer

1. **`gender_gap_screen.dart`** — politique, pas une attente d'un 49 ans VD. Décharge en insert éducatif.
2. **`consumer_credit_screen.dart` isolé** — signal Safe Mode, pas écran-produit. Intègre dans `debt_risk_check_screen`.
3. **`simulator_leasing_screen.dart`** — leasing auto ne mérite pas un top-level. Insert dans budget.

---

## 5. 5 raisons de préférer VZ / Cleo / Yuh

1. **VZ livre un plan LPP écrit signé** (290 CHF, 90 min). MINT lit, ne livre pas de plan daté.
2. **VZ a les deadlines fiscales cantonales en CRM** et relance en février. MINT = silence.
3. **Cleo a une conversation continue** (mémoire, voix). MINT = chat sans mémoire cross-session visible.
4. **Yuh/Neon ont bLink vivant**. MINT `open_banking/` existe mais n'alimente pas visiblement le dossier.
5. **VZ donne un humain** (52% des 50+ veulent validation humaine). MINT = 100% LLM, pas de tier expert.

---

## 6. Top 5 à câbler MAINTENANT

1. **Calendrier fiscal 26 cantons** — deadlines + rappels J-21/J-7/J-1 + deeplink `documents_screen`. **3-5j. Débloque mars-avril.**
2. **Certificat LPP diff N/N-1** — scan janvier → diff avoir/salaire assuré/bonif./conversion + alerte plan. **1-2 sem.**
3. **Payslip parser** (`bulletin_salaire_parser.py`) — AVS 10.60%, AC 2.2%, LPP vs certificat, 13e. **2 sem. MINT devient mensuel.**
4. **Fenêtre LAMal oct-nov** — notif J-30, comparateur franchise+modèle, hausse OFSP (asset class, compliance OK). **1 sem.**
5. **Dossier vivant cross-ref** — relier salaire déclaré / assuré LPP / imposable / net budget. Détecter incohérences. **2 sem. Différenciateur anti-Cleo.**

**Sans ces 5 : simulateur. Avec : le dossier que VZ vend 290 CHF.**
