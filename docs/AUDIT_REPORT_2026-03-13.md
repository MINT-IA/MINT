# MINT — Rapport d'Audit Croisé Complet

> **Date** : 2026-03-13
> **Branche** : `main`
> **Dernier commit** : `7d746da fix(ci): TestFlight pre-checkout steps need working-directory override`
> **Working tree** : dirty (74 fichiers modifiés — travail en cours)
> **Méthode** : 5 équipes parallèles × 15 gates = 75 gates mécaniques

---

## TABLEAU DE SYNTHÈSE

```
╔══════════════════════════════╦══════╦══════╦═══════════════════════════════════╗
║ Équipe                       ║ PASS ║ FAIL ║ Findings P0                       ║
╠══════════════════════════════╬══════╬══════╬═══════════════════════════════════╣
║ Actuariat & Calculs          ║ 11   ║  4   ║ Constants hardcodées backend (A4) ║
║ Juridique & Compliance       ║ 13   ║  2   ║ Comparaison sociale "Top X%" (J3) ║
║ UX & Design System           ║  5   ║  7*  ║ 1471 couleurs hardcodées (U1)     ║
║ 3 Piliers & Éducatif         ║ 11   ║  4   ║ Taux ajournement AVS faux (E12)   ║
║ DevOps & Qualité             ║ 12   ║  3   ║ Auth user_id=1 hardcodé (D7)      ║
╠══════════════════════════════╬══════╬══════╬═══════════════════════════════════╣
║ TOTAL                        ║ 52   ║ 20   ║ 5 findings P0                     ║
╚══════════════════════════════╩══════╩══════╩═══════════════════════════════════╝

* UX : 3 gates additionnelles WARN/INFO (non comptées comme FAIL strict)
```

---

## SCORE GLOBAL

```
MINT HEALTH SCORE: 52/75 gates PASS (69%)

  Actuariat :  11/15 ( 73%)
  Juridique :  13/15 ( 87%)
  UX :          5/15 ( 33%)  ← point faible
  3 Piliers :  11/15 ( 73%)
  DevOps :     12/15 ( 80%)

VERDICT: ██ RED ██
  Raison : 5 findings P0 + score < 70%
```

---

## FINDINGS P0 — BLOQUANTS (fix avant tout merge)

### P0-1 : Comparaison sociale "Top X%" (J3 — Juridique)
- **Fichiers** : `apps/mobile/lib/widgets/coach/benchmark_card.dart`, `apps/mobile/lib/services/benchmark_service.dart`
- **Constat** : Affiche "Top ${percentile}%" et compare l'utilisateur aux "autres Suisses" par tranche d'âge
- **Violation** : CLAUDE.md § 6 — "top 20% des Suisses → BANNED. Compare only to user's own past."
- **Fix** : Remplacer par comparaison temporelle (progression personnelle) ou supprimer le benchmark social

### P0-2 : Taux d'ajournement AVS faux dans insert éducatif (E12 — 3 Piliers)
- **Fichier** : `education/inserts/concepts/retraite_anticipee_ajournement.md`
- **Constat** : Insert dit 2 ans = +10.8%, 3 ans = +17.1%, 4 ans = +24.0%
- **Source de vérité** : `social_insurance.py` dit 2 ans = +10.6%, 3 ans = +16.4%, 4 ans = +22.7%
- **Fix** : Aligner l'insert sur les valeurs backend

### P0-3 : Constants hardcodées dans 3 services backend (A4 — Actuariat)
- **Fichiers** :
  - `services/backend/app/services/family/naissance_service.py:83-97` — LPP_SEUIL_ENTREE, LPP_DEDUCTION_COORDINATION, PLAFOND_3A redéclarés
  - `services/backend/app/services/independants/pillar_3a_indep_service.py:25-26` — PLAFOND_3A_AVEC/SANS_LPP redéclarés
  - `services/backend/app/services/pillar_3a_deep/real_return_service.py:32-33` — PLAFOND_3A redéclarés
- **Risque** : Si `social_insurance.py` est mis à jour, ces services resteront sur les anciennes valeurs
- **Fix** : Remplacer par `from app.constants.social_insurance import ...`

### P0-4 : 1471 couleurs hardcodées (U1 — UX)
- **Constat** : 9 `Color(0x...)` + ~1462 `Colors.*` dans screens/widgets
- **Fichiers principaux** : `portfolio_screen.dart`, `stop_rule_callout.dart`, `landing_screen.dart`, `smart_shortcuts`, `retirement_hero_zone`
- **Violation** : CLAUDE.md § 7 — "NEVER hardcode hex, always MintColors.*"
- **Fix** : Migration systématique vers `MintColors.*` (effort significatif)

### P0-5 : Auth placeholder user_id=1 (D7 — DevOps)
- **Fichier** : `services/backend/app/routes/wizard.py:79`
- **Constat** : `user_id=1, # TODO: Get from auth` — tous les utilisateurs partagent le même ID
- **Risque** : Si endpoint exposé en prod, données mélangées entre utilisateurs
- **Fix** : Implémenter auth middleware ou session-based user_id

---

## FINDINGS P1 — CRITIQUES (fix dans le sprint courant)

### P1-1 : 121 strings FR hardcodées dans screens (U3 — UX)
- **Constat** : 121 occurrences de `Text('...')` avec strings littérales FR au lieu de `S.of(context)!.key`
- **Impact** : L'app ne peut pas fonctionner en DE/EN/ES/IT/PT sur ces écrans
- **Fix** : Migration i18n par batch de 10 écrans

### P1-2 : 16 items LEGAL_RELEASE_CHECK non cochés (J4 — Juridique)
- **Fichier** : `LEGAL_RELEASE_CHECK.md`
- **Constat** : 16 checkboxes ouvertes dont ~10 concernent des features déjà livrées (arbitrage, BYOK, document scan, snapshots)
- **Fix** : Auditer chaque item, cocher si conforme ou créer ticket

### P1-3 : Constants hardcodées dans 3 services Flutter (A3 — Actuariat)
- **Fichiers** : `segments_service.dart:94`, `pulse_hero_engine.dart:244` (7258), `forecaster_service.dart:529` (7258/12)
- **Fix** : Importer depuis `social_insurance.dart`

### P1-4 : Projections sans confidenceScore (A10 — Actuariat)
- **Fichiers** : `financial_report_service.dart`, `forecaster_service.dart`
- **Violation** : CLAUDE.md § 5 — "confidenceScore mandatory on ALL projections"
- **Fix** : Ajouter confidenceScore + enrichmentPrompts aux retours de ces services

### P1-5 : 15 espaces simples avant ponctuation FR (U6 — UX)
- **Fichier** : `apps/mobile/lib/l10n/app_fr.arb`
- **Constat** : "Bienvenue !", "Bravo !" etc. avec espace simple au lieu de `\u00a0`
- **Fix** : Rechercher-remplacer ` !` par `\u00a0!` dans app_fr.arb

### P1-6 : Font Outfit non autorisée (U7 — UX)
- **Constat** : 118 usages de `GoogleFonts.outfit()` — seuls Montserrat + Inter sont dans la charte
- **Fix** : Migrer vers Montserrat ou Inter selon le contexte

### P1-7 : 5 life events sans insert éducatif (E10 — 3 Piliers)
- **Manquants** : deathOfRelative, newJob, jobLoss, inheritance, countryMove
- **Fix** : Créer 5 inserts dédiés

### P1-8 : Aucun insert chômage avec durées LACI (E6 — 3 Piliers)
- **Risque** : 260j affiché au lieu de 400j standard (piège audit connu)
- **Fix** : Créer `q_job_loss.md` avec durées correctes (400j standard, 520j senior)

### P1-9 : q_retirement.md dit "43 années femme" (E2 — 3 Piliers)
- **Fichier** : `education/inserts/q_retirement.md:66`
- **Constat** : Après AVS 21, la durée de cotisation complète = 44 ans pour tous
- **Fix** : Corriger "43" → "44" avec note sur période transitoire

### P1-10 : 153 erreurs Ruff backend (D14 — DevOps)
- **Constat** : Principalement imports non utilisés
- **Fix** : `ruff check . --fix`

### P1-11 : 8 Navigator.push au lieu de GoRouter (U2 — UX)
- **Fichiers principaux** : `fullscreen_chart_wrapper.dart`, `document_scan_screen.dart`, `avs_guide_screen.dart`, `extraction_review_screen.dart`
- **Fix** : Migrer vers `context.push()` / `context.go()`

### P1-12 : ARB template FR 124 lignes plus court que les traductions (U4 — UX)
- **Constat** : fr=4268 lignes vs en/de/es/it/pt=4392 — le template devrait avoir au moins autant de keys
- **Fix** : Auditer les keys manquantes dans le template FR

### P1-13 : CGU/Mentions légales avec champs "[à compléter]" (J10 — Juridique)
- **Fichiers** : `legal/CGU.md`, `legal/MENTIONS_LEGALES.md`
- **Constat** : Forme juridique, siège social, IDE/CHE non remplis
- **Fix** : Compléter avec les informations légales de l'entité

---

## FINDINGS P2 — IMPORTANTS (sprint suivant)

| # | Finding | Équipe | Fichier(s) |
|---|---------|--------|-----------|
| P2-1 | 5 simulateurs sans PDF export (TODO stubs) | UX/DevOps | compound, consumer_credit, leasing, debt_risk, 3a |
| P2-2 | Lauren rachat_max (52949) non testé | Actuariat | Tests golden couple |
| P2-3 | ~60 debugPrint dans services (pas de logging framework) | Juridique/DevOps | Multiples services |
| P2-4 | SliverAppBar non utilisé sur plusieurs écrans | UX | budget, succession, consent, data_block |
| P2-5 | Seulement 13 checks responsive sur ~100 écrans | UX | Multiples |
| P2-6 | 22 TODOs/FIXME/HACK dans le code | DevOps | Multiples |
| P2-7 | Couverture multilingue inserts faible (11 DE, 0 EN) | 3 Piliers | education/inserts/ |
| P2-8 | Archetypes expat_us et expat_non_eu sans insert dédié | 3 Piliers | education/inserts/ |
| P2-9 | 89 StatefulWidgets dans screens (review shared state) | UX | Multiples |
| P2-10 | 1400 infos lint Flutter (prefer_const) | DevOps | Multiples |

---

## FINDINGS TRANSVERSAUX (touchent ≥ 2 équipes)

### TRANSVERSAL 1 : Constante drift backend ↔ Flutter ↔ Éducatif
- **Équipes** : Actuariat + 3 Piliers + DevOps
- **Pattern** : Les taux d'ajournement AVS sont faux dans l'insert éducatif (E12), et 3 services backend redéclarent des constantes localement (A4). Si `social_insurance.py` est mis à jour, 3 services backend + 1 insert éducatif + 3 services Flutter resteront désynchronisés.
- **Risque** : Mise à jour annuelle OFAS (septembre) → divergence silencieuse
- **Fix systémique** : Script de validation automatique des constantes (CI gate)

### TRANSVERSAL 2 : i18n manquant + termes potentiellement non-conformes
- **Équipes** : UX + Juridique
- **Pattern** : 121 strings FR hardcodées (U3) + certaines contiennent des termes qui échappent au ComplianceGuard car ils ne passent pas par le flux i18n standard
- **Risque** : Les strings hardcodées ne sont pas filtrées par les outils de compliance automatiques
- **Fix systémique** : Lint rule Flutter interdisant `Text('...')` avec littéral FR

### TRANSVERSAL 3 : Comparaison sociale + absence de test
- **Équipes** : Juridique + DevOps
- **Pattern** : Le benchmark social "Top X%" (J3/P0) n'a pas de test de compliance dédié
- **Fix** : Ajouter un test adversarial dans ComplianceGuard pour détecter les patterns de comparaison sociale

### TRANSVERSAL 4 : Calculs critiques sans confidenceScore
- **Équipes** : Actuariat + UX
- **Pattern** : `financial_report_service` et `forecaster_service` projettent sans confidenceScore (A10), et l'UX n'affiche donc pas de bande d'incertitude
- **Risque** : L'utilisateur voit un chiffre précis sur une projection incertaine
- **Fix** : Ajouter confidenceScore aux deux services + afficher la bande d'incertitude dans les widgets

---

## DÉTAIL PAR ÉQUIPE

### Actuariat & Calculs (11/15 PASS)

| Gate | Résultat | Description |
|------|----------|-------------|
| A1 | PASS | Constantes backend correctes |
| A2 | PASS | Flutter = backend (pas de drift) |
| A3 | **FAIL** | 3 services Flutter hardcodent des constantes |
| A4 | **FAIL** | 3 services backend redéclarent des constantes |
| A5 | PASS | Bonification LPP correcte (7/10/15/18%) |
| A6 | PASS | Tax progressive correcte |
| A7 | PASS | _calculate* = domain logic uniquement |
| A8 | PASS | AVS ajoute les années futures |
| A9 | PASS | Cap 150% = mariés uniquement |
| A10 | **FAIL** | financial_report + forecaster sans confidenceScore |
| A11 | PASS | 8 archetypes définis et utilisés |
| A12 | PASS | AC 400j standard, 520j senior |
| A13 | PASS | Pas de double-taxation capital |
| A14 | PASS | Golden Julien testé |
| A15 | **FAIL** | Lauren rachat_max (52949) non testé |

### Juridique & Compliance (13/15 PASS)

| Gate | Résultat | Description |
|------|----------|-------------|
| J1 | PASS | Termes bannis = tous dans disclaimers négatifs |
| J2 | PASS | Pas de ranking d'options |
| J3 | **FAIL** | Comparaison sociale "Top X%" dans benchmark |
| J4 | **FAIL** | 16 items LEGAL_RELEASE_CHECK non cochés |
| J5 | PASS | ComplianceGuard couvre les 8 termes |
| J6 | PASS | Read-only confirmé |
| J7 | PASS | Pas de données sensibles loggées |
| J8 | PASS | CoachContext sans montants exacts |
| J9 | PASS | Disclaimers backend présents |
| J10 | PASS | CGU/Privacy/Disclaimer cohérents (avec "[à compléter]") |
| J11 | PASS | Langage conditionnel respecté |
| J12 | PASS | Arbitrage côte à côte |
| J13 | PASS | Hypothèses visibles et éditables |
| J14 | PASS | Sensitivity analysis incluse |
| J15 | PASS | BYOK consent avec neverSent |

### UX & Design System (5/15 PASS)

| Gate | Résultat | Description |
|------|----------|-------------|
| U1 | **FAIL** | ~1471 couleurs hardcodées |
| U2 | **FAIL** | 8 Navigator.push au lieu de GoRouter |
| U3 | **FAIL** | 121 strings FR hardcodées |
| U4 | **FAIL** | ARB FR 124 lignes plus court que traductions |
| U5 | PASS | Accents FR corrects |
| U6 | **FAIL** | 15 espaces simples avant ponctuation |
| U7 | **FAIL** | 118 usages font Outfit non autorisée |
| U8 | PASS | MintColors palette complète |
| U9 | **FAIL** | Mélange AppBar/SliverAppBar |
| U10 | PASS | GoRouter 106 routes centralisées |
| U11 | WARN | 89 StatefulWidgets (review needed) |
| U12 | INFO | 5 PDF exports non implémentés |
| U13 | WARN | 13 checks responsive sur ~100 écrans |
| U14 | PASS | Material 3 activé |
| U15 | PASS | Chiffre-choc pattern implémenté |

### 3 Piliers & Éducatif (11/15 PASS)

| Gate | Résultat | Description |
|------|----------|-------------|
| E1 | PASS | 41 inserts, bonne couverture |
| E2 | PASS* | AVS correct (*reserve: "43 années femme") |
| E3 | PASS | LPP exact |
| E4 | PASS | 3a exact |
| E5 | PASS | Hypothèque exact |
| E6 | **FAIL** | Aucun insert chômage avec durées LACI |
| E7 | PASS | Pas de conseil déguisé |
| E8 | PASS | Pas de promesse de rendement |
| E9 | PASS | 100% des inserts ont des réf. légales |
| E10 | **FAIL** | 5/18 life events sans insert dédié |
| E11 | PASS | Archetypes mentionnés (reserve: expat_us/non_eu) |
| E12 | **FAIL** | Taux ajournement AVS faux (10.8% vs 10.6%) |
| E13 | PASS | 39 q_*.md pour wizard |
| E14 | **FAIL** | 11 DE, 0 EN/ES/IT/PT |
| E15 | PASS | Ton éducatif cohérent |

### DevOps & Qualité (12/15 PASS)

| Gate | Résultat | Description |
|------|----------|-------------|
| D1 | PASS | Backend 3927 passed, 0 failures |
| D2 | PASS | Flutter analyze 0 errors (1400 infos) |
| D3 | PASS | Flutter ~3048+ passed, 0 failures |
| D4 | PASS | Healthcheck prod OK |
| D5 | PASS | Couverture tests 73% |
| D6 | PASS | Pydantic v2 pur |
| D7 | **FAIL** | user_id=1 hardcodé |
| D8 | PASS | Pas de secrets commités |
| D9 | PASS | Railway DOCKERFILE configuré |
| D10 | INFO | 22 TODOs inventoriés |
| D11 | PASS | 3 workflows CI/CD présents |
| D12 | **FAIL** | 74 fichiers dirty (travail en cours) |
| D13 | PASS | OpenAPI canonical existe |
| D14 | **FAIL** | 153 erreurs Ruff |
| D15 | PASS | TestFlight configuré |

---

## PLAN D'ACTION RECOMMANDÉ

### Sprint immédiat (P0 — cette semaine)
1. Supprimer ou réécrire `benchmark_card.dart` + `benchmark_service.dart` (comparaison sociale)
2. Corriger taux ajournement AVS dans `retraite_anticipee_ajournement.md`
3. Remplacer constantes hardcodées par imports dans 3 services backend
4. Remplacer `user_id=1` par auth middleware dans `wizard.py`
5. Commencer migration couleurs hardcodées (top 10 fichiers les plus utilisés)

### Sprint suivant (P1)
6. Migration i18n : 121 strings FR hardcodées
7. Auditer et cocher LEGAL_RELEASE_CHECK.md
8. Ajouter confidenceScore à financial_report_service + forecaster_service
9. Corriger q_retirement.md "43 → 44 années"
10. Créer 5 inserts éducatifs manquants (life events)
11. Compléter CGU/Mentions légales "[à compléter]"
12. `ruff check . --fix` pour les 153 erreurs

### Backlog (P2)
13. Migration complète MintColors (1471 occurrences)
14. Migrer Outfit → Montserrat/Inter (118 usages)
15. SliverAppBar sur tous les écrans principaux
16. PDF export pour 5 simulateurs
17. Logging framework pour remplacer debugPrint
18. Traductions multilingues des inserts éducatifs

---

> **Prochain audit planifié** : après résolution des P0 (re-audit ciblé par équipe croisée)
> **Généré par** : `/audit-complet` — 5 agents parallèles, 75 gates mécaniques
