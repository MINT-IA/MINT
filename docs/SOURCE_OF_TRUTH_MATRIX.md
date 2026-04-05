# SOURCE OF TRUTH MATRIX

> Dernière mise à jour : 2026-03-27
> Statut : **AUTORITATIF** — Ce document définit quel moteur fait foi, dans quel contexte.
> En cas de divergence code/doc : ce document prime. Si le code contredit, corriger le code.
>
> **⚠️ LEGACY NOTE (2026-04-05):** "chiffre choc" est un legacy term technique.
> Concept canonique : **"premier éclairage"** (voir `docs/MINT_IDENTITY.md`). Migration code à planifier.

---

## 1. Données utilisateur

| Donnée | Source de vérité | Fallback autorisé | Owner | Non-divergence vérifié par |
|---|---|---|---|---|
| **Identité** (âge, canton, statut civil) | `CoachProfile` (local) | Backend `Profile` (sync descendante) | `CoachProfileProvider` | Tests wizard → profile |
| **Revenu** (brut, mois, bonus) | `CoachProfile` | Estimation Bayesienne si absent | `CoachProfileProvider` | Tests golden couple (Julien/Lauren) |
| **Prévoyance** (AVS, LPP, 3a) | `CoachProfile.prevoyance` | `MinimalProfileService` estimation si onboarding | `CoachProfileProvider` | Tests financial_core |
| **Patrimoine** (épargne, immobilier, dettes) | `CoachProfile.patrimoine` + `CoachProfile.dettes` | Aucun — absent = absent | `CoachProfileProvider` | — |
| **Conjoint** | `CoachProfile.conjoint` | Aucun | `CoachProfileProvider` | Tests couple_optimizer |
| **Genre conjoint** | `CoachProfile.conjoint.gender` | Aucun (jamais inféré) | `CoachProfileProvider` | Tests same-sex couple (S57-F4) |

---

## 2. Calculs financiers

| Calcul | Source de vérité | Fallback | Owner | Où vivent les constantes |
|---|---|---|---|---|
| **AVS rente** | `AvsCalculator` (financial_core) | Aucun | `financial_core/avs_calculator.dart` | `constants/social_insurance.dart` + `RegulatoryRegistry` |
| **LPP projection** | `LppCalculator` (financial_core) | Aucun | `financial_core/lpp_calculator.dart` | `constants/social_insurance.dart` + `RegulatoryRegistry` |
| **Fiscalité** | `TaxCalculator` (financial_core) | Aucun | `financial_core/tax_calculator.dart` | `constants/social_insurance.dart` |
| **Monte Carlo** | `MonteCarloService` (financial_core) | Aucun | `financial_core/monte_carlo_service.dart` | — |
| **Budget Snapshot** | `BudgetLivingEngine` | Aucun | `services/budget_living_engine.dart` | — |

### Règle absolue
**Aucun service consommateur ne doit réimplémenter un calcul.** Tout calcul AVS/LPP/fiscal/Monte Carlo passe par `financial_core/`. Si un service a besoin d'un calcul, il importe `financial_core.dart`.

---

## 3. Confiance / scoring

| Score | Source de vérité | Fallback | Contexte d'usage |
|---|---|---|---|
| **Confiance globale** | Backend `EnhancedConfidenceService` (4 axes, geometric mean) | Mobile `EnhancedConfidenceService` (3 axes, weighted) | Feature gates, enrichment ranking, UI bars |
| **Confiance projection** | `ConfidenceScorer` (financial_core, 12 composants) | Aucun | Seuil ≥ 40 pour afficher projections |
| **Confiance chiffre choc** | `ChiffreChocSelector._withConfidence()` | Default `factual` | Mode factuel vs pédagogique dans l'onboarding |
| **FRI** | `FriCalculator` (financial_core, 4 axes) | Aucun | Shadow mode (pas affiché), nourrit FHS |
| **FHS** | `FinancialHealthScoreService` (FRI + temporal) | Aucun | Pulse, streaks, weekly recap |

### Divergences connues et acceptées

| Mobile | Backend | Pourquoi | Risque | Mitigation |
|---|---|---|---|---|
| 3 axes (completeness, accuracy, freshness) | 4 axes (+ understanding) | Mobile n'a pas de tracking literacy côté client | Faible — understanding a un poids mineur | TODO : unifier quand backend confidence est systématiquement appelé |

---

## 4. Onboarding chiffre choc

| Composant | Source de vérité | Fallback | Contrat |
|---|---|---|---|
| **Sélection** | Backend `select_chiffre_choc()` via API `/onboarding/chiffre-choc` | Mobile `ChiffreChocSelector.select()` (local) | Même algorithme : intention × lifecycle × confidence × data |
| **Calcul minimal** | Backend `compute_minimal_profile()` | Mobile `MinimalProfileService.compute()` | Même formules, mêmes constantes via `RegulatoryRegistry` |
| **stress_type** | Envoyé dans request HTTP + passé au local selector | — | Doit influencer les deux chemins identiquement |
| **confidence_mode** | Renvoyé dans response HTTP + calculé localement | Default `factual` | Même logique `_withConfidence` / per-builder |

### Tests de non-divergence

| Test | Fichier | Ce qu'il vérifie |
|---|---|---|
| Backend selector (35 tests) | `tests/test_chiffre_choc.py` | Sélection par stress, lifecycle, confiance, archetype |
| Flutter selector (23 tests) | `test/services/chiffre_choc_selector_test.dart` | Même matrice de cas |
| HTTP contract (16 tests) | `tests/test_onboarding_contract.py` | stress_type round-trip, confidence_mode, camelCase, banned terms |
| **Verrouillage F3** | `test_onboarding_contract.py::test_stress_retraite_with_ok_ratio_returns_income_not_gap` | **Exactement** `retirement_income` (pas `retirement_gap`) |

---

## 5. Coach AI

| Composant | Source de vérité | Fallback | Owner |
|---|---|---|---|
| **Orchestration** | `CoachOrchestrator` | — | `services/coach/coach_orchestrator.dart` |
| **Contexte injecté** | `ContextInjectorService` (profil + budget + nudges + mémoire) | — | `services/coach/context_injector_service.dart` |
| **Compliance guard** | `ComplianceGuard` (post-processing LLM) | — | `services/coach/compliance_guard.dart` |
| **Routing écran** | `RoutePlanner` + `ScreenRegistry` (71 écrans routables) | — | `services/navigation/` |
| **LLM provider** | SLM on-device (30s) → BYOK cloud (30s) → Fallback templates | Fallback = toujours disponible | `CoachOrchestrator` |

---

## 6. État au logout

| Provider | Cleared au logout ? | Comment | Ref |
|---|---|---|---|
| `CoachProfileProvider` | **Oui** — inconditionnel | `clear()` dans app.dart + `ReportPersistenceService.clear()` | `app.dart:1059`, `coach_profile_provider.dart:1707` |
| `MintStateProvider` | **Oui** — quand profile == null | `clear()` dans update callback (S57-A9) | `app.dart:1119` |
| `ProfileProvider` | **Oui** | Géré par ChangeNotifierProxyProvider | — |
| `BudgetProvider` | **Oui** | ChangeNotifierProxyProvider, clear() au logout | `app.dart:1039` |
| `SharedPreferences` (wizard) | **Oui** — ciblé | `ReportPersistenceService.clear()` efface wizard + coach history. Préserve : `mint_locale`, `_white_label_config`, `_b2b_organization` | `auth_provider.dart:341` |
| `SharedPreferences` (device) | **Préservé** | Langue, B2B org, white-label config ne sont PAS effacés au logout | Intentionnel — ce sont des préférences device, pas compte |
