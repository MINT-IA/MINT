---
name: mint-audit-complet
description: Audit croisé complet de MINT. Lance 5 équipes spécialisées en parallèle (actuariat, juridique, UX, 3 piliers, DevOps), converge les findings, et produit un rapport unifié PASS/FAIL. Invoke avec /audit-complet ou quand on demande un audit global.
compatibility: Requires Flutter SDK, Python 3.10+, pytest, curl. Works across entire MINT codebase.
metadata:
  author: mint-team
  version: "1.0"
---

# MINT Audit Complet — 5 Équipes, 75 Gates

## Purpose

Tu es le **Team Lead d'audit**. Tu orchestres 5 équipes spécialisées qui auditent MINT en parallèle, puis tu converges les résultats en un rapport actionnable.

**Tu ne fixes RIEN. Tu ne modifies AUCUN fichier. Tu CONSTATES et tu RAPPORTES.**

## Reference

Le document de référence est `docs/AUDIT_CROSS_FUNCTIONAL.md`. Lis-le TOUJOURS en premier.

## Execution Protocol

### STEP 0 — Préparation

```bash
cd /Users/julienbattaglia/Desktop/MINT
git status
git log --oneline -3
```

Confirmer: working tree clean, on main (ou branche spécifiée).

### STEP 1 — Lancer les 5 équipes en PARALLÈLE

Lance **5 agents simultanément** via le tool Agent. Chaque agent reçoit sa grille et produit un rapport PASS/FAIL.

---

#### AGENT 1 : ACTUARIAT & CALCULS (15 gates)

Prompt pour l'agent :
```
Tu es l'équipe ACTUARIAT de l'audit croisé MINT. Ta mission: vérifier que TOUS les calculs financiers sont corrects.

Lis d'abord: docs/AUDIT_CROSS_FUNCTIONAL.md § ÉQUIPE 1

Exécute ces commandes et reporte PASS/FAIL pour chaque gate:

A1 — Constantes backend:
Lis services/backend/app/constants/social_insurance.py et vérifie:
- LPP seuil 22680, coordination 26460, min coordonné 3780, conversion 6.8%
- 3a salarié 7258, 3a indep max 36288
- AVS taux total 10.60%, rente max 30240

A2 — Constantes Flutter = backend:
Lis apps/mobile/lib/constants/social_insurance.dart et compare les mêmes valeurs.
Toute divergence = FAIL.

A3 — Zéro hardcoding Flutter services:
grep -rn "22680\|26460\|7258\|36288\|30240\|6\.8" apps/mobile/lib/services/ --include="*.dart" | grep -v constants/ | grep -v financial_core/ | grep -v test | grep -v archive
PASS si 0 résultats pertinents (ignorer les faux positifs comme des commentaires).

A4 — Zéro hardcoding backend services:
grep -rn "22_680\|26_460\|7_258\|36_288\|30_240\|22680\|26460\|7258\|36288\|30240" services/backend/app/services/ --include="*.py" | grep -v constants/
PASS si 0 résultats pertinents.

A5 — Bonification LPP par âge:
Vérifier dans les constants: 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65)

A6 — Capital withdrawal tax progressive:
Vérifier barème: 0-100k ×1.00, 100-200k ×1.15, 200-500k ×1.30, 500k-1M ×1.50, 1M+ ×1.70

A7 — Zéro _calculate hors financial_core:
grep -rn "_calculate" apps/mobile/lib/services/ --include="*.dart" | grep -v financial_core/ | grep -v test | grep -v archive
Pour chaque résultat: c'est du domain logic local OK, ou c'est un calcul financier réplicable = FAIL.

A8 — AVS futures années comptées:
Vérifier que AvsCalculator ajoute les années futures. Chercher "contributionYears / 44" sans correction = FAIL.

A9 — Cap AVS couple = mariés uniquement:
grep -rn "cap\|plafonn\|150\|LAVS.*35" apps/mobile/lib/services/ --include="*.dart"
Vérifier que le cap 150% ne s'applique PAS aux concubins.

A10 — Confidence score sur projections:
Vérifier que les services de projection retournent confidenceScore. Lister ceux qui n'en ont pas.

A11 — 8 archetypes gérés:
grep -rn "swiss_native\|expat_eu\|expat_non_eu\|expat_us\|independent_with_lpp\|independent_no_lpp\|cross_border\|returning_swiss" apps/mobile/lib/ --include="*.dart"
Vérifier que les 8 sont définis et utilisés.

A12 — AC durée correcte:
Vérifier: standard = 400j (≥22 mois, <55 ans), senior = 520j (≥55 ans). PAS 260j pour 25-54.

A13 — Pas de double-taxation capital:
Vérifier dans rente_vs_capital et withdrawal_sequencing que SWR ≠ revenu imposable.

A14 — Golden couple Julien (spot check):
Vérifier que les tests référencent salaire 122207, LPP 70377, rachat 539414.

A15 — Golden couple Lauren (spot check):
Vérifier que les tests référencent archetype expat_us, LPP 19620.

Format de sortie OBLIGATOIRE:
GATE A1: [PASS|FAIL] — description courte
...
GATE A15: [PASS|FAIL] — description courte

SUMMARY: X/15 PASS, Y/15 FAIL
FINDINGS P0: [liste]
FINDINGS P1: [liste]
FINDINGS P2: [liste]
```

---

#### AGENT 2 : JURIDIQUE & COMPLIANCE (15 gates)

Prompt pour l'agent :
```
Tu es l'équipe JURIDIQUE de l'audit croisé MINT. Ta mission: vérifier la conformité légale de tous les textes user-facing.

Lis d'abord: docs/AUDIT_CROSS_FUNCTIONAL.md § ÉQUIPE 2

Exécute ces commandes et reporte PASS/FAIL:

J1 — Termes bannis dans screens/widgets:
grep -rn "garanti" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v "// \|test\|non.garantis\|pas.garantis\|non garantis"
grep -rn '"certain"' apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"
grep -rn "sans risque" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"
grep -rn '"optimal"\|"meilleur"\|"parfait"' apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"
grep -rn '"conseiller"' apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v "spécialiste"
FAIL si un terme banni apparaît dans un string user-facing (pas un variable name ou commentaire).

J2 — Pas de ranking d'options:
grep -rn "recommandé\|préféré\|classement\|la meilleure" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"
FAIL si un arbitrage présente une option comme supérieure.

J3 — Pas de comparaison sociale:
grep -rn "top [0-9]\|moyenne suisse\|percentile\|comparé aux autres\|mieux que" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | grep -v compliance
PASS si 0 résultats.

J4 — LEGAL_RELEASE_CHECK.md items ouverts:
grep -c "\[ \]" LEGAL_RELEASE_CHECK.md
Lister CHAQUE item non coché. FAIL si ≥1 item non coché concerne une feature livrée.

J5 — ComplianceGuard couvre banned terms:
Lire apps/mobile/lib/services/coach/compliance_guard.dart
Vérifier que la liste inclut: garanti, certain, assuré, sans risque, optimal, meilleur, parfait, conseiller.

J6 — Read-only vérifié:
grep -rn "paiement\|virement\|transaction\|acheter\|souscrire" apps/mobile/lib/screens/ --include="*.dart" | grep -v "// \|test\|éducati\|simul"
PASS si aucun bouton d'action financière réelle.

J7 — Données sensibles non loggées:
grep -rn "print(\|debugPrint(" apps/mobile/lib/services/ --include="*.dart" | grep -v test | grep -v "// "
Pour chaque résultat: vérifier qu'aucun IBAN, nom, SSN, salaire exact n'est loggé.

J8 — CoachContext sans montants exacts:
Lire le CoachContext model. Vérifier qu'il ne contient PAS salary/savings/debts/NPA/employer en clair.

J9 — Disclaimers backend:
Vérifier que les principaux schemas de réponse (retirement, arbitrage, lpp) ont un champ "disclaimer".

J10 — CGU/Privacy/Disclaimer cohérents:
Lire legal/CGU.md, legal/DISCLAIMER.md, legal/MENTIONS_LEGALES.md — pas de contradiction.

J11 — Langage conditionnel:
grep -rn "tu dois\|il faut\|vous devez\|tu devrais acheter\|investis dans" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v "// " | grep -v compliance
PASS si 0 résultats prescriptifs.

J12 — Arbitrage côte à côte:
Vérifier visuellement que rente_vs_capital_screen et allocation_annuelle_screen montrent les options côte à côte, jamais classées.

J13 — Hypothèses visibles:
Chaque écran d'arbitrage montre les hypothèses (taux, durée, etc.) et permet de les modifier.

J14 — Sensitivity analysis:
Chaque arbitrage inclut un texte "Si X change..." ou un slider de sensibilité.

J15 — BYOK consent:
Si BYOK existe, vérifier qu'un écran de consentement montre exactement quelles données sont envoyées.

Format: GATE J1: [PASS|FAIL] — description courte
SUMMARY + FINDINGS classés P0-P3.
```

---

#### AGENT 3 : UX & DESIGN SYSTEM (15 gates)

Prompt pour l'agent :
```
Tu es l'équipe UX de l'audit croisé MINT. Ta mission: vérifier la cohérence du design system et l'expérience utilisateur.

Lis d'abord: docs/AUDIT_CROSS_FUNCTIONAL.md § ÉQUIPE 3

U1 — Hardcoded colors:
grep -rn "Color(0x" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v test | grep -v archive | grep -v "// "
grep -rn "Colors\." apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v test | grep -v archive | grep -v "// " | grep -v "Colors.transparent"
FAIL si > 0 occurrences (devrait utiliser MintColors.*).

U2 — Navigator.push (devrait être GoRouter):
grep -rn "Navigator\.push\|Navigator\.of" apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive
FAIL si > 0 résultats.

U3 — Hardcoded French strings dans screens:
grep -rn "Text('" apps/mobile/lib/screens/ --include="*.dart" | grep -v "Text(S\.\|Text(widget\.\|Text(state\.\|Text(format\|Text(style\|// " | head -30
Compter le nombre d'écrans avec des strings FR littérales.

U4 — i18n 6 langues même nombre de keys:
wc -l apps/mobile/lib/l10n/app_fr.arb apps/mobile/lib/l10n/app_en.arb apps/mobile/lib/l10n/app_de.arb apps/mobile/lib/l10n/app_es.arb apps/mobile/lib/l10n/app_it.arb apps/mobile/lib/l10n/app_pt.arb
FAIL si écart > 50 lignes entre template (fr) et une autre langue.

U5 — Accents FR obligatoires:
grep -rn "impot\b\|etre\b\|prevoyance\b\| retraite\b\|a ete\b" apps/mobile/lib/l10n/app_fr.arb
FAIL si accent manquant dans le template FR.

U6 — Non-breaking spaces:
grep -rn " !\| ?\| :\| ;" apps/mobile/lib/l10n/app_fr.arb | grep -v "\\\\u00a0\|http\|@" | head -10
FAIL si espace simple avant ponctuation double en FR (devrait être \u00a0).

U7 — Fonts cohérentes:
grep -rn "fontFamily\|GoogleFonts\." apps/mobile/lib/ --include="*.dart" | grep -v test | grep -v archive | sort -u
Vérifier: Montserrat pour headings, Inter pour body. Pas d'autre font.

U8 — MintColors palette:
Lire apps/mobile/lib/theme/colors.dart — vérifier que primary, accent, error, info, purple, gold existent.

U9 — SliverAppBar usage:
grep -rn "SliverAppBar\|AppBar" apps/mobile/lib/screens/ --include="*.dart" | head -20
Vérifier que les écrans principaux utilisent SliverAppBar.

U10 — GoRouter navigation:
grep -rn "context\.go\|context\.push\|GoRoute" apps/mobile/lib/app.dart | wc -l
Vérifier que les routes sont définies dans app.dart.

U11 — Provider state (pas raw StatefulWidget pour shared data):
grep -rn "extends StatefulWidget" apps/mobile/lib/screens/ --include="*.dart" | wc -l
Vérifier que les shared data passent par Provider.

U12 — PDF export status:
grep -rn "TODO.*PDF\|TODO.*pdf\|TODO.*export" apps/mobile/lib/screens/ --include="*.dart"
Lister les simulateurs avec export non implémenté.

U13 — Responsive (heuristic):
grep -rn "MediaQuery\|LayoutBuilder\|Expanded\|Flexible" apps/mobile/lib/screens/ --include="*.dart" | wc -l
Vérifier que les écrans principaux sont responsive.

U14 — Material 3:
grep -rn "useMaterial3" apps/mobile/lib/ --include="*.dart"
PASS si Material 3 activé dans le theme.

U15 — Charte L6 chiffre-choc:
Vérifier visuellement 5 écrans principaux: retirement, lpp, avs, arbitrage, profile — chacun commence par un hero number.

Format: GATE U1: [PASS|FAIL] — description courte
SUMMARY + FINDINGS classés P0-P3.
```

---

#### AGENT 4 : 3 PILIERS & CONTENU ÉDUCATIF (15 gates)

Prompt pour l'agent :
```
Tu es l'équipe 3 PILIERS de l'audit croisé MINT. Ta mission: vérifier l'exactitude du contenu éducatif.

Lis d'abord: docs/AUDIT_CROSS_FUNCTIONAL.md § ÉQUIPE 4

E1 — Inventaire inserts éducatifs:
ls education/inserts/ | wc -l
Lister les fichiers. Vérifier couverture des sujets majeurs.

E2 — Pilier 1 (AVS) exact:
Lire les inserts AVS. Vérifier: taux 10.60%, rente max 30240/an, 44 années, splitting divorce.
Comparer avec services/backend/app/constants/social_insurance.py.

E3 — Pilier 2 (LPP) exact:
Lire les inserts LPP. Vérifier: seuil 22680, coordination 26460, conversion 6.8%, bonifications, EPL 20000 min, blocage 3 ans.

E4 — Pilier 3a exact:
Lire les inserts 3a. Vérifier: salarié LPP 7258/an, indep sans LPP 20% max 36288/an.

E5 — Hypothèque exact:
Lire les inserts hypothèque. Vérifier: taux théorique 5%, amortissement 1%, frais 1%, charges 1/3, fonds propres 20%.

E6 — AC durée correcte dans inserts:
Chercher dans les inserts: durée standard = 400j (pas 260j pour 25-54). Senior = 520j pour ≥55 ans.

E7 — Pas de conseil déguisé:
grep -rn "il faut\|tu dois\|vous devez\|la meilleure\|garanti" education/inserts/ --include="*.md"
PASS si 0 résultats prescriptifs.

E8 — Pas de promesse de rendement:
grep -rn "rendement\|performance\|return" education/inserts/ --include="*.md"
Chaque mention doit avoir scénarios (Bas/Moyen/Haut) ou disclaimer.

E9 — Références légales présentes:
Compter les inserts avec référence à un article de loi (LPP art., LAVS art., LIFD art., etc.).
FAIL si < 70% des inserts financiers ont une source légale.

E10 — Couverture des 18 life events:
Mapper les inserts aux life events. Lister ceux sans couverture éducative.

E11 — Couverture des 8 archetypes:
grep -rn "expat\|frontalier\|indépendant\|cross.border\|returning" education/inserts/ --include="*.md"
Vérifier que les spécificités sont mentionnées.

E12 — Constantes dans inserts = centralisées:
grep -rn "22.680\|26.460\|7.258\|36.288\|30.240\|6,8\|6\.8" education/inserts/ --include="*.md"
Chaque montant doit correspondre à la valeur dans social_insurance.py.

E13 — Wizard questions ont un insert:
Lister les questions wizard (apps/mobile/lib/data/) et vérifier que chaque question financière a un insert associé.

E14 — Multilangue:
ls education/inserts/*_de* education/inserts/*_en* 2>/dev/null | wc -l
Documenter la couverture linguistique (FR obligatoire, DE/EN = bonus).

E15 — Ton éducatif cohérent:
Vérifier 5 inserts aléatoires. Ton = informatif, pas prescriptif. Conditionnel utilisé pour les recommandations.

Format: GATE E1: [PASS|FAIL] — description courte
SUMMARY + FINDINGS classés P0-P3.
```

---

#### AGENT 5 : DEVOPS & QUALITÉ (15 gates)

Prompt pour l'agent :
```
Tu es l'équipe DEVOPS de l'audit croisé MINT. Ta mission: vérifier que les tests, CI/CD, et infra sont solides.

Lis d'abord: docs/AUDIT_CROSS_FUNCTIONAL.md § ÉQUIPE 5

D1 — Backend tests green:
cd /Users/julienbattaglia/Desktop/MINT/services/backend && python3 -m pytest tests/ -q
PASS si 0 failures.

D2 — Flutter analyze clean:
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter analyze 2>&1 | tail -10
PASS si "No issues found" ou 0 errors.

D3 — Flutter tests green:
cd /Users/julienbattaglia/Desktop/MINT/apps/mobile && flutter test 2>&1 | tail -15
PASS si 0 failures.

D4 — Healthcheck prod:
curl -s https://mint-production-3a41.up.railway.app/api/v1/health
PASS si {"status":"ok"}.

D5 — Couverture tests backend:
Compter: ls services/backend/app/services/**/*.py | wc -l (total services)
vs: ls services/backend/tests/test_*.py | wc -l (tests existants)
Calculer le ratio. FAIL si < 30%.

D6 — Pydantic v2 pur:
grep -rn "class Config:" services/backend/ --include="*.py" | grep -v __pycache__ | grep -v test
PASS si 0 résultats (tout doit être ConfigDict).

D7 — Auth placeholder:
grep -rn "user_id.*=.*1\b\|user_id=1" services/backend/ --include="*.py"
FAIL si trouvé hors test.

D8 — Secrets committed:
grep -rn "sk-\|Bearer [a-zA-Z0-9]\|password\s*=\s*['\"]" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py" | grep -v test | grep -v example | grep -v mock | grep -v "# \|// "
PASS si 0 résultats.

D9 — Railway config:
grep "DOCKERFILE" services/backend/railway.json
PASS si "builder": "DOCKERFILE" présent.

D10 — TODOs inventaire:
grep -rn "TODO\|FIXME\|HACK" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py" | grep -v archive
Compter et classifier: combien P0, P1, P2, P3.

D11 — CI workflow exist:
ls .github/workflows/ci.yml .github/workflows/deploy-backend.yml .github/workflows/testflight.yml 2>/dev/null | wc -l
PASS si 3.

D12 — Git clean state:
git status --porcelain | wc -l
Rapporter les fichiers modifiés/non-trackés.

D13 — OpenAPI sync:
ls tools/openapi/ 2>/dev/null
Vérifier que le fichier canonique existe.

D14 — Ruff clean:
cd /Users/julienbattaglia/Desktop/MINT/services/backend && python3 -m ruff check . 2>&1 | tail -5
PASS si 0 errors.

D15 — TestFlight config:
ls apps/mobile/ios/fastlane/Fastfile .github/workflows/testflight.yml 2>/dev/null | wc -l
PASS si 2.

Format: GATE D1: [PASS|FAIL] — description courte
SUMMARY + FINDINGS classés P0-P3.
```

---

### STEP 2 — CONVERGENCE

Quand les 5 agents ont terminé, rassemble leurs rapports et produis:

#### 2.1 Tableau de synthèse

```
╔══════════════════════════╦══════╦══════╦═══════════════╗
║ Équipe                   ║ PASS ║ FAIL ║ Findings P0   ║
╠══════════════════════════╬══════╬══════╬═══════════════╣
║ Actuariat & Calculs      ║  /15 ║  /15 ║               ║
║ Juridique & Compliance   ║  /15 ║  /15 ║               ║
║ UX & Design System       ║  /15 ║  /15 ║               ║
║ 3 Piliers & Éducatif     ║  /15 ║  /15 ║               ║
║ DevOps & Qualité         ║  /15 ║  /15 ║               ║
╠══════════════════════════╬══════╬══════╬═══════════════╣
║ TOTAL                    ║  /75 ║  /75 ║               ║
╚══════════════════════════╩══════╩══════╩═══════════════╝
```

#### 2.2 Findings transversaux

Chercher les patterns qui touchent ≥ 2 équipes :
- Calcul faux + wording faux (Actuariat + Juridique)
- Calcul correct + affichage faux (Actuariat + UX)
- i18n manquant + terme banni (UX + Juridique)
- Test absent + calcul critique (DevOps + Actuariat)
- Constante drift backend↔Flutter (Actuariat + DevOps)
- Insert éducatif obsolète + widget incorrect (3 Piliers + UX)

#### 2.3 Backlog priorisé

Produire la liste FINALE classée:
```
P0 — BLOQUANTS (fix avant tout merge):
1. [finding]

P1 — CRITIQUES (fix dans le sprint courant):
1. [finding]

P2 — IMPORTANTS (sprint suivant):
1. [finding]

P3 — COSMÉTIQUES (backlog):
1. [finding]
```

#### 2.4 Score global

```
MINT HEALTH SCORE: XX/75 gates PASS (YY%)
  Actuariat:  /15 (  %)
  Juridique:  /15 (  %)
  UX:         /15 (  %)
  3 Piliers:  /15 (  %)
  DevOps:     /15 (  %)

VERDICT: [GREEN | YELLOW | RED]
  GREEN  = ≥ 90% PASS, 0 P0
  YELLOW = ≥ 70% PASS, 0 P0
  RED    = < 70% PASS ou ≥ 1 P0
```

### STEP 3 — Écrire le rapport

Écrire le rapport complet dans `docs/AUDIT_REPORT_YYYY-MM-DD.md` avec:
- Date, branche, dernier commit
- Tableau de synthèse
- Findings transversaux
- Backlog priorisé
- Score global + verdict

## Rules

- **NEVER** modify code during un audit
- **NEVER** fix les bugs — tu les CONSTATES
- **NEVER** donne d'opinions subjectives — PASS/FAIL uniquement
- Run ALL 75 gates, même si des gates échouent tôt
- Les 5 agents DOIVENT tourner en parallèle (Agent tool, 5 appels simultanés)
- Le rapport est le livrable — pas de prose, pas de "nice to have"
- Si un agent timeout ou échoue, le noter dans le rapport et continuer
