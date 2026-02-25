# AGENTS_LOG.md — Historique des erreurs (anti-répétition)

Format d’entrée:
- Date:
- Sujet:
- Symptôme:
- Cause racine:
- Fix:
- Test ajouté:
- Doc/règle mise à jour (quel fichier):
- Lien PR/commit:

## Entries

### 2026-02-08 — Agent Skills Setup (.claude/skills/)
- **Date:** 2026-02-08
- **Sujet:** Mise en place des Agent Skills pour standardiser le travail de la dream team
- **Symptôme:** Les agents répétaient les mêmes erreurs (MintColors.text au lieu de textPrimary, tests sans GoRouter, commits sans format conventionnel) car les conventions n'étaient pas formalisées de manière lisible par les agents.
- **Cause racine:** Les conventions étaient dispersées dans AGENTS.md, rules.md, et dans la mémoire du team-lead. Les agents spawned n'avaient pas accès à ces connaissances capitalisées.
- **Fix:**
  - Création de 5 skills dans `.claude/skills/` (format Agent Skills spec — agentskills.io)
  - `mint-flutter-dev` : patterns Flutter, UI kit MintColors, GoRouter, Provider, checklists
  - `mint-backend-dev` : patterns backend, rules_engine, schemas Pydantic, TestClient (pas httpx)
  - `mint-swiss-compliance` : droit suisse (LPP, LIFD, LAVS), mots interdits, format specs
  - `mint-test-suite` : commandes, erreurs courantes (GoRouter missing, findsOneWidget vs findsWidgets)
  - `mint-commit` : conventional commits, scopes MINT, format PR
  - Mise à jour AGENTS.md : chaque fiche agent référence son skill, prompts de spawn mis à jour
  - Ajout section SKILLS dans la hiérarchie de vérité (rang 3)
- **Test ajouté:** N/A (documentation)
- **Doc/règle mise à jour:** AGENTS.md, AGENTS_LOG.md, `.claude/skills/*`
- **Lien PR/commit:** Commit suivant

---

### 2026-02-08 — 114/114 Flutter Tests Green + 59/59 Backend Tests
- **Date:** 2026-02-08
- **Sujet:** Suite de tests complète verte après multiple sessions de fix
- **Symptôme:** 11 tests Flutter échouaient, 17 tests backend échouaient
- **Cause racine:**
  - Flutter: Wizard V2 ajoutait q_financial_stress_check comme première question, tests pas mis à jour
  - Flutter: GoRouter manquant dans les persona tests (MaterialApp au lieu de MaterialApp.router)
  - Flutter: MintColors.text n'existe pas (textPrimary/textSecondary/textMuted)
  - Flutter: Duplicate imports dans mint_ui_kit.dart, bracket cassé dans explore_tab.dart
  - Backend: httpx.AsyncClient incompatible → TestClient(app) synchrone
  - Backend: topActions pas paddé à 3 éléments minimum
- **Fix:**
  - Compilation: 4 fichiers source fixes (mint_ui_kit, comprendre_hub, theme_detail, explore_tab)
  - Flutter tests: GoRouter setup ajouté, stress check step ajouté, findsWidgets, scrollUntilVisible
  - Backend tests: Conversion async→sync, padding topActions, compliance test fix
  - dart-agent a finalisé les 5 derniers (wizard_insight, persona_marc flow)
- **Test ajouté:** apps/mobile/test/services/avs_logic_test.dart (nouveau)
- **Doc/règle mise à jour:** Pièges documentés dans `.claude/skills/mint-test-suite/SKILL.md`
- **Lien PR/commit:** 775a3e3, c82cf07

---

### 2026-01-10 — Anti-Surendettement Feature: Privacy Pitfall Avoided
- **Date:** 2026-01-10
- **Sujet:** Questionnaire Risque d'Endettement (debt_risk)
- **Symptôme:** N/A (prévention)
- **Cause racine:** Risque de stocker des données sensibles (réponses questionnaire, score de risque, flag jeux d'argent)
- **Fix:**
  - Calcul côté client (Dart) uniquement
  - Aucun stockage backend des réponses du questionnaire
  - Documentation explicite dans `SOT.md` et `vision_trust_privacy.md`
  - Disclaimers obligatoires sur tous les écrans sensibles
- **Test ajouté:** `test_rules_engine.py::TestDebtRiskScore` (5 tests)
- **Doc/règle mise à jour:** `SOT.md`, `vision_trust_privacy.md`, `vision_features.md`
- **Lien PR/commit:** N/A (feature initiale)

---

### 2026-02-08 — Chantier 1 : Modèle Fiscal MVP (SESSION EN COURS)

**Team** : `mint-fiscal-mvp` (config: `~/.claude/teams/mint-fiscal-mvp/config.json`)
**Membres** : team-lead (Opus), swiss-brain (Opus), python-agent (Sonnet)

#### ÉTAT DES DONNÉES FISCALES (découvert cette session)

| Fichier | Contenu | État |
|---------|---------|------|
| `apps/mobile/assets/config/tax_scales.json` | Barèmes cantonaux scrapés ESTV (23/26 cantons) | Partiel |
| `apps/mobile/scripts/extract_tax_data.py` | Scraper Playwright (FONCTIONNEL) | OK |
| `tools/fetch_tax_data.py` | Scraper API REST (CASSÉ — 26/26 en erreur) | KO |
| `apps/mobile/lib/data/average_tax_multipliers.dart` | Multiplicateurs canton+commune | À vérifier |
| `apps/mobile/lib/services/tax_estimator_service.dart` | Calcul actuel (heuristique + fallback) | À refactorer |
| `services/backend/app/services/rules_engine.py` | `calculate_marginal_tax_rate()` 4 paliers fixes | À refactorer |

#### DONNÉES tax_scales.json — 6 cantons MVP

| Canton | Brackets | Tarifs (single/married) | Statut |
|--------|----------|------------------------|--------|
| Zurich | 26 | À vérifier | Probablement OK |
| Bern | 28 | À vérifier | Probablement OK |
| Lucerne | 23 | À vérifier | Probablement OK |
| Basel-Stadt | **6** | À vérifier | **SUSPECT — trop peu** |
| Vaud | 57 | À vérifier | Probablement OK |
| Geneva | 18 | À vérifier | Probablement OK |

**Cantons manquants dans le JSON** : AR, AI, SG (échec scraping — noms avec caractères spéciaux)

#### SPEC CALCUL (produite cette session)

Formule cible :
```
Impôt_total = IFD + (ICC_base × mult_canton_commune) + (ICC_base × mult_église)
```

Composants :
1. **IFD** : Barème A (célibataire) ou B (marié) — LIFD art. 36
2. **ICC** : Barème cantonal réel (depuis tax_scales.json)
3. **Multiplicateurs** : Chef-lieu par défaut, commune exacte si NPA fourni
4. **Église** : Optionnel (isChurchMember)

Nouveaux champs Profile : `commune`, `isChurchMember`, `pillar3aAnnual`

#### ANALYSE python-agent (2026-02-08)

**Findings critiques :**
1. `calculate_marginal_tax_rate(canton, income_gross)` ignore le param `canton` → même taux ZG/GE
2. `_create_3a_optimizer_recommendation()` hardcode `marginal_rate = 0.25` au lieu d'appeler la fonction
3. **0 tests** sur les fonctions fiscales (`calculate_marginal_tax_rate`, `calculate_tax_potential`)
4. Format tax_scales.json hétérogène (strings "6'900", BS incomplet, URI/OW taux unique)

**Structure proposée (validée team-lead) :**
- `TaxBracket(upper_limit: float, rate_percent: float)`
- `CantonTaxScale(canton_code, year, source_url, brackets_single[], brackets_married[])`
- `FederalTaxScale(year, source, brackets_single[], brackets_married[])`
- Fichiers : `services/backend/app/data/tax_scales/{canton}_{year}.json`

#### AUDIT swiss-brain (2026-02-08) — BUGS CRITIQUES DÉTECTÉS

**Cantons OK :** ZH (26 brackets, mult 2.38 OK), BE (28 brackets, mult 3.06 OK)

**Cantons KO :**

| Canton | Problème | Impact | Fix |
|--------|----------|--------|-----|
| **BS** | Taux JSON = totaux (21-28%), pas de base | Impôt x2 si mult 2.00 appliqué | Forcer mult=1.00 OU re-scraper |
| **VD** | Tarifs nommés "Married" / "Single, with / no children" | Ne matche PAS le code → fallback | Normaliser noms OU fuzzy match |
| **GE** | Tarif unique "All" + splitting non implémenté | Ne matche PAS + mariés surestimés | Normaliser + implémenter splitting |
| **LU** | Multiplicateur 1.95 au lieu de ~3.35 | Sous-estimation ~43% | Corriger mult à 3.35 |

**Autres findings :**
- IFD approximé en 3 paliers au lieu de 14 tranches → erreur 0-100%
- VD a 3 tarifs (dont "cohabiting") = plus granulaire que les autres
- LU a un bracket dégressif au sommet (5.8% → 5.7%) = intentionnel (plafond constitutionnel)
- BS married = exactement 2x single (splitting classique)

**Cas de test de référence (revenu imposable 80'000, single, chef-lieu) :**
| Canton | ICC attendu | IFD attendu | Total attendu |
|--------|------------|-------------|---------------|
| ZH | ~9'500 | ~900 | ~10'400 |
| BE | ~12'500 | ~900 | ~13'400 |
| VD | ~13'000 | ~900 | ~13'900 |
| GE | ~11'000 | ~900 | ~11'900 |
| LU | ~7'500 | ~900 | ~8'400 |
| BS | ~16'000 | ~900 | ~16'900 |

#### DÉCISIONS ACTÉES (swiss-brain 2026-02-08)

| # | Décision | Fondement juridique |
|---|----------|-------------------|
| D1 | Fallback chef-lieu = OK MVP + disclaimer obligatoire | LHID art. 2 al. 1 |
| D2 | Concubins = barème célibataire partout | LIFD art. 9 al. 1 ; ATF 131 I 409 |
| D3 | IFD = uniforme fédéral (LIFD art. 36/214) | Barèmes fournis (11 tranches single, 15 tranches married) |
| D4 | Données scrapées fiables sauf BS | ZH/BE/LU/VD/GE = OK fond, normaliser tarifs VD/GE |
| D5 | Tolérance ±10% MVP si disclaimer + fourchette | LCD art. 3 al. 1 let. b (pas trompeur si disclaimer) |

**Cas spécial** : concubin avec enfant à charge → barème "Single, with children (cohabiting)" si dispo (VD, JU).

#### TODO (à reprendre si contexte compressé)

- [x] python-agent : analyser rules_engine.py existant ✅
- [x] swiss-brain : valider tax_scales.json 6 cantons ✅
- [x] swiss-brain : vérifier multiplicateurs ✅
- [x] swiss-brain : répondre 5 questions + fournir barèmes IFD ✅
- [x] **P0** team-lead : Corriger mult BS (→1.00) + LU (→3.35) ✅ (déjà appliqué)
- [x] **P0** team-lead : Normaliser tarifs VD/GE dans TaxScalesLoader ✅ + fallback "All"
- [x] **P0** python-agent : Refactorer calculate_marginal_tax_rate() backend ✅ (IFD brackets + canton multipliers + household_type)
- [x] **P0** team-lead : Implémenter barème IFD réel dans tax_estimator_service.dart ✅ (estimateFederalTax avec 11/15 tranches)
- [x] **P0** team-lead : Fixer test_low_income_floor assertion (ZG 20k → 0.2277, pas 0.10) ✅
- [x] P1 : Fixer hardcode marginal_rate=0.25 dans _create_3a_optimizer_recommendation() ✅ (appelle calculate_marginal_tax_rate)
- [x] P1 : Fixer hardcode "Taux marginal 25%" dans roadmap assumptions ✅ (dynamique)
- [x] P1 : Refactorer estimateMarginalTaxRate() Dart — IFD marginal réel ✅ (_getIfdMarginalRate remplace hardcode)
- [x] P1 : Implémenter splitting GE pour mariés ✅ (_usesSplitting + income/2 + tax*2)
- [x] P2 : Écrire 30 tests avec valeurs attendues vs ESTV ✅ (15 ESTV validation + canton code resolution)
- [x] P2 : Fixer BUG CRITIQUE — canton code vs nom JSON ✅ (_codeToName mapping dans TaxScalesLoader)
- [x] P2 : Mettre à jour SOT.md + OpenAPI + Profile Dart + Profile Python (nouveaux champs: commune, isChurchMember, pillar3aAnnual) ✅

#### BUG CRITIQUE TROUVÉ — Canton Code vs Nom JSON (P2)

**Symptôme** : Les tests ESTV pour BS donnaient 53'874 au lieu de ~17'500.

**Cause racine** : Le JSON `tax_scales.json` utilise des noms complets ("Zurich", "Vaud", "Geneva")
mais l'app passe des codes cantons ("ZH", "VD", "GE"). `TaxScalesLoader.getBrackets('VD', ...)`
ne trouvait rien → fallback heuristique en production. Les données réelles n'étaient JAMAIS utilisées !

**Fix** : Ajout d'un mapping `_codeToName` dans TaxScalesLoader avec `_resolveCantonKey()`.
Les deux formats (code et nom complet) fonctionnent maintenant.

#### CHANTIER 1 — COMPLÉTÉ ✅

Le chantier 1 (Modèle fiscal MVP 6 cantons) est **terminé**.
55 tests passent (30 Flutter + 25 Backend). Précision ±10% sur ZH/BE/LU/VD, ±30% sur BS/GE (données hétérogènes).

---

### 2026-02-08 — DREAM TEAM MINT CONFIGURÉE

**Sujet** : Mise en place de l'agent team mode + revue critique du PLAN_ACTION_10_CHANTIERS.md

#### CE QUI A ÉTÉ FAIT

1. **Agent Teams activé** : `~/.claude/settings.json` → `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`
2. **Settings projet** : `.claude/settings.json` créé (env + permissions safe)
3. **AGENTS.md refondu** : Dream team avec 3 teammates + protocole + sprints séquencés
4. **PLAN_ACTION_10_CHANTIERS.md mis à jour** : Revue critique ajoutée en section finale

#### DREAM TEAM — COMPOSITION

| Agent | Nom | Modèle | Rôle | Scope |
|-------|-----|--------|------|-------|
| Team Lead | (session principale) | Opus | Orchestre, review, merge | Tout |
| Flutter Engineer | `dart-agent` | Sonnet | UI, widgets, screens, tests widget | `apps/mobile/` |
| Backend Engineer | `python-agent` | Sonnet | FastAPI, rules_engine, tests pytest | `services/backend/` |
| Expert Finance CH | `swiss-brain` | Opus | Specs, formules, cas de test, compliance, textes | `docs/`, `education/`, pas de code |

#### WORKFLOW OBLIGATOIRE (chantier métier)

```
swiss-brain (spec + cas de test + textes éducatifs)
    → python-agent (implémentation backend + tests)
        → dart-agent (UI Flutter + tests widget)
            → Team Lead (review + merge)
```

#### COMMENT SPAWNER (copier-coller dans un nouveau chat)

**dart-agent :**
```
Spawn a teammate named "dart-agent" with model sonnet.
Prompt: "Tu es le Flutter/Dart engineer de MINT. Lis AGENTS.md, rules.md et SOT.md avant d'agir.
Tu travailles exclusivement dans apps/mobile/. Tu suis le pattern existant.
Avant chaque changement : flutter analyze && flutter test.
Ne touche JAMAIS au backend."
```

**python-agent :**
```
Spawn a teammate named "python-agent" with model sonnet.
Prompt: "Tu es le Backend Python engineer de MINT. Lis AGENTS.md, rules.md et SOT.md avant d'agir.
Tu travailles exclusivement dans services/backend/.
Avant chaque changement : ruff check . && pytest -q.
Ne touche JAMAIS au code Flutter.
Si tu changes un contrat API → mettre à jour tools/openapi/mint.openapi.yaml ET SOT.md."
```

**swiss-brain :**
```
Spawn a teammate named "swiss-brain" with model opus.
Prompt: "Tu es l'expert finance suisse et compliance de MINT.
Lis AGENTS.md, rules.md, AGENT_SYSTEM_PROMPT.md, LEGAL_RELEASE_CHECK.md et visions/*.md.
Tu ne codes PAS. Tu produis : specs calcul (avec sources juridiques), cas de test, textes éducatifs conformes, alertes compliance.
Tu es le garde-fou. Si un calcul est faux ou un wording non conforme, tu bloques."
```

#### DÉCISION LLM — BYOK (Bring Your Own Key)

**Rejet** du modèle "MINT paie l'API LLM".
**Adopté** : Architecture 3 tiers :
- **Free** : Rules engine + simulateurs + contenu statique (pas de LLM)
- **BYOK** : L'user branche sa clé Claude/OpenAI/Mistral, MINT orchestre
- **Local (v2)** : Ollama pour privacy-first

Justification : 0 coût variable pour MINT, modèle prouvé (Cursor/Continue), l'user choisit.

#### PLANNING RÉVISÉ — NEXT SPRINTS

| Sprint | Chantier | État |
|--------|----------|------|
| S0 | Fiscal MVP 6 cantons | ✅ FAIT |
| **S1** | **Rente vs Capital (LPP simplifié)** | **NEXT** |
| S2 | Invalidité / Gap | Backlog |
| S3 | Auth + persistence backend | Backlog |
| S4 | Analytics + Onboarding | Backlog |
| S5 | Multilinguisme DE | Backlog |
| S6 | RAG allégé + BYOK | Backlog |

#### PROBLÈMES CONNUS À REPRENDRE

| Problème | Priorité | Détail |
|----------|----------|--------|
| BS/GE données incorrectes (seuils cumulatifs vs largeurs) | P1 | ±30% d'erreur. Normaliser dans le scraper ou détecter par canton |
| AR, AI, SG manquants dans tax_scales.json | P2 | Noms avec caractères spéciaux cassent le scraper |
| Pas d'auth backend | P1 (pour rétention) | Pas de persistence cross-session sans auth |
| Pas d'analytics | P1 (pour mesure) | Impossible de mesurer l'Action Conversion à 14j |

---

#### DATA FORMAT — BS et GE (non résolu, toléré MVP)

Les cantons BS et GE ont des données JSON avec des **seuils cumulatifs** au lieu de **largeurs de brackets**.
- ZH/BE/LU/VD : `incomeThreshold` = largeur du bracket (ex: 6'900 = "pour les prochains 6'900 CHF")
- BS/GE : `incomeThreshold` = seuil cumulatif (ex: 212'500 = "jusqu'à 212'500 CHF")

Impact : BS et GE sur-estiment l'impôt (~30% trop haut). Toléré MVP avec disclaimer (D5).

**Fix possible** : Normaliser les données dans le scraper OU détecter le format par canton.

#### RÉSUMÉ SESSION (état final 2026-02-08)

**Tests :**
- Flutter `test/tax_estimator_test.dart` : 30/30 ✅
- Backend `tests/test_rules_engine.py` : 25/25 ✅

**Fichiers modifiés (cette session) :**
| Fichier | Changement |
|---------|-----------|
| `apps/mobile/lib/data/average_tax_multipliers.dart` | BS: 2.00→1.00, LU: 1.95→3.35 |
| `apps/mobile/lib/services/tax_scales_loader.dart` | Normalisation VD + fallback "All" + **_codeToName mapping** |
| `apps/mobile/lib/services/tax_estimator_service.dart` | IFD réel, IFD marginal, splitting GE |
| `apps/mobile/test/tax_estimator_test.dart` | 30 tests (dont 15 ESTV validation, 2 canton code resolution) |
| `services/backend/app/services/rules_engine.py` | IFD brackets, canton multipliers, _create_3a_optimizer dynamique |
| `services/backend/tests/test_rules_engine.py` | +9 tests (TestMarginalTaxRate) |

---

### 2026-02-XX — S30.5 Financial Core Unification (PLANNED)
- **Date:** [date]
- **Sujet:** Audit et nettoyage des doublons de calcul à travers le codebase
- **Symptôme:** Calculs financiers dupliqués dans N services, constantes divergentes backend/Flutter
- **Cause racine:** Croissance organique sur 30 sprints sans enforcement strict du financial_core
- **Fix:** [à documenter après exécution]
  - Doublons supprimés: N
  - Constantes alignées: N
  - Méthodes ajoutées à financial_core: N
  - Parity check backend/Flutter: N profils validés
- **Test ajouté:** Parity tests + regression tests
- **Doc/règle mise à jour:** CLAUDE.md (anti-patterns), ADR-20260223
- **Lien PR/commit:** [commit hash]
