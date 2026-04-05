# W16 — Fixes techniques (absurdités logiques + logic gaps)

> **⚠️ LEGACY NOTE (2026-04-05):** Uses "chiffre choc" (legacy term → "premier éclairage", see `docs/MINT_IDENTITY.md`).

> 4 prompts ciblés sur les bugs de LOGIQUE trouvés par la W16.
> Les findings UX/produit sont traités séparément (vision stratégique).

---

## PROMPT 1 — Logic absurdities : guards manquants (5 P0, 8 P1)

```
Tu es un ingénieur senior spécialisé en logique métier fintech suisse.
Tu ajoutes des GUARDS pour empêcher les résultats absurdes.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/w16-logic-guards
- Run flutter analyze + flutter test AVANT et APRÈS

## FIXES P0

### FIX 1: Couple optimizer skip avec conjoint salary=0 (P0)
File: apps/mobile/lib/services/financial_core/couple_optimizer.dart
Bug: Si conjointIncome <= 0, le code skip TOUTES les analyses (AVS cap,
marriage penalty) alors que la pénalité s'applique quand même.
Action: Remplacer le guard blanket par des guards par analyse :
```dart
// AVANT (line ~164):
if (conjointIncome <= 0) return const CoupleOptimizationResult.empty();

// APRÈS :
// Allow optimization if AT LEAST ONE person has income
if (userIncome <= 0 && conjointIncome <= 0) {
  return const CoupleOptimizationResult.empty();
}
// Proceed with per-analysis guards instead
```
Pour chaque sous-analyse (LPP buyback, 3a, AVS cap, marriage penalty),
ajouter un guard spécifique au lieu du blanket.

### FIX 2: Age 18 → 47 ans de projection LPP invalide (P0)
File: apps/mobile/lib/services/financial_core/lpp_calculator.dart
Bug: LPP entry = age 25, mais la projection commence dès l'âge actuel.
Action: Dans projectToRetirement(), skip les bonifications avant 25 :
```dart
for (int year = 0; year < futureYears; year++) {
  final ageThisYear = currentAge + year;
  // LPP bonifications start at 25 (LPP art. 7)
  if (ageThisYear < 25) continue;
  final rate = getLppBonificationRate(ageThisYear);
  // ... rest of projection
}
```

### FIX 3: Divorce split avec 0 ans mariage — early return (P0)
File: apps/mobile/lib/services/financial_core/avs_calculator.dart
Bug: Le code exécute le splitting même si marriageYears=0 ou
totalContributionYears=0 (risque division par zéro).
Action: Ajouter un early return :
```dart
if (isDivorced && (marriageYears <= 0 || totalContributionYears <= 0)) {
  // No married period to split — use individual salary
  // Fall through to standard calculation
  isDivorced = false; // Disable splitting for this call
}
```

### FIX 4: Replacement ratio >100% — reformuler (P0)
File: Chercher où le replacement ratio est affiché en texte (chiffre choc,
dashboard, rapport).
Bug: "120% de ton revenu actuel" est absurde pour un retraité.
Action: Quand replacementRatio > 1.0 :
```dart
if (replacementRatio > 1.0) {
  final surplus = ((replacementRatio - 1.0) * 100).toStringAsFixed(0);
  return 'Tu as $surplus% de capital supplémentaire au-delà de tes besoins.';
} else {
  final pct = (replacementRatio * 100).toStringAsFixed(0);
  return 'Tu maintiens $pct% de ton train de vie actuel.';
}
```

### FIX 5: Age 64.9 arrondi → projection incorrecte (P0)
File: Partout où `age = DateTime.now().year - birthYear` est utilisé
pour des projections critiques (retirement countdown).
Bug: Integer truncation donne 1 an au lieu de 1 mois.
Action: Ajouter un avertissement quand l'âge est à <12 mois de la retraite :
```dart
final monthsToRetirement = (retirementAge * 12) -
    ((DateTime.now().year - birthYear) * 12 +
     DateTime.now().month - birthMonth);
if (monthsToRetirement < 12 && monthsToRetirement > 0) {
  // Show months, not years
  projectionLabel = '$monthsToRetirement mois avant la retraite';
}
```

## FIXES P1

### FIX 6: Canton vide → default ZH silencieux
Action: Dans CHAQUE calculateur qui utilise `canton ?? 'ZH'` ou
`canton.isEmpty ? 'ZH' : canton`, ajouter un warning dans le résultat :
```dart
if (canton.isEmpty) {
  warnings.add('Canton non renseigné — taux Zurich utilisé par défaut.');
}
```

### FIX 7: Negative replacement ratio display
Action: Clamp avant affichage :
```dart
final displayRatio = replacementRatio.clamp(0.0, 3.0);
```

### FIX 8: Zero salary → AVS rente sans contexte
Action: Quand la rente calculée = 0, retourner une raison :
```dart
if (baseRente <= 0) {
  return MonthlyRenteResult(
    rente: 0,
    reason: grossAnnualSalary <= 0
        ? 'Aucun revenu déclaré'
        : 'Revenu insuffisant pour une rente',
  );
}
```

## VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. Test: couple avec conjoint salary=0 → AVS cap quand même calculé
4. Test: age=18 → pas de bonification LPP avant 25
5. git commit: "fix(logic): W16 — guards for absurd outputs"
```

---

## PROMPT 2 — Cross-component logic gaps (8 gaps)

```
Tu es un ingénieur systèmes senior. Tu fixes les GAPS de logique
entre les composants.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/w16-logic-gaps
- Run flutter analyze + flutter test + pytest tests/ -q AVANT et APRÈS

## FIX 1: 3a ceiling dynamique selon employmentStatus (P0 — HIGH)
File: services/backend/app/services/rules_engine.py (~ligne 675)
Bug: Toujours 7'258 CHF même pour les indépendants sans LPP (devrait être 36'288).
Action:
```python
# AVANT :
annual_contribution = PILIER_3A_PLAFOND_AVEC_LPP  # 7,258

# APRÈS :
if profile.employmentStatus == "independant" and not profile.has2ndPillar:
    annual_contribution = PILIER_3A_PLAFOND_SANS_LPP  # 36,288
else:
    annual_contribution = PILIER_3A_PLAFOND_AVEC_LPP  # 7,258
```
Faire le même changement dans TOUS les endroits qui utilisent le plafond 3a
(chercher PILIER_3A_PLAFOND dans le backend ET le Flutter).

## FIX 2: Spouse data persiste après divorce (MEDIUM-HIGH)
File: services/backend/app/api/v1/endpoints/profiles.py
Bug: Quand householdType passe de "couple" à "single", spouseSalaryGrossAnnual
reste dans le JSON.
Action: Ajouter un cascade clear :
```python
update_data = profile_update.model_dump(exclude_unset=True)

# Cascade clear on household type change
if "householdType" in update_data and update_data["householdType"] == "single":
    for spouse_key in ["spouseSalaryGrossAnnual", "spouseEmploymentStatus",
                       "spouseAvsContributionYears", "householdGrossIncome"]:
        data.pop(spouse_key, None)

for key, value in update_data.items():
    data[key] = value
```

## FIX 3: Canton null handling — standardiser (MEDIUM-HIGH)
Action: Créer un helper commun dans le backend :
```python
# services/backend/app/utils/canton_utils.py
VALID_CANTONS = {"ZH", "BE", "LU", "UR", "SZ", "OW", "NW", "GL",
                 "ZG", "FR", "SO", "BS", "BL", "SH", "AR", "AI",
                 "SG", "GR", "AG", "TG", "TI", "VD", "VS", "NE",
                 "GE", "JU"}

def validate_canton(canton: str | None, default: str = "ZH") -> tuple[str, str | None]:
    """Returns (canton, warning). Warning is set if default was used."""
    if not canton or canton.upper() not in VALID_CANTONS:
        return default, f"Canton '{canton}' non reconnu — {default} utilisé par défaut."
    return canton.upper(), None
```
Utiliser ce helper dans TOUS les services qui utilisent canton.

## FIX 4: Employment + LPP consistency check (MEDIUM)
File: services/backend/app/schemas/profile.py
Action: Ajouter un validator Pydantic :
```python
@model_validator(mode='after')
def validate_employment_lpp_consistency(self):
    if (self.employmentStatus == "salarie"
        and self.incomeGrossYearly and self.incomeGrossYearly > 22680
        and self.has2ndPillar is False):
        # Warn but don't reject — user might not know
        pass  # Log warning, don't raise
    return self
```

## FIX 5: Salary monthly/annual conversion — documenter et valider
File: services/backend/app/services/rules_engine.py
Action: Ajouter un commentaire + validation :
```python
# SALARY CONVENTION:
# - incomeGrossYearly: annual GROSS salary (includes 13th month if applicable)
# - incomeNetMonthly: monthly NET salary (after deductions)
# - Conversion: net ≈ gross / 12 × 0.85 (approximate)
# - If both provided, incomeNetMonthly takes priority
estimated_net = profile.incomeNetMonthly or (
    (profile.incomeGrossYearly / 12 * 0.85) if profile.incomeGrossYearly else 0
)
```

## FIX 6: targetRetirementAge — ajouter au schema backend
File: services/backend/app/schemas/profile.py
Action: Ajouter le champ :
```python
targetRetirementAge: Optional[int] = Field(None, ge=58, le=70,
    description="Âge cible de retraite (défaut: âge légal)")
```
Et dans rules_engine.py, utiliser ce champ au lieu du hardcodé 65 :
```python
retirement_age = profile.targetRetirementAge or 65
years = max(5, retirement_age - (now.year - (profile.birthYear or 1990)))
```

## VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. pytest tests/ -q — tous passent
4. Test: indépendant sans LPP → 3a ceiling = 36'288 (pas 7'258)
5. Test: householdType single → spouseSalary cleared
6. git commit: "fix(logic-gaps): W16 — 3a dynamic ceiling, spouse cleanup, canton validation"
```

---

## PROMPT 3 — UX micro-fixes (quick wins Catherine)

```
Tu es un ingénieur Flutter UX. Tu fais les QUICK WINS identifiés
par le test utilisateur Catherine. Pas de refactoring — juste des
améliorations de copy et de clarté.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/w16-ux-quickwins
- Run flutter analyze + flutter test + flutter gen-l10n AVANT et APRÈS

## FIX 1: Bouton "Voir mon résultat" → "Calculer ma retraite"
File: apps/mobile/lib/l10n/app_fr.arb (+ 5 autres langues)
Chercher la clé du bouton CTA de l'onboarding step questions.
Remplacer "Voir mon résultat" par "Calculer ma retraite" (FR).
Traduire dans les 5 autres langues.

## FIX 2: Confidence badge — expliquer les 5 détails
Partout où "Basé sur X détails" est affiché, ajouter un tooltip ou
un texte expandable :
```dart
// "Basé sur 5 détails : âge, revenu, canton, statut, nationalité"
Text('Basé sur ${count} détails : ${detailsList.join(", ")}')
```

## FIX 3: Jargon tooltips — "Taux de remplacement"
File: Partout où "Taux de remplacement" est affiché, ajouter un
suffixe explicatif :
```dart
// AVANT : "Taux de remplacement : 62%"
// APRÈS : "Taux de remplacement : 62% (part de ton salaire maintenue à la retraite)"
```
Faire pareil pour :
- "LPP" → "(prévoyance professionnelle)"
- "3a" → "(épargne retraite privée)"
- "AVS" → "(assurance vieillesse)"
- "RAMD" → "(revenu annuel moyen déterminant)"

## FIX 4: Chiffre choc — ajouter contexte "c'est bien ou pas"
Après le big number, ajouter une ligne de contexte :
```dart
if (replacementRatio >= 0.8) {
  contextLine = 'C\'est un bon niveau — au-dessus de 80%.';
} else if (replacementRatio >= 0.6) {
  contextLine = 'C\'est dans la moyenne suisse. Des optimisations sont possibles.';
} else {
  contextLine = 'C\'est en dessous de la moyenne. Voyons comment améliorer ça.';
}
```

## FIX 5: Data origin visible — montrer les inputs
Sur le retirement dashboard, ajouter un petit bloc "Calculé avec" :
```dart
Text(
  'Calculé avec : âge ${profile.age}, revenu ${formatChf(profile.salaireBrutAnnuel)}, '
  'canton ${profile.canton}. Modifier ?',
  style: MintTextStyles.caption(),
),
```
Avec un lien "Modifier ?" qui mène à /profile/bilan.

## FIX 6: Disclaimer — raccourcir et déplacer
Le disclaimer de 50+ mots est trop long dans le flow principal.
Le raccourcir à 1 ligne + lien "En savoir plus" :
```dart
// AVANT (50 mots) :
// "Suggestions pédagogiques basées sur ton profil — outil éducatif qui ne
//  constitue pas un conseil financier personnalisé au sens de la LSFin.
//  Consultez un·e spécialiste pour une analyse adaptée à ta situation."

// APRÈS (15 mots) :
// "Outil éducatif, pas un conseil financier. En savoir plus"
// Où "En savoir plus" ouvre le disclaimer complet.
```

## VALIDATION
1. flutter gen-l10n — 0 errors
2. flutter analyze — 0 errors
3. flutter test — tous passent
4. git commit: "fix(ux): W16 — jargon tooltips, data origin, chiffre choc context"
```

---

## PROMPT 4 — Privacy claim fix (P0 trust)

```
Tu es un expert compliance nLPD. Tu fixes UNE claim mensongère.

## PRÉ-VÉRIFICATION (AVANT de coder)
Lis les fichiers cibles AVANT de modifier quoi que ce soit.
Vérifie que la structure décrite correspond au code ACTUEL.
Si le code a changé depuis la rédaction de ce prompt, ADAPTE le fix.
Ne fais PAS un copier-coller aveugle — comprends d'abord, fixe ensuite.

## CONTEXTE
- Branche : feature/w16-fix-privacy-claim
- Run flutter analyze + flutter test AVANT et APRÈS

## LE PROBLÈME
L'écran d'import bancaire dit "Tes relevés sont analysés localement.
Les transactions ne sont jamais stockées sur nos serveurs."
MAIS le fichier est envoyé au backend via POST /bank-import/import.

## LE FIX
Chercher la string dans les ARB files (chercher "localement" ou
"locally" ou "jamais stockées").
Remplacer par une formulation honnête :
```
AVANT: "Tes relevés sont analysés localement. Les transactions ne sont
jamais stockées sur nos serveurs."

APRÈS: "Ton relevé est envoyé de manière sécurisée à notre serveur pour
analyse. Les données brutes sont supprimées après traitement — seuls les
résumés par catégorie sont conservés."
```
Traduire dans les 6 langues.

Vérifier aussi que le backend SUPPRIME effectivement le fichier brut
après parsing. Si ce n'est pas le cas, ajouter :
```python
# Dans bank_import.py, après parsing :
# Le fichier uploadé n'est PAS persisté — seul le ParseResult est retourné
# Les bytes sont garbage-collectés après la requête
```

## VALIDATION
1. flutter gen-l10n — 0 errors
2. Relire la nouvelle formulation — honnête et rassurante
3. git commit: "fix(privacy): honest bank import data handling disclosure"
```

---

## ORCHESTRATION

```
Tu es un orchestrateur de sprint. Ta mission : lancer les 4 prompts
du fichier docs/W16_FIX_PROMPTS.md.

## RÈGLE GIT CRITIQUE (NON-NÉGOCIABLE)

NE JAMAIS utiliser isolation: "worktree" pour les agents de fix.
Les worktrees créent des branches worktree-agent-* où les commits se PERDENT.

Pour CHAQUE agent :
1. L'agent travaille DIRECTEMENT dans le repo principal (PAS de worktree)
2. L'agent crée sa feature branch : git checkout -b feature/xxx
3. L'agent commite sur CETTE branche (pas worktree-agent-*)
4. Vérifier AVANT merge : git log feature/xxx --oneline → les commits sont là ?

Si un agent a utilisé un worktree par erreur :
1. NE PAS supprimer le worktree avant d'avoir récupéré les commits
2. git log worktree-agent-xxx --oneline → identifier les commits
3. git cherry-pick <hash> sur dev → récupérer le travail
4. ENSUITE supprimer : git worktree remove ... --force

## PLAN D'EXÉCUTION

### VAGUE 1 — (4 agents EN PARALLÈLE, fichiers différents)
| Agent | Prompt | Branch |
|-------|--------|--------|
| A | P1 (Logic guards) | feature/w16-logic-guards |
| B | P2 (Logic gaps) | feature/w16-logic-gaps |
| C | P3 (UX quick wins) | feature/w16-ux-quickwins |
| D | P4 (Privacy claim) | feature/w16-fix-privacy-claim |

Merger : D → C → B → A

### VÉRIFICATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. pytest tests/ -q — tous passent
4. flutter gen-l10n — 0 errors
5. Test: indépendant sans LPP → 3a = 36'288
6. Test: couple conjoint salary=0 → AVS cap calculé
7. Test: age 18 → LPP bonif commence à 25
8. Privacy claim bank import → formulation honnête
9. git branch → PAS de worktree-agent-* branches orphelines
```
