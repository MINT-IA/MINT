# ONBOARDING ARCHITECTURE

> Dernière mise à jour : 2026-03-27
> Statut : **AUTORITATIF** — Ce document décrit l'architecture réelle de l'onboarding.
> Remplace les sections onboarding de `ONBOARDING_ARBITRAGE_ENGINE.md` (archive).

---

## 1. Vue d'ensemble

L'onboarding a **deux chemins** :
- **Chemin primaire** : API backend (authoritative)
- **Chemin fallback** : calcul local (offline, instantané)

Les deux chemins utilisent le **même algorithme** (S57 — ChiffreChoc V2).

```
Utilisateur
    │
    ▼
StepStressSelector (intention)
    │  stressType = 'stress_retraite' | 'stress_budget' | 'stress_impots' | ...
    ▼
StepQuestions (3-5 inputs)
    │  age, grossSalary, canton [+ employmentStatus, nationalityGroup]
    ▼
SmartOnboardingViewModel.compute()
    │  ├─ MinimalProfileService.compute() → MinimalProfileResult
    │  └─ ChiffreChocSelector.select(profile, stressType: stressType)
    ▼
StepChiffreChoc (reveal)
    │  ├─ Nombre animé (counter 0 → rawValue)
    │  ├─ Barre de confiance (% données fournies)
    │  ├─ Caveat pédagogique (si confidenceMode == pedagogical)
    │  └─ 3 questions literacy (calibrage financier)
    ▼
StepJitExplanation (SI... ALORS)
    ▼
StepTopActions (3 next steps)
    ▼
StepNextStep (enrichir OU dashboard)
    ▼
/home?tab=0 (Aujourd'hui)
```

---

## 2. Dual engine : API vs Local

### Chemin primaire (API)

```
ChiffreChocScreen → ApiService.computeOnboardingChiffreChoc(
    age, grossSalary, canton, ..., stressType
) → POST /api/v1/onboarding/chiffre-choc
    → MinimalProfileInput (avec stress_type)
    → compute_minimal_profile(input) → MinimalProfileResult
    → select_chiffre_choc(profile, stress_type=input.stress_type) → ChiffreChoc
    → ChiffreChocResponse (avec confidence_mode)
← Client lit category, primaryNumber, displayText, confidenceMode
```

### Chemin fallback (local)

```
SmartOnboardingViewModel.compute()
    → MinimalProfileService.compute(age, grossSalary, canton, ...)
    → ChiffreChocSelector.select(profile, stressType: stressType)
    → ChiffreChoc (avec confidenceMode)
```

### Contrat de non-divergence

| Paramètre | API | Local | Vérifié par |
|---|---|---|---|
| `stress_type` | Envoyé dans request body | Passé en paramètre | `test_onboarding_contract.py` |
| `confidence_mode` | Renvoyé dans response | Calculé par `_withConfidence()` | `test_onboarding_contract.py` |
| Archetype Phase 0 | `_select_by_archetype()` | `_selectByArchetype()` | Tests selector (35 backend + 23 Flutter) |
| Lifecycle fallback | `_select_by_lifecycle()` (age direct) | `_selectByLifecycle()` (profile.age) | Tests selector |
| Compound growth math | `math.pow(1+r, n)` | `pow(1+r, n)` (dart:math) | Tests E2E |

---

## 3. ChiffreChoc V2 — Sélection

### Hiérarchie de sélection (4 phases)

```
Phase 0 : ARCHETYPE (toujours prioritaire)
  ├─ Indépendant sans LPP → retirement_gap (error)
  └─ Expat AVS < 1500 → retirement_gap (warning)

Phase 1 : LIQUIDITÉ (si données réelles ou crise sévère)
  └─ < 2 mois ET (savings non-estimées OU < 1 mois) → liquidity (error)

Phase 2 : STRESS-ALIGNED (si stressType déclaré)
  ├─ stress_budget → hourlyRate (pure math)
  ├─ stress_impots → taxSaving3a (si saving > 500)
  ├─ stress_retraite → retirementGap (si ratio < 55%) OU retirementIncome
  ├─ stress_patrimoine → null (pas de données à l'onboarding)
  └─ stress_couple → null (pas de données à l'onboarding)

Phase 3 : UNIVERSEL (gaté par lifecycle)
  ├─ Retirement gap (si age ≥ 30 ET ratio < 55%)
  └─ Tax saving 3a (si no 3a ET saving > 1500)

Phase 4 : LIFECYCLE FALLBACK
  ├─ < 28 ans → compoundGrowth (intérêts composés, pure math)
  ├─ 28-37 ans → taxSaving3a (si applicable) OU compoundGrowth
  └─ 38+ ans → retirementGap (si ratio < 55%) OU retirementIncome
```

### Confidence gating (post-sélection)

| Type | Données clés | Factuel si | Pédagogique si |
|---|---|---|---|
| `compoundGrowth` | Pure math | Toujours | Jamais |
| `hourlyRate` | Salaire (fourni) | Toujours | Jamais |
| `taxSaving3a` | Salaire + canton (fournis) | Toujours | Jamais |
| `liquidityAlert` | Épargne | `currentSavings` fourni | `currentSavings` estimé |
| `retirementGap` | LPP | `existingLpp` fourni | `existingLpp` estimé |
| `retirementIncome` | LPP | `existingLpp` fourni | `existingLpp` estimé |

---

## 4. Types de chiffre choc

| Type | Catégorie API | Icône | Couleur | Pour qui |
|---|---|---|---|---|
| `compoundGrowth` | `compound_growth` | `trending_up` | `success` | < 38 ans sans stress spécifique |
| `hourlyRate` | `hourly_rate` | `schedule` | `info` | stress_budget |
| `taxSaving3a` | `tax_saving` | `savings` | `success` | Pas de 3a + économie significative |
| `liquidityAlert` | `liquidity` | `warning_amber` | `error` | Réserves < 2 mois (données réelles) |
| `retirementGap` | `retirement_gap` | `trending_down` | `warning` | Ratio < 55% et age ≥ 30 |
| `retirementIncome` | `retirement_income` | `account_balance` | `info` | Ratio OK, stress_retraite ou fallback 38+ |

---

## 5. Garde-fous

### Ce que le chiffre choc ne fait JAMAIS

- Montrer un gap retraite précis à un 22 ans (trop abstrait → compoundGrowth)
- Montrer une alerte liquidité sur des données estimées sauf crise sévère (< 1 mois)
- Utiliser des termes interdits ("garanti", "optimal", "meilleur", "conseiller")
- Promettre un rendement ("ton 3a rapportera X" → "pourrait économiser ~X d'impôts")

### Ce que le chiffre choc fait TOUJOURS

- Respecter l'intention de l'utilisateur (stressType)
- Adapter par phase de vie (lifecycle)
- Distinguer factuel vs pédagogique (confidenceMode)
- Inclure un disclaimer LSFin
- Citer les sources légales

---

## 6. Enrichissement post-onboarding

Après le chiffre choc, l'enrichissement se fait par :

1. **Coach conversationnel** : pose les questions contextuelles (`ask_user_*` tools)
2. **Scan documentaire** : certificat LPP (+25-30 pts confiance), déclaration fiscale, extrait AVS
3. **EVI ranking** : le `BayesianProfileEnricher` classe les documents/questions par Expected Value of Information
4. **Low confidence card** : affichée quand confiance < 40% avec top 3 enrichment prompts
5. **Smart shortcuts** : `/scan` inséré automatiquement quand confiance < 70

L'utilisateur n'a **jamais** besoin de remplir un formulaire complet. Chaque session enrichit progressivement.
