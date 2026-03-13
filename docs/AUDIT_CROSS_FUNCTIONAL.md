# Audit Croisé MINT — Grilles Opérationnelles par Équipe

> **Version**: 1.0 — 2026-03-13
> **Objectif**: Rendre le debugging ultra-performant via un audit systématique par domaine
> **Méthode**: Chaque équipe audite son périmètre → convergence → re-audit ciblé
> **Règle d'or**: Si c'est FAIL, c'est un blocker. Pas de prose, pas d'opinion — PASS/FAIL + commande pour reproduire.

---

## TAXONOMIE DE SÉVÉRITÉ (commune à toutes les équipes)

| Niveau | Nom | Définition | SLA |
|--------|-----|-----------|-----|
| **P0** | **BLOQUANT** | Non-conformité légale, calcul financier faux, fuite de données | Fix immédiat, avant tout merge |
| **P1** | **CRITIQUE** | UX cassé, i18n manquant sur écran principal, test absent sur calcul financier | Fix dans le sprint courant |
| **P2** | **IMPORTANT** | Dette technique, TODO non traité, optimisation, wording imprécis | Planifié sprint suivant |
| **P3** | **COSMÉTIQUE** | Polish, micro-UX, refactoring préventif | Backlog, si le temps le permet |

### Format de finding (obligatoire)

```
[P0|P1|P2|P3] TITRE_COURT
- Fichier: path/to/file.dart:42
- Commande de repro: `grep -n "garanti" apps/mobile/lib/screens/*.dart`
- Attendu: <comportement correct>
- Constaté: <comportement actuel>
- Fix suggéré: <1 ligne>
```

---

## PHASE 1 — AUDIT SECTORIEL (en parallèle)

---

### ÉQUIPE 1 : ACTUARIAT & CALCULS FINANCIERS

**Périmètre**: 122 services Flutter + 141 services backend + `financial_core/` + `constants/`

#### Grille d'audit

| # | Gate | Commande de vérification | PASS/FAIL |
|---|------|--------------------------|-----------|
| **A1** | Constantes backend = CLAUDE.md | Vérifier `services/backend/app/constants/social_insurance.py` : LPP seuil 22'680, coordination 26'460, min coordonné 3'780, conversion 6.8%, 3a salarié 7'258, 3a indep 36'288, AVS taux 10.60%, rente max 30'240 | ☐ |
| **A2** | Constantes Flutter = backend | Diff `apps/mobile/lib/constants/social_insurance.dart` vs `services/backend/app/constants/social_insurance.py` — toute divergence = P0 | ☐ |
| **A3** | Zéro hardcoding dans services | `grep -rn "22680\|26460\|7258\|36288\|30240\|6\.8" apps/mobile/lib/services/ --include="*.dart"` — hors `constants/` et `financial_core/` = P1 | ☐ |
| **A4** | Zéro hardcoding backend | `grep -rn "22680\|26460\|7258\|36288\|30240" services/backend/app/services/ --include="*.py"` — hors `constants/` = P1 | ☐ |
| **A5** | Golden couple Julien ±1 CHF | Exécuter tests golden: LPP projeté 677'847, rachat max 539'414, AVS couple 2'500/mois, taux remplacement 65.5% | ☐ |
| **A6** | Golden couple Lauren ±1 CHF | LPP projeté ~153'000, rachat max 52'949, archetype `expat_us` détecté | ☐ |
| **A7** | Zéro `_calculate*` hors financial_core | `grep -rn "_calculate" apps/mobile/lib/services/ --include="*.dart"` — vérifier que chaque occurrence est du domain logic local, PAS du calcul financier réplicable | ☐ |
| **A8** | Bonification LPP par âge correcte | 7% (25-34), 10% (35-44), 15% (45-54), 18% (55-65) — vérifier dans constants ET dans les consumers | ☐ |
| **A9** | Capital withdrawal tax progressive | Vérifier barème: 0-100k ×1.00, 100-200k ×1.15, 200-500k ×1.30, 500k-1M ×1.50, 1M+ ×1.70 | ☐ |
| **A10** | Pas de double-taxation capital | SWR ≠ revenu imposable. Capital taxé au retrait (LIFD 38) uniquement. Vérifier `rente_vs_capital` et `withdrawal_sequencing` | ☐ |
| **A11** | AVS futures années comptées | `AvsCalculator` ajoute les années futures. Vérifier qu'aucun service n'utilise `contributionYears / 44` brut | ☐ |
| **A12** | Cap AVS couple = mariés uniquement | LAVS art. 35 (150%) = mariés seulement. Vérifier que concubins ne sont PAS capés | ☐ |
| **A13** | Confidence score sur TOUTES les projections | Chaque service de projection retourne `confidenceScore` + `enrichmentPrompts` + bande d'incertitude si < 70% | ☐ |
| **A14** | 8 archetypes gérés | swiss_native, expat_eu, expat_non_eu, expat_us, independent_with_lpp, independent_no_lpp, cross_border, returning_swiss — chaque projection DOIT brancher | ☐ |
| **A15** | AC durée correcte | Standard 400j (pas 260), senior 55+ = 520j. `grep -rn "260" apps/mobile/lib/` pour trouver erreurs | ☐ |

#### Findings connus (pré-remplis)

```
[P2] Hardcoded constants dans naissance_service.py
- Fichier: services/backend/app/services/family/naissance_service.py:83-97
- Commande: grep -n "22_680\|26_460\|7_258" services/backend/app/services/family/naissance_service.py
- Attendu: import depuis constants/social_insurance.py
- Constaté: LPP_SEUIL_ENTREE, LPP_DEDUCTION_COORDINATION, PLAFOND_3A redéfinis localement
- Fix: remplacer par import + appel constants centralisés
```

```
[P1] 86 services backend sans tests
- Fichier: services/backend/app/services/ (86 sur 98 fichiers)
- Commande: diff entre ls services/backend/app/services/ et ls services/backend/tests/
- Attendu: minimum 10 tests par service (DoD)
- Constaté: 12 services testés sur 98
- Fix: prioriser les services financiers critiques (disability_gap, divorce_simulator, housing_sale, lpp_conversion, succession_simulator)
```

---

### ÉQUIPE 2 : JURIDIQUE & COMPLIANCE

**Périmètre**: 5 fichiers légaux + tous les textes user-facing + ComplianceGuard + disclaimers

#### Grille d'audit

| # | Gate | Commande de vérification | PASS/FAIL |
|---|------|--------------------------|-----------|
| **J1** | Zéro termes bannis user-facing | `grep -rn "garanti\|certain\|assuré\|sans risque\|optimal\|meilleur\|parfait\|conseiller" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"` — filtrer variables internes, ne garder que strings affichées | ☐ |
| **J2** | Disclaimers dans chaque service financier | Chaque `*Result`/`*Response` backend contient `disclaimer` + `sources` avec réf. légale | ☐ |
| **J3** | LEGAL_RELEASE_CHECK.md à jour | Toutes les checkboxes cochées. Les items § 6-8 (unchecked) = P0 si feature livrée | ☐ |
| **J4** | Pas de conseil déguisé | Aucun texte ne dit "vous devriez", "il faut", "la meilleure option est". Conditionnel obligatoire | ☐ |
| **J5** | Pas de ranking d'options | Arbitrage: toujours côte à côte, jamais classé. `grep -rn "recommandé\|préféré\|classement" apps/mobile/lib/ --include="*.dart"` | ☐ |
| **J6** | Pas de comparaison sociale | `grep -rn "top\|moyenne suisse\|comparé aux autres\|percentile" apps/mobile/lib/ --include="*.dart"` — TOUT = P0 | ☐ |
| **J7** | CGU / Privacy / Disclaimer cohérents | Comparer `legal/CGU.md`, `legal/DISCLAIMER.md`, `legal/MENTIONS_LEGALES.md` — dates, versions, pas de contradiction | ☐ |
| **J8** | Read-only vérifié | `grep -rn "paiement\|virement\|transaction\|acheter\|souscrire" apps/mobile/lib/ --include="*.dart"` — rien d'actionnable | ☐ |
| **J9** | Zéro données sensibles loggées | `grep -rn "print(\|log(\|debugPrint(" apps/mobile/lib/services/ --include="*.dart"` — vérifier qu'aucun IBAN, nom, SSN, salaire exact | ☐ |
| **J10** | ComplianceGuard couvre banned terms | Vérifier `compliance_guard.dart` — la liste DOIT inclure TOUS les termes de CLAUDE.md § 6 | ☐ |
| **J11** | BYOK consent écran | Si BYOK actif: écran de consentement montre exactement quelles données sont envoyées à quel provider | ☐ |
| **J12** | CoachContext sans montants exacts | `grep -rn "salary\|salaire\|savings\|debt\|npa\|employer" apps/mobile/lib/services/coach/ --include="*.dart"` — CoachContext ne doit PAS contenir ces champs bruts | ☐ |
| **J13** | OCR: images supprimées après extraction | Vérifier flux document_scan — original supprimé, jamais stocké | ☐ |
| **J14** | Langage conditionnel partout | Textes projections: "pourrait", "envisager", "dans ce scénario simulé" — jamais affirmatif | ☐ |
| **J15** | Références légales correctes | Chaque calcul cite le bon article: LPP art. 14-16, LAVS art. 21-40, LIFD art. 38, etc. | ☐ |

#### Findings connus

```
[P1] LEGAL_RELEASE_CHECK.md — 8 items non cochés
- Fichier: LEGAL_RELEASE_CHECK.md:31-57
- Commande: grep -c "\[ \]" LEGAL_RELEASE_CHECK.md
- Attendu: 0 items unchecked pour features livrées
- Constaté: 8 checkboxes ouvertes (§ 6 Arbitrage, § 7 Coach, § 8 Data Acquisition)
- Fix: auditer chaque item, cocher si conforme ou créer ticket P0
```

```
[P2] Terme "meilleur" dans texte user-facing
- Fichier: apps/mobile/lib/screens/concubinage_screen.dart:669
- Commande: grep -n "meilleur" apps/mobile/lib/screens/concubinage_screen.dart
- Attendu: i18n key + wording neutre ("aucune option n'est universellement préférable")
- Constaté: Hardcoded "Aucune option n'est universellement meilleure"
- Fix: migrer vers ARB key + reformuler sans superlatif
```

---

### ÉQUIPE 3 : UX & DESIGN SYSTEM

**Périmètre**: 100 screens + 198 widgets + navigation + i18n + accessibilité

#### Grille d'audit

| # | Gate | Commande de vérification | PASS/FAIL |
|---|------|--------------------------|-----------|
| **U1** | Zéro hardcoded colors | `grep -rn "Color(0x\|Colors\." apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"` — hors `theme/colors.dart` = P1 | ☐ |
| **U2** | Zéro hardcoded strings FR | `grep -rn "'[A-ZÀÂÉÈÊËÏÎÔÙÛÇ][a-zàâéèêëïîôùûç]" apps/mobile/lib/screens/ --include="*.dart"` — chaque string littérale FR visible user = P1 | ☐ |
| **U3** | i18n 6 langues complètes | Compter les keys dans chaque ARB: `wc -l apps/mobile/lib/l10n/app_*.arb` — toutes doivent avoir le même nombre (±5) | ☐ |
| **U4** | Zéro Navigator.push | `grep -rn "Navigator\.\(push\|of\)" apps/mobile/lib/ --include="*.dart"` — tout doit utiliser GoRouter | ☐ |
| **U5** | Charte L1: CHF/mois d'abord | Chaque écran de projection montre le montant mensuel en hero (36pt Montserrat W800). Vérifier les 10 écrans principaux | ☐ |
| **U6** | Charte L2: Avant → Après | Chaque simulateur montre un delta (situation actuelle vs changement). Pas de résultat isolé | ☐ |
| **U7** | Charte L3: 3 niveaux max | Aucun écran n'affiche > 6 composants sans hiérarchie. Vérifier scroll length sur les plus longs | ☐ |
| **U8** | Charte L6: Chiffre-choc en entrée | Chaque écran de résultat commence par 1 nombre hook + phrase percutante | ☐ |
| **U9** | MintColors.* palette respectée | Vérifier palette émotionnelle: vert=sérénité, orange=attention, rouge=alerte, bleu=info, purple=couple, gold=progression | ☐ |
| **U10** | Fonts: Montserrat headings, Inter body | `grep -rn "fontFamily\|GoogleFonts\." apps/mobile/lib/ --include="*.dart"` — vérifier cohérence | ☐ |
| **U11** | SliverAppBar avec gradient | `grep -rn "AppBar\|SliverAppBar" apps/mobile/lib/screens/ --include="*.dart"` — vérifier que chaque écran principal utilise SliverAppBar + MintColors.primary gradient | ☐ |
| **U12** | 1 écran = 1 intention | Audit visuel des 20 écrans les plus complexes — pas de surcharge cognitive | ☐ |
| **U13** | Hypothèses visibles et éditables | Chaque simulateur/arbitrage montre les hypothèses utilisées ET permet de les modifier | ☐ |
| **U14** | Sensitivity analysis | Chaque arbitrage inclut "Si X change de Y%, le résultat s'inverse" | ☐ |
| **U15** | Responsive layout | Tester sur iPhone SE (375px), iPhone 16 Pro Max (430px), iPad mini (768px) — pas de overflow | ☐ |
| **U16** | Accents FR obligatoires | `grep -rn "impot\b\|etre\b\|prevoyance\b\|retraite\b" apps/mobile/lib/l10n/app_fr.arb` — sans accent = P1 | ☐ |
| **U17** | Non-breaking spaces | Avant `!`, `?`, `:`, `;`, `%` en français — `\u00a0` obligatoire | ☐ |
| **U18** | PDF export fonctionnel | 5 simulateurs ont un TODO "PDF export" — documenter le statut réel | ☐ |

#### Findings connus

```
[P1] Navigator.push dans fullscreen_chart_wrapper
- Fichier: apps/mobile/lib/widgets/fullscreen_chart_wrapper.dart:48-59
- Commande: grep -n "Navigator" apps/mobile/lib/widgets/fullscreen_chart_wrapper.dart
- Attendu: GoRouter navigation (context.push ou context.go)
- Constaté: Navigator.of(context).push(MaterialPageRoute<void>(...))
- Fix: migrer vers GoRouter avec route dédiée pour fullscreen chart
```

```
[P1] Colors.white hardcodé dans naissance_screen
- Fichier: apps/mobile/lib/screens/naissance_screen.dart:129,139,157,221,245,300,349,403
- Commande: grep -n "Colors\." apps/mobile/lib/screens/naissance_screen.dart
- Attendu: MintColors.* ou Theme.of(context)
- Constaté: 8 occurrences de Colors.white
- Fix: remplacer par MintColors.surface ou MintColors.onPrimary selon contexte
```

```
[P1] ~40 écrans avec strings FR hardcodées (i18n manquant)
- Fichier: multiples (voir liste S45 dans MEMORY.md)
- Commande: grep -rn "Text('" apps/mobile/lib/screens/ --include="*.dart" | head -50
- Attendu: S.of(context)!.keyName pour TOUT texte visible
- Constaté: budget_waterfall_painter, narrative_header, couple_patrimoine_card, conjoint_invitation_card, futur_projection_card, financial_summary_screen + ~34 autres
- Fix: migration i18n systématique par batch de 5 écrans
```

---

### ÉQUIPE 4 : 3 PILIERS & CONTENU ÉDUCATIF

**Périmètre**: 58 inserts éducatifs + wizard questions + textes pédagogiques + références légales

#### Grille d'audit

| # | Gate | Commande de vérification | PASS/FAIL |
|---|------|--------------------------|-----------|
| **E1** | 58 inserts éducatifs: contenu correct | Relire chaque insert dans `education/inserts/` — vérifier exactitude des chiffres, références légales, et absence de conseil | ☐ |
| **E2** | Références légales à jour 2025/2026 | Chaque insert cite l'article de loi correct (LPP, LAVS, OPP3, LIFD, etc.). Vérifier contre les textes en vigueur | ☐ |
| **E3** | Constantes dans inserts = constantes centralisées | Tout montant dans un insert (22'680, 7'258, etc.) doit correspondre exactement aux valeurs dans `social_insurance.py` | ☐ |
| **E4** | Pas de conseil déguisé dans les inserts | Aucun insert ne dit "il faut", "vous devriez", "la meilleure stratégie". Ton éducatif uniquement | ☐ |
| **E5** | Couverture des 18 life events | Chaque life event a au minimum 1 insert éducatif pertinent. Lister les manques | ☐ |
| **E6** | Couverture des 8 archetypes | Les inserts mentionnent les spécificités: expat (totalisation), frontalier (impôt source), indépendant (3a max 36'288), etc. | ☐ |
| **E7** | Wizard questions cohérentes | Chaque question du wizard a un insert explicatif. L'insert correspond à la question posée | ☐ |
| **E8** | Pilier 1 (AVS) — contenu exact | Taux 10.60%, rente max 30'240/an, 44 années complètes, bonification éducative, splitting divorce | ☐ |
| **E9** | Pilier 2 (LPP) — contenu exact | Seuil 22'680, coordination 26'460, conversion 6.8%, bonifications par âge, EPL 20'000 min, blocage 3 ans | ☐ |
| **E10** | Pilier 3a — contenu exact | Salarié LPP: 7'258/an, indep sans LPP: 20% revenu net max 36'288/an, déductible du revenu imposable | ☐ |
| **E11** | Hypothèque — contenu exact | Taux théorique 5%, amortissement 1%/an, frais 1%/an, charges max 1/3 revenu, fonds propres 20% | ☐ |
| **E12** | Impôt retrait capital — barème correct | 0-100k ×1.00, 100-200k ×1.15, 200-500k ×1.30, 500k-1M ×1.50, 1M+ ×1.70 | ☐ |
| **E13** | Pas de promesse de rendement | Aucun insert ne mentionne un rendement attendu sans scénarios (Bas/Moyen/Haut) | ☐ |
| **E14** | Multilangue: inserts DE disponibles | Vérifier la couverture des variantes linguistiques dans `education/inserts/` | ☐ |
| **E15** | Chômage (AC) — durée correcte | Standard 400j ≥22 mois cotisation <55 ans. Senior 520j ≥55 ans. PAS 260j pour les 25-54 | ☐ |

---

### ÉQUIPE 5 : DEVOPS & QUALITÉ

**Périmètre**: CI/CD + tests + linting + sécurité + performance

#### Grille d'audit

| # | Gate | Commande de vérification | PASS/FAIL |
|---|------|--------------------------|-----------|
| **D1** | Backend tests green | `cd services/backend && python3 -m pytest tests/ -q` — 0 failures | ☐ |
| **D2** | Flutter analyze clean | `cd apps/mobile && flutter analyze` — 0 errors, 0 warnings | ☐ |
| **D3** | Flutter tests green | `cd apps/mobile && flutter test` — 0 failures | ☐ |
| **D4** | CI workflow fonctionnel | Vérifier `.github/workflows/ci.yml` — dernier run green sur main | ☐ |
| **D5** | Deploy workflow fonctionnel | Vérifier `.github/workflows/deploy-backend.yml` — staging + prod OK | ☐ |
| **D6** | Healthcheck prod | `curl https://mint-production-3a41.up.railway.app/api/v1/health` → `{"status":"ok"}` | ☐ |
| **D7** | Zéro secrets committed | `grep -rn "sk-\|IBAN\|password\|secret\|token" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py"` — hors configs | ☐ |
| **D8** | Railway config correct | `railway.json` a `"builder": "DOCKERFILE"` (sinon Railpack fail) | ☐ |
| **D9** | TODOs critiques inventoriés | `grep -rn "TODO\|FIXME\|HACK" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py"` — classer chaque P0-P3 | ☐ |
| **D10** | Couverture tests backend | 12/98 services testés → liste des 86 manquants classés par criticité | ☐ |
| **D11** | Couverture tests Flutter | Vérifier ratio screens testés vs total (100 screens) | ☐ |
| **D12** | Pydantic v2 pur | `grep -rn "class Config:" services/backend/ --include="*.py"` — 0 résultats (v1 = P1) | ☐ |
| **D13** | Auth placeholder résolu | `grep -rn "user_id=1\|user_id = 1" services/backend/ --include="*.py"` — 0 résultats | ☐ |
| **D14** | OpenAPI + SOT synchronisés | Comparer `tools/openapi/` et `SOT.md` — aucune divergence | ☐ |
| **D15** | TestFlight opérationnel | Dernier build TestFlight successful, Fastlane Match configuré | ☐ |

#### Findings connus

```
[P2] Auth placeholder user_id=1
- Fichier: services/backend/app/routes/wizard.py:79
- Commande: grep -n "user_id=1" services/backend/app/routes/wizard.py
- Attendu: Depends(get_current_user) ou système auth
- Constaté: user_id=1 hardcodé avec TODO
- Fix: implémenter auth middleware ou session-based user_id
```

```
[P1] 86/98 services backend sans tests
- Fichier: services/backend/app/services/ (complet)
- Attendu: minimum 10 tests par service (DoD § 4)
- Constaté: seulement 12 services ont des tests
- Fix: sprint dédié testing — prioriser: disability_gap, divorce_simulator, housing_sale, lpp_conversion, succession_simulator, expat, frontalier
```

```
[P2] 5 simulateurs sans PDF export
- Fichiers: simulator_compound_screen.dart:44, consumer_credit_screen.dart:47, debt_risk_check_screen.dart:45, simulator_leasing_screen.dart:42, simulator_3a_screen.dart:88
- Commande: grep -rn "TODO.*PDF\|TODO.*pdf" apps/mobile/lib/screens/ --include="*.dart"
- Attendu: Export PDF fonctionnel avec disclaimers
- Constaté: TODO placeholder, pas d'implémentation
- Fix: implémenter ou retirer le bouton si feature non prévue V1
```

---

## PHASE 2 — CONVERGENCE (toutes les équipes ensemble)

### Protocole de convergence

**Durée**: 2h max
**Format**: Chaque équipe présente ses 3 findings P0/P1 les plus critiques (5 min/équipe)

#### Matrice de convergence transversale

Chercher les **problèmes systémiques** — quand un finding touche ≥ 2 équipes :

| Pattern transversal | Équipes concernées | Exemple MINT |
|--------------------|--------------------|--------------|
| **Calcul faux + wording faux** | Actuariat + Juridique | Un taux LPP incorrect dans le code ET dans l'insert éducatif |
| **Calcul correct + affichage faux** | Actuariat + UX | Le backend calcule bien mais le widget arrondit mal ou inverse un signe |
| **Compliance OK code + compliance KO texte** | Juridique + 3 Piliers | Le ComplianceGuard filtre mais un insert éducatif contient "garanti" |
| **Test absent + calcul critique** | DevOps + Actuariat | Service de divorce_simulator sans test ET utilisé en production |
| **i18n manquant + texte non-conforme** | UX + Juridique | String hardcodée qui en plus contient un terme banni |
| **Constante drift backend↔Flutter** | Actuariat + DevOps | Valeur correcte en Python mais obsolète en Dart (ou inversement) |

#### Questions de convergence obligatoires

1. **Y a-t-il un calcul financier faux en production ?** (Actuariat → tous)
2. **Y a-t-il un texte non-conforme visible par l'utilisateur ?** (Juridique → tous)
3. **Y a-t-il un écran qui ne fonctionne pas sur petit device ?** (UX → tous)
4. **Y a-t-il un insert éducatif avec une info obsolète ?** (3 Piliers → tous)
5. **Y a-t-il un service critique sans test ?** (DevOps → tous)
6. **Y a-t-il un finding qui touche ≥ 2 équipes ?** (Team Lead → tous)

---

## PHASE 3 — RE-AUDIT CIBLÉ

### Scope

Uniquement les P0/P1 corrigés → validation croisée par une équipe DIFFÉRENTE de celle qui a fixé.

### Protocole

```
1. Pour chaque P0/P1 fixé:
   a. L'équipe qui a trouvé le bug VÉRIFIE le fix (commande de repro → PASS)
   b. Une équipe ADJACENTE vérifie l'absence d'effets de bord:
      - Fix actuariat → UX vérifie l'affichage
      - Fix juridique → 3 Piliers vérifie la cohérence éducative
      - Fix UX → DevOps vérifie les tests
      - Fix 3 Piliers → Juridique vérifie la compliance
      - Fix DevOps → Actuariat vérifie que les calculs n'ont pas bougé

2. Re-run des suites de tests complètes:
   - pytest tests/ -q (backend)
   - flutter analyze + flutter test (mobile)

3. Sign-off: chaque équipe signe SON périmètre "PASS" ou liste les findings restants
```

---

## ANNEXE A — INVENTAIRE ACTUEL MINT (snapshot 2026-03-13)

| Composant | Quantité | Couvert par tests |
|-----------|----------|-------------------|
| Screens Flutter | 100 | ~30% (estimé) |
| Services Flutter | 122 | ~40% (via integration) |
| Widgets Flutter | 198 | ~20% (estimé) |
| Services Backend | 98 | **12%** (12/98) |
| Tests Flutter | 216 | — |
| Tests Backend | 84 | — |
| Inserts éducatifs | 58 | Non testable auto |
| ARB keys (fr) | ~1880 | — |
| Docs stratégiques | 10 | — |
| Legal | 5 | — |
| ADR | 8 | — |
| TODOs/FIXME/HACK | 19 | — |

## ANNEXE B — COMMANDES RAPIDES (copier-coller)

```bash
# === ACTUARIAT ===
# Drift constantes
grep -rn "22680\|26460\|7258\|36288\|30240" apps/mobile/lib/services/ --include="*.dart" | grep -v constants/ | grep -v financial_core/
grep -rn "22680\|26460\|7258\|36288\|30240" services/backend/app/services/ --include="*.py" | grep -v constants/

# _calculate hors financial_core
grep -rn "_calculate" apps/mobile/lib/services/ --include="*.dart" | grep -v financial_core/

# === JURIDIQUE ===
# Termes bannis
grep -rn "garanti\|\"certain\"\|assuré\|sans risque" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"
grep -rn "\"optimal\"\|\"meilleur\"\|\"parfait\"\|\"conseiller\"" apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart"

# Comparaison sociale
grep -rn "top [0-9]\|moyenne suisse\|percentile\|comparé aux" apps/mobile/lib/ --include="*.dart"

# Données sensibles loggées
grep -rn "print(\|debugPrint(" apps/mobile/lib/services/ --include="*.dart"

# === UX ===
# Hardcoded colors
grep -rn "Color(0x\|Colors\." apps/mobile/lib/screens/ apps/mobile/lib/widgets/ --include="*.dart" | grep -v "// " | grep -v test

# Navigator.push
grep -rn "Navigator\.\(push\|of\)" apps/mobile/lib/ --include="*.dart"

# Hardcoded French strings (heuristic)
grep -rn "Text('" apps/mobile/lib/screens/ --include="*.dart" | grep -v "Text(S\.\|Text(widget\.\|Text(state\.\|Text(format"

# i18n key count per language
for f in apps/mobile/lib/l10n/app_*.arb; do echo "$f: $(grep -c '"@' $f || echo 0) keys"; done

# === DEVOPS ===
# All tests
cd services/backend && python3 -m pytest tests/ -q && cd ../..
cd apps/mobile && flutter analyze && flutter test && cd ../..

# TODOs
grep -rn "TODO\|FIXME\|HACK" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py"

# Secrets leak check
grep -rn "sk-\|Bearer \|password.*=\|secret.*=" apps/mobile/lib/ services/backend/app/ --include="*.dart" --include="*.py" | grep -v "test\|example\|mock"

# Auth placeholders
grep -rn "user_id.*=.*1\b" services/backend/ --include="*.py"

# Pydantic v1 remnants
grep -rn "class Config:" services/backend/ --include="*.py"

# Healthcheck prod
curl -s https://mint-production-3a41.up.railway.app/api/v1/health
```

## ANNEXE C — MATRICE RACI

| Activité | Actuariat | Juridique | UX | 3 Piliers | DevOps | Team Lead |
|----------|:---------:|:---------:|:--:|:---------:|:------:|:---------:|
| Constantes correctes | **R** | I | I | C | A | I |
| Calculs golden couple | **R** | I | I | C | A | I |
| Termes bannis | C | **R** | I | C | I | A |
| Disclaimers | I | **R** | C | I | A | I |
| Charte MINT (7 lois) | I | I | **R** | C | I | A |
| i18n complétude | I | I | **R** | I | A | I |
| Inserts éducatifs | C | C | I | **R** | I | A |
| Références légales | C | **R** | I | **R** | I | A |
| Tests & CI | I | I | I | I | **R** | A |
| Sécurité & secrets | I | C | I | I | **R** | A |
| Convergence | C | C | C | C | C | **R** |

> R = Responsible, A = Accountable, C = Consulted, I = Informed

---

> **Ce document est vivant.** Après chaque audit, mettre à jour les findings et marquer les gates PASS/FAIL.
> Prochain audit planifié: ____________
