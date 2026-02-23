# ADR-20260223 — Archetype-Driven Retirement Projection

**Status**: Accepted
**Date**: 2026-02-23
**Authors**: Julien + Claude (senior audit)

---

## Contexte

### Probleme identifie

Le moteur de projection retraite (`RetirementProjectionService`) utilise un modele unique
"Swiss native salarie" pour tous les profils. Cela produit des projections **fausses**
pour les profils atypiques, qui representent potentiellement 40%+ de la cible MINT (22-45 ans
en Suisse, souvent expats, independants, ou parcours mixtes).

### Bugs concrets decouverts (audit 2026-02-23)

| Bug | Impact | Fichier | Lignes |
|-----|--------|---------|--------|
| `_estimateLppAvoir()` simule des cotisations depuis 25 ans meme si arrive a 42 ans | LPP gonfle de +40-60% pour expats | `coach_profile.dart` | 1486-1504 |
| Double imposition du capital LPP : taxe au retrait PUIS taxe comme revenu annuel | Capital paraît ~15% pire que la realite | `retirement_projection_service.dart` | 1018-1021 |
| Independant avec revenu > seuil LPP → bonifications LPP calculees alors que pas affilie | LPP fictif pour independants | `retirement_projection_service.dart` | 506-510 |
| Comparaison visuelle asymetrique rente (brut) vs capital (net) dans le chart | UX trompeuse | `retirement_projection_screen.dart` | stacked bar |
| US citizen : pas de Social Security, pas d'alerte FATCA/PFIC | Projection incomplete | non implemente | — |

### Approche rejetee : "bibliotheque de variables exhaustive"

L'idee de collecter 100+ variables dans un modele unique a ete evaluee et rejetee :
- **UX** : 100+ questions → taux d'abandon massif
- **Precision illusoire** : la plupart des users ne rempliront pas tout
- **Moteur unique** : memes formules avec plus de variables ≠ formules adaptees
- **Maintenance** : 1 moteur × 150 variables = fragile, hard to test

Le probleme n'est pas un manque de variables. C'est un manque de **chemins de calcul adaptes**
aux differents profils.

---

## Decision

### Architecture : Archetype-Driven Progressive Enrichment

3 couches :

```
Couche 1 — CoreProfile (mini-onboarding, tout le monde)
  ├── age, canton, revenu, foyer, emploi
  ├── nationality, arrivalAge (si pas ne en Suisse)
  └── → detection automatique de l'archetype

Couche 2 — ArchetypeEngine (calcul adapte par module)
  ├── BaseProjection (AVS + patrimoine libre — tout le monde)
  ├── LppModule      → SwissNativeLpp | ExpatLpp | IndependentLpp | NoLpp
  ├── ForeignPension  → SocialSecurity | EuPension | null
  ├── TaxModule      → OrdinaryTax | SourceTax | DualTax(US)
  └── → projection avec confidence score + bande d'incertitude

Couche 3 — Enrichment (progressif, optionnel, archetype-specifique)
  ├── Certificat de prevoyance LPP (solde reel, taux conversion reel)
  ├── Extrait AVS (annees effectives, revenus moyens)
  ├── Releves 3a (soldes reels par compte)
  ├── Foreign pension statements (401k, Social Security statement)
  └── → chaque enrichment reduit la bande d'incertitude
```

### Archetypes (enum definitive)

| Archetype | Detection | Calcul LPP | Calcul AVS | Fiscalite | Specificites |
|-----------|-----------|------------|------------|-----------|--------------|
| `swiss_native` | CH + arrive < 22 ans | Bonif. depuis 25 ans (standard) | LAVS plein | Ordinaire | Modele par defaut |
| `expat_eu` | Nationalite EU + arrive > 20 ans | Bonif. depuis `arrivalAge` | LAVS partiel + convention bilaterale | Ordinaire (ou source si permis B) | Totalisation periodes EU pour AVS |
| `expat_non_eu` | Hors EU + arrive > 20 ans | Bonif. depuis `arrivalAge` | LAVS partiel, pas de convention (sauf cas) | Source → ordinaire | Avoir etranger non modelise |
| `expat_us` | US citizen/green card | Bonif. depuis `arrivalAge` | LAVS partiel + Social Security US | Double taxation CH-US (CDI) | FATCA, PFIC, restriction 3a |
| `independent_with_lpp` | Independant + LPP declaree | LPP facultative (solde reel) | LAVS standard | Ordinaire | Rachat possible, attention coordination |
| `independent_no_lpp` | Independant + pas de LPP | LPP = 0 | LAVS standard | Ordinaire | 3a max 36'288, patrimoine = prevoyance |
| `cross_border` | Permis G / frontalier | LPP suisse standard | LAVS suisse (convention bilat.) | Impot source / quasi-resident | Assurance maladie: choix LAMal ou pays |
| `returning_swiss` | CH + sejour etranger > 3 ans | Libre passage + bonif. depuis retour | LAVS avec lacunes | Ordinaire | Rachat LPP souvent avantageux |

### Detection automatique

```dart
FinancialArchetype detectArchetype(CoachProfile profile) {
  final isSwiss = profile.nationality == 'CH';
  final isFatca = profile.isFatcaResident || profile.nationality == 'US';
  final isIndep = profile.employmentStatus == 'independant';
  final isFrontalier = profile.residencePermit == 'permit_g';
  final arrivedLate = (profile.arrivalAge ?? 0) > 21;

  if (isFrontalier) return FinancialArchetype.crossBorder;
  if (isFatca) return FinancialArchetype.expatUs;
  if (isIndep && (profile.prevoyance.avoirLppTotal ?? 0) > 0) {
    return FinancialArchetype.independentWithLpp;
  }
  if (isIndep) return FinancialArchetype.independentNoLpp;
  if (isSwiss && arrivedLate) return FinancialArchetype.returningSwiss;
  if (arrivedLate) {
    final isEu = _euCountries.contains(profile.nationality);
    return isEu ? FinancialArchetype.expatEu : FinancialArchetype.expatNonEu;
  }
  return FinancialArchetype.swissNative;
}
```

### Confidence Score

Chaque projection inclut un score de confiance (0-100%) calcule sur la completude
des donnees **pertinentes pour l'archetype detecte**.

```dart
class ProjectionConfidence {
  final double score;           // 0.0 - 1.0
  final String level;           // 'low', 'medium', 'high'
  final List<EnrichmentPrompt> prompts; // actions pour ameliorer
}
```

**Poids par source de donnee :**

| Donnee | Poids | Comment obtenir |
|--------|-------|-----------------|
| Salaire reel | 15% | Mini-onboarding (deja collecte) |
| Age + canton | 10% | Mini-onboarding (deja collecte) |
| Archetype detecte | 5% | Automatique |
| Avoir LPP reel | 20% | Certificat de prevoyance (upload ou saisie) |
| Taux conversion reel | 10% | Certificat de prevoyance |
| Extrait AVS | 15% | Commande gratuite sur caissedevs.ch |
| Soldes 3a reels | 10% | Saisie manuelle ou releve |
| Patrimoine detaille | 10% | Saisie manuelle |
| Pension etrangere (si expat) | 5% | Saisie manuelle |

**Affichage UX :**

```
Revenu retraite estime : CHF 9'200 - 12'800 /mois
Confiance : ██████░░░░ 58%

💡 +20% confiance → Ajoute ton solde LPP (certificat de prevoyance)
💡 +15% confiance → Commande ton extrait AVS (gratuit)
```

### Regles de calcul par archetype

#### LPP Module

```dart
// swiss_native : standard (comme aujourd'hui)
double lppSwissNative(age, salary) → boucle 25..age

// expat_* : depuis arrivalAge
double lppExpat(age, salary, arrivalAge) → boucle max(25, arrivalAge)..age

// independent_no_lpp : zero
double lppIndependentNoLpp() → 0

// independent_with_lpp : valeur declaree, pas d'estimation
double lppIndependentWithLpp(declaredBalance) → declaredBalance
```

#### AVS Module

```dart
// swiss_native : 44 annees max, pas de lacunes
double avsSwissNative(age, retirementAge) → standard

// expat_eu : convention bilaterale, totalisation des periodes
// Les annees EU comptent pour le DROIT a la rente (pas le montant)
double avsExpatEu(age, retirementAge, arrivalAge, yearsEu)
  → rente CH proportionnelle + note "pension EU separee"

// expat_us : idem + Social Security
double avsExpatUs(age, retirementAge, arrivalAge, yearsUs)
  → rente CH partielle + estimation Social Security US
```

#### Tax Module (retrait capital)

```dart
// standard : LIFD art. 38, bareme progressif cantonal
double capitalTaxStandard(capital, canton, isMarried)

// expat_us : attention double taxation
// CDI CH-US art. 18 : la Suisse taxe, credit d'impot US
double capitalTaxUs(capital, canton, isMarried)
  → tax CH + alerte "verifier credit impot IRS"
```

### Budget Gap : fix double imposition capital

Dans `_computeBudgetGap()`, le revenu imposable annuel doit **exclure** la portion
capital du LPP (deja taxee au retrait sous LIFD art. 38) :

```dart
// AVANT (bug) :
final impotMensuel = _estimateRetirementTax(
  revenuAnnuelRetraite: totalRevenus * 12,  // inclut capital SWR
);

// APRES (fix) :
// Les retraits SWR du capital LPP ne sont pas un revenu imposable
// (c'est une consommation de patrimoine propre, deja taxe au retrait)
final revenuImposable = incomes
    .where((s) => !s.isCapitalWithdrawal)
    .fold(0.0, (sum, s) => sum + s.monthlyAmount);
final impotMensuel = _estimateRetirementTax(
  revenuAnnuelRetraite: revenuImposable * 12,
);
```

---

## Alternatives considerees

### 1. Bibliotheque de variables exhaustive (rejetee)

Collecter 100-150 variables dans un modele plat, un seul moteur de calcul.

**Rejete car** :
- UX : trop de questions, taux d'abandon
- Le probleme est les chemins de calcul, pas les inputs
- Precision illusoire si 80% des champs restent vides
- Fragile : un moteur avec 50 if/else est impossible a tester

### 2. Moteur unique avec parametres optionnels (rejetee)

Ajouter des parametres optionnels partout (`arrivalAge?`, `foreignPension?`, etc.)

**Rejete car** :
- Complexite cyclomatique explosive
- Chaque nouveau profil = modifier toutes les fonctions
- Impossible a tester exhaustivement (combinatoire)

### 3. Archetype-driven avec modules (acceptee)

Modules de calcul independants, un par aspect (LPP, AVS, fiscalite),
avec implementations par archetype.

**Accepte car** :
- Chaque module est testable independamment
- Ajouter un archetype = ajouter des implementations, pas modifier l'existant
- UX : on ne demande que les questions pertinentes pour l'archetype
- Confidence score = honnetete envers l'utilisateur (LSFin)

---

## Consequences

### Ce qui change

1. **CoachProfile** : ajouter `arrivalAge`, `archetype` (enum), `confidenceScore`
2. **RetirementProjectionService** : refactorer en modules (LppModule, AvsModule, TaxModule)
3. **RetirementProjectionResult** : ajouter `confidence`, `enrichmentPrompts`, `assumptions`
4. **UI** : afficher bande d'incertitude + score de confiance + prompts d'enrichment
5. **Onboarding** : ajouter 1-2 questions (nationalite, annee arrivee si pas CH)

### Ce qui ne change pas

- CoreProfile (mini-onboarding existant)
- Patrimoine libre (calcul identique pour tous)
- Navigation / design system
- Backend API (les calculs restent en Flutter, backend = source de verite pour constantes)

### Risques

| Risque | Mitigation |
|--------|-----------|
| Complexite du refactoring | Incremental : fixer d'abord les bugs P1/P2 avec l'archi actuelle, puis migrer module par module |
| Archetypes trop simplistes | Prevoir `custom` archetype avec saisie manuelle complete |
| Confidence score mal calibre | Valider avec 5-10 profils reels, ajuster les poids |
| Conventions bilaterales complexes | V1 = alerte educative, V2 = calcul reel |

---

## Plan de migration

### Phase 1 — Quick wins (sprint actuel)

- [ ] Fix double imposition capital (P2) — `retirement_projection_service.dart`
- [ ] Fix `_estimateLppAvoir()` : passer `arrivalAge`, demarrer boucle a `max(25, arrivalAge)`
- [ ] Fix independant sans LPP : `avoirLppTotal = 0` si independant et pas de LPP declaree
- [ ] Ajouter `arrivalAge` dans `CoachProfile` (derive de `q_avs_arrival_year`)
- [ ] Ajouter `isCapitalWithdrawal` flag sur `RetirementIncomeSource`

### Phase 2 — Archetype detection

- [ ] Definir enum `FinancialArchetype` dans `coach_profile.dart`
- [ ] Implementer `detectArchetype()` dans un nouveau `archetype_service.dart`
- [ ] Ajouter questions onboarding : nationalite + annee arrivee (si non-CH)
- [ ] Stocker l'archetype detecte dans `CoachProfile`

### Phase 3 — Module refactoring

- [ ] Extraire `LppModule` avec implementations par archetype
- [ ] Extraire `AvsModule` avec support conventions bilaterales (EU)
- [ ] Extraire `TaxModule` avec support double taxation (US)
- [ ] Ajouter `ProjectionConfidence` au resultat

### Phase 4 — Enrichment UX

- [ ] Afficher bande d'incertitude dans le chart (min/max)
- [ ] Afficher confidence score avec prompts d'enrichment
- [ ] Upload certificat de prevoyance (OCR ou saisie manuelle)
- [ ] Saisie extrait AVS

### Phase 5 — Foreign pensions

- [ ] Estimation Social Security US (basique)
- [ ] Alertes FATCA/PFIC pour US persons
- [ ] Note "pension EU separee" pour expats EU
- [ ] Integration convention bilaterale CH-EU pour AVS

---

## Liens

- **LAVS art. 21-29** — Rente AVS, anticipation, ajournement
- **LPP art. 4** — Affiliation facultative (independants)
- **LPP art. 7** — Seuil d'entree 22'680 CHF
- **LPP art. 14** — Taux de conversion minimum 6.8%
- **LPP art. 79b al. 3** — Blocage rachat 3 ans
- **LIFD art. 22** — Imposition des rentes
- **LIFD art. 33 al. 1 let. d** — Deduction rachats LPP
- **LIFD art. 38** — Imposition separee des prestations en capital
- **LIFD art. 83-86** — Impot a la source
- **OPP3 art. 7** — Plafonds 3e pilier
- **Convention bilaterale CH-EU** — Totalisation des periodes (reglement CE 883/2004)
- **Convention bilaterale CH-US** — Double taxation, Social Security (RS 0.831.109.336.1)
- **FATCA** — Foreign Account Tax Compliance Act (reporting obligations)
- **Trinity Study** — Safe Withdrawal Rate 4% (Cooley, Hubbard, Walz, 1998)
- Audit initial : commit `e4e26cf` (fix controller sync)
