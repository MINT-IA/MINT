# W13 Fixes + Grade A+ Sprint — Prompts complets

> 10 prompts au total : 4 features A→A+ et 6 fixes W13.
> Chaque prompt est autonome avec sa propre branche.
>
> **Vague 1 (parallèle)** : Prompts 5, 6, 7, 8 (W13 fixes, fichiers indépendants)
> **Vague 2 (parallèle)** : Prompts 1, 2 (features AVS, indépendants)
> **Vague 3 (séquentiel)** : Prompt 3 (refactoring coach_chat — gros changement)
> **Vague 4 (après prompt 3)** : Prompt 4 (performance — dépend du refactoring)
> **Vague 5 (parallèle)** : Prompts 9, 10 (cleanup final)

---

## PROMPT 1 — Échelle 44 AVS concave (Feature A+)

```
Tu es un actuaire suisse expert en AVS. Ta mission : remplacer l'interpolation
linéaire actuelle par l'échelle 44 officielle de l'OFAS.

## CONTEXTE
- Branche : feature/grade-a-echelle44-avs
- File principal : apps/mobile/lib/services/financial_core/avs_calculator.dart
- File constants : apps/mobile/lib/constants/social_insurance.dart
- Backend registry : services/backend/app/services/regulatory/registry.py
- Tests : apps/mobile/test/services/financial_core/avs_calculator_test.dart

## IMPORTANT — L'échelle 44 évolue tous les 2 ans
Les montants changent avec l'indice mixte (50% prix + 50% salaires).
Il faut donc :
1. Mettre la table dans social_insurance.dart (hardcoded fallback offline)
2. Mettre la table dans le backend registry (source of truth, syncable)
3. Le code doit utiliser reg() pour charger depuis le registry, avec fallback

## CE QU'IL FAUT FAIRE

### 1. Ajouter la table Échelle 44 dans social_insurance.dart
```dart
/// Échelle 44 — table officielle OFAS (rentes mensuelles AVS, 44 ans de cotisation)
/// Source : Mémento 6.01 — Tables des rentes AVS/AI (OFAS 2025)
/// ATTENTION : cette table est mise à jour tous les 2 ans par le Conseil fédéral.
/// Le backend registry (RegulatorySyncService) est la source de vérité.
/// Ces valeurs servent de fallback offline uniquement.
const List<List<double>> avsEchelle44 = [
  [0, 0],
  [14700, 1260],
  [17640, 1299],
  [20580, 1338],
  [23520, 1377],
  [26460, 1416],
  [29400, 1470],
  [32340, 1524],
  [35280, 1578],
  [38220, 1632],
  [41160, 1686],
  [44100, 1743],
  [47040, 1800],
  [49980, 1857],
  [52920, 1914],
  [55860, 1971],
  [58800, 2028],
  [61740, 2085],
  [64680, 2142],
  [67620, 2199],
  [70560, 2256],
  [73500, 2313],
  [76440, 2370],
  [79380, 2427],
  [82320, 2462],
  [85260, 2491],
  [88200, 2520],
];
```

### 2. Modifier renteFromRAMD() dans avs_calculator.dart
Remplacer l'interpolation linéaire par un lookup dans l'échelle 44 :
```dart
static double renteFromRAMD(double grossAnnualSalary) {
  if (grossAnnualSalary <= 0) return 0;
  final table = avsEchelle44; // TODO: load from registry when available
  if (grossAnnualSalary <= table.first[0]) return table.first[1];
  if (grossAnnualSalary >= table.last[0]) return table.last[1];
  for (int i = 0; i < table.length - 1; i++) {
    final lower = table[i];
    final upper = table[i + 1];
    if (grossAnnualSalary >= lower[0] && grossAnnualSalary <= upper[0]) {
      final ratio = (grossAnnualSalary - lower[0]) / (upper[0] - lower[0]);
      return lower[1] + ratio * (upper[1] - lower[1]);
    }
  }
  return table.last[1];
}
```

### 3. Ajouter la table dans le backend registry
File: services/backend/app/services/regulatory/registry.py
Ajouter la table Échelle 44 comme constante syncable, avec le même format.

### 4. Mettre à jour les tests
- Julien (122'207) → toujours 2'520 (au-dessus du max)
- Lauren (67'000) → environ 2'175-2'200 (SUPÉRIEUR à l'ancien 2'156 linéaire)
- Revenu moyen (45'000) → vérifier SUPÉRIEUR à interpolation linéaire
- Edge cases : 14'700 → 1'260, 88'200 → 2'520, 0 → 0

### VALIDATION
1. flutter test test/services/financial_core/avs_calculator_test.dart — tous passent
2. flutter test test/golden/ — golden couple valide
3. flutter analyze — 0 errors
4. git commit: "feat(avs): implement Échelle 44 concave lookup table (OFAS 2025)"
```

---

## PROMPT 2 — AVS divorce splitting + bonifications éducatives (Feature A+)

```
Tu es un actuaire suisse expert en LAVS art. 29sexies.
Ta mission : implémenter le splitting de revenus au divorce ET
les bonifications pour tâches éducatives.

## CONTEXTE
- Branche : feature/grade-a-avs-splitting
- File : apps/mobile/lib/services/financial_core/avs_calculator.dart
- Constants : apps/mobile/lib/constants/social_insurance.dart
- Tests : apps/mobile/test/services/financial_core/avs_calculator_test.dart

## FEATURE 1 : Splitting de revenus au divorce (LAVS art. 29sexies)

Ajouter des paramètres optionnels à computeMonthlyRente() :
```dart
static double computeMonthlyRente({
  // ... existing params ...
  bool isDivorced = false,
  double? exSpouseAnnualSalary,
  int marriageYears = 0,
  int totalContributionYears = 44,
}) {
  double effectiveSalary = grossAnnualSalary;
  if (isDivorced && exSpouseAnnualSalary != null && marriageYears > 0) {
    final combinedDuringMarriage = (grossAnnualSalary + exSpouseAnnualSalary) / 2;
    final marriageRatio = marriageYears / totalContributionYears;
    final singleRatio = 1.0 - marriageRatio;
    effectiveSalary = (combinedDuringMarriage * marriageRatio) +
                      (grossAnnualSalary * singleRatio);
  }
  return renteFromRAMD(effectiveSalary);
}
```

## FEATURE 2 : Bonifications éducatives (LAVS art. 29sexies)

```dart
static double computeMonthlyRente({
  // ... existing params ...
  int childRaisingYears = 0,
}) {
  // ... divorce splitting ...
  if (childRaisingYears > 0) {
    final bonificationAnnuelle = 3 * avsRenteMinAnnuelle;
    final bonificationRAMD = (bonificationAnnuelle * childRaisingYears) /
                              totalContributionYears;
    effectiveSalary += bonificationRAMD;
    effectiveSalary = effectiveSalary.clamp(0, avsRAMDMax);
  }
  return renteFromRAMD(effectiveSalary);
}
```

### Tests
1. Divorce : femme 60k, ex-mari 120k, 20 ans mariage / 44 → RAMD ~73'636
2. Bonification : 2 enfants, 16 ans chacun = 32 ans
3. Combiné : divorce + bonification
4. Edge case : marriageYears = 0, childRaisingYears = 0

### VALIDATION
1. flutter test — tous passent
2. Golden couple Lauren → résultat inchangé (pas divorcée)
3. git commit: "feat(avs): divorce income splitting + child-raising credits (LAVS 29sexies)"
```

---

## PROMPT 3 — Refactoring coach_chat_screen.dart (Feature A+)

```
Tu es un architecte Flutter senior. Ta mission : refactorer coach_chat_screen.dart
de ~4193 lignes à <1000 lignes en extrayant 6 composants.

## CONTEXTE
- Branche : feature/grade-a-refactor-coach-chat
- File : apps/mobile/lib/screens/coach/coach_chat_screen.dart
- Tests : apps/mobile/test/screens/coach/coach_chat_test.dart

## RÈGLES NON-NÉGOCIABLES
1. ZERO changement de comportement visible (refactoring pur)
2. Tous les tests existants doivent passer SANS modification
3. Pas de nouvelle dépendance

## PLAN D'EXTRACTION — 6 composants dans apps/mobile/lib/widgets/coach/

1. coach_message_bubble.dart (~300 lignes)
   - _buildCoachBubble() + _buildUserBubble() + animation logic

2. coach_input_bar.dart (~400 lignes)
   - TextField + send button + voice button + attachments

3. coach_greeting_card.dart (~200 lignes)
   - _buildGreetingCard() avec animation expand/collapse

4. coach_canvas_background.dart (~300 lignes)
   - Canvas mood tinting + milestone pulse animation

5. coach_app_bar.dart (~150 lignes)
   - _buildAppBar() avec tier badge, export button

6. coach_disclaimer.dart (~100 lignes)
   - _buildDisclaimer() widget

### Ce qui RESTE dans coach_chat_screen.dart (~800 lignes) :
- State management, message sending, streaming, layout, navigation

### VALIDATION
1. flutter analyze — 0 errors
2. flutter test — TOUS les tests passent SANS modification
3. coach_chat_screen.dart < 1000 lignes
4. git commit: "refactor(coach-chat): extract 6 components (4193→<1000 lines)"
```

---

## PROMPT 4 — Selector/RepaintBoundary performance (Feature A+)

```
Tu es un expert Flutter performance. Ta mission : ajouter Selector
et RepaintBoundary sur 3 écrans critiques.

## CONTEXTE
- Branche : feature/grade-a-performance
- DÉPEND DU PROMPT 3 (refactoring coach_chat) — lancer APRÈS merge du prompt 3

## FIXES

### 1. CoachChatScreen — RepaintBoundary sur message list
```dart
RepaintBoundary(
  child: ListView.builder(
    itemCount: _messages.length,
    itemBuilder: (context, index) => _buildMessageItem(index),
  ),
),
```

### 2. RenteVsCapitalScreen — ValueListenableBuilder pour sliders
```dart
final _capitalRatio = ValueNotifier<double>(0.5);
ValueListenableBuilder<double>(
  valueListenable: _capitalRatio,
  builder: (context, ratio, child) => Slider(value: ratio, onChanged: (v) => _capitalRatio.value = v),
),
```
+ RepaintBoundary autour de la zone résultats

### 3. PulseScreen — RepaintBoundary sur hero number
Vérifier que computations memoizées, ajouter RepaintBoundary:
```dart
RepaintBoundary(child: _buildDominantNumber(context)),
```

### VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. git commit: "perf(screens): Selector + RepaintBoundary on 3 critical screens"
```

---

## PROMPT 5 — W13 Fix : Provider state wiring (11 bugs)

```
Tu es un architecte Flutter senior. Tu fixes les problèmes de state
consistency entre providers. Fix ONLY what's listed.

## CONTEXTE
- Branche : feature/w13-provider-state
- Run flutter analyze + flutter test AVANT et APRÈS

## FIXES

### FIX 1: MintStateProvider auto-recompute (CRITICAL)
File: apps/mobile/lib/app.dart (MultiProvider section)
Bug: MintStateProvider n'est JAMAIS recomputed quand CoachProfileProvider change.
Action: Remplacer le ChangeNotifierProvider par un ChangeNotifierProxyProvider :
```dart
ChangeNotifierProxyProvider<CoachProfileProvider, MintStateProvider>(
  create: (_) => MintStateProvider(),
  update: (_, coachProvider, mintState) {
    if (coachProvider.hasProfile && coachProvider.profileUpdatedSinceBudget) {
      mintState?.recompute(coachProvider.profile!);
    }
    return mintState!;
  },
),
```

### FIX 2: mergeAnswers() — persist BEFORE notify (5 instances)
File: apps/mobile/lib/providers/coach_profile_provider.dart
Bug: notifyListeners() appelé AVANT ReportPersistenceService.saveAnswers().
Action: Pour chaque instance de ce pattern, inverser l'ordre :
```dart
// AVANT :
notifyListeners();
ReportPersistenceService.saveAnswers(merged); // fire-and-forget
// APRÈS :
await ReportPersistenceService.saveAnswers(merged);
notifyListeners();
```
Faire ce changement dans : mergeAnswers(), updateFromSmartFlow(),
updateFromRefresh(), addCheckIn(), updateContributions().
NOTE: Rendre ces méthodes async si elles ne le sont pas déjà.

### FIX 3: Divorce cleanup — awaiter correctement
File: apps/mobile/lib/providers/coach_profile_provider.dart
Bug: _awaitedDivorceCleanup() appelé mais pas awaité dans updateProfile().
Action: Await the cleanup before notifyListeners:
```dart
if (statusChangedToSingle) {
  await _awaitedDivorceCleanup();
}
_profileUpdatedSinceBudget = true;
notifyListeners();
```

### FIX 4: LocaleProvider — persist avant notify
File: apps/mobile/lib/providers/locale_provider.dart
Action: Await prefs save before notifyListeners:
```dart
Future<void> setLocale(Locale newLocale) async {
  if (newLocale == _locale) return;
  _locale = newLocale;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(_prefKey, newLocale.languageCode);
  notifyListeners(); // APRÈS persistence
}
```

### FIX 5: SubscriptionProvider — debounce concurrent calls
File: apps/mobile/lib/providers/subscription_provider.dart
Action: Ajouter un lock simple :
```dart
bool _isRefreshing = false;
Future<void> refreshFromBackend() async {
  if (_isRefreshing) return;
  _isRefreshing = true;
  try {
    _state = await SubscriptionService.refreshFromBackend();
    _lastRefresh = DateTime.now();
    notifyListeners();
  } finally {
    _isRefreshing = false;
  }
}
```

### VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. git commit: "fix(providers): W13 — auto-recompute, persist-before-notify, locks"
```

---

## PROMPT 6 — W13 Fix : API contract gaps (20 bugs)

```
Tu es un architecte backend Python/FastAPI senior.
Tu fixes les problèmes de contrat API. Fix ONLY what's listed.

## CONTEXTE
- Branche : feature/w13-api-contracts
- Run pytest tests/ -q AVANT et APRÈS

## FIXES

### FIX 1: Ajouter response_model aux 5 endpoints sans contrat
Files: unemployment.py, regulatory.py, knowledge.py, open_banking.py
Pour chaque endpoint sans response_model :
1. Créer un Pydantic model dans le fichier schemas correspondant
2. Ajouter response_model= au décorateur @router

Exemple pour regulatory :
```python
class ConstantsResponse(BaseModel):
    count: int
    constants: list[dict]

@router.get("/constants", response_model=ConstantsResponse)
def get_constants(...):
```

### FIX 2: Remplacer datetime.utcnow() par datetime.now(timezone.utc)
Rechercher TOUS les `datetime.utcnow()` dans le backend et remplacer :
```python
# AVANT : datetime.utcnow()
# APRÈS : datetime.now(timezone.utc)
from datetime import timezone
```

### FIX 3: Ajouter pagination aux endpoints liste sans limit
Files: open_banking.py (consents, transactions), scenarios.py
Ajouter limit/offset query params :
```python
@router.get("/consents")
def list_consents(
    limit: int = Query(default=50, ge=1, le=200),
    offset: int = Query(default=0, ge=0),
    ...
):
    return db.query(...).offset(offset).limit(limit).all()
```

### FIX 4: Standardiser le format d'erreur
File: open_banking.py
Remplacer les retours `{"ok": True, "message": "..."}` par le format standard :
```python
# AVANT : return {"ok": True, "message": "Consent revoked"}
# APRÈS : return {"status": "revoked", "consent_id": consent_id}
```

### FIX 5: Ajouter .order_by() explicite aux queries liste
Files: open_banking.py, scenarios.py
```python
.order_by(ConsentModel.created_at.desc())
```

### VALIDATION
1. pytest tests/ -q — tous passent
2. git commit: "fix(api): W13 — response models, pagination, datetime.now(tz), error format"
```

---

## PROMPT 7 — W13 Fix : Calculation edge case guards (10 bugs)

```
Tu es un actuaire suisse. Tu ajoutes des guards pour les edge cases
financiers identifiés. Fix ONLY what's listed.

## CONTEXTE
- Branche : feature/w13-calc-guards
- Run flutter analyze + flutter test AVANT et APRÈS

## FIXES

### FIX 1: 3a partial year pro-rating
File: apps/mobile/lib/services/financial_core/tax_calculator.dart
Dans estimate3aTaxSaving(), ajouter un paramètre optionnel :
```dart
static double estimate3aTaxSaving({
  // ... existing ...
  int contributionMonths = 12,
}) {
  final ceiling = reg('pillar3a.max_with_lpp', pilier3aPlafondAvecLpp);
  final proRatedCeiling = ceiling * contributionMonths / 12;
  return proRatedCeiling * marginalRate;
}
```

### FIX 2: Negative income guard
File: apps/mobile/lib/services/financial_core/tax_calculator.dart
Au début de estimateMonthlyIncomeTax() et estimate3aTaxSaving() :
```dart
if (grossAnnualSalary <= 0) return 0;
```

### FIX 3: Cross-canton couple — use conjoint canton
File: apps/mobile/lib/services/financial_core/couple_optimizer.dart
Dans _analyzeMarriagePenalty(), si conjoint.canton != user.canton :
```dart
final conjointCanton = conjoint.canton ?? user.canton;
if (conjointCanton != canton) {
  // Split taxation: compute each in their own canton
  final taxUser = TaxCalculator.estimateMonthlyIncomeTax(
    revenuAnnuelImposable: userIncome, canton: canton, ...);
  final taxConjoint = TaxCalculator.estimateMonthlyIncomeTax(
    revenuAnnuelImposable: conjointIncome, canton: conjointCanton, ...);
  // Compare with joint filing in user's canton
}
```

### FIX 4: LPP threshold pro-rating
File: apps/mobile/lib/services/financial_core/lpp_calculator.dart
Ajouter commentaire + guard pour partial year :
```dart
// NOTE: LPP entry threshold (22'680) applies to annual salary.
// For partial years, the effective threshold should be pro-rated.
// Currently assumes full-year employment.
// TODO(P2-Finance): Add contributionMonths param for pro-rated threshold
```

### FIX 5: 13-month salary documentation
File: apps/mobile/lib/services/financial_core/lpp_calculator.dart
Ajouter commentaire :
```dart
// NOTE: grossAnnualSalary should be base salary × 12, NOT including
// 13th month bonus, unless the LPP certificate explicitly includes it
// in the coordinated salary. See LPP art. 8.
// The nombreDeMois field (12, 13, 13.5) is for net income calculation,
// NOT for LPP coordination deduction.
```

### VALIDATION
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. git commit: "fix(calc): W13 — partial year 3a, negative income, cross-canton couple"
```

---

## PROMPT 8 — W13 Fix : ARB cleanup (1'460 clés mortes)

```
Tu es un ingénieur i18n Flutter. Ta mission : supprimer les clés ARB
inutilisées pour alléger la codebase.

## CONTEXTE
- Branche : feature/w13-arb-cleanup
- Run flutter gen-l10n + flutter analyze + flutter test AVANT et APRÈS

## CE QU'IL FAUT FAIRE

### 1. Identifier les clés inutilisées
Script à exécuter :
```bash
# Extraire toutes les clés du FR ARB (sans les @metadata)
grep -oP '"(\w+)":' apps/mobile/lib/l10n/app_fr.arb | grep -v '^"@' | tr -d '":' | sort > /tmp/arb_keys.txt

# Chercher chaque clé dans le code Dart (hors l10n/)
while read key; do
  count=$(grep -r "\\.$key\\b\|'$key'" apps/mobile/lib/ --include="*.dart" -l | grep -v l10n/ | wc -l)
  if [ "$count" -eq 0 ]; then
    echo "$key"
  fi
done < /tmp/arb_keys.txt > /tmp/unused_keys.txt
```

### 2. Supprimer les clés CONFIRMÉES inutilisées
Pour CHAQUE clé dans unused_keys.txt :
1. Supprimer la clé ET son @metadata dans les 6 ARB files
2. NE PAS supprimer si la clé est utilisée dynamiquement (string interpolation)

### 3. Focus prioritaire — supprimer les préfixes connus morts :
- `advisorMini*` (149 clés — ancien flow advisor)
- `advisorReadiness*` (4 clés)
- Toute clé commençant par un préfixe qui n'a AUCUNE référence dans le code

### 4. Supprimer les 3 méthodes deprecated
- retirement_service.dart : computeMonthlyRenteFromContributions()
- api_service.dart : méthode marquée @Deprecated
- coach_llm_service.dart : méthode marquée @Deprecated

### VALIDATION
1. flutter gen-l10n — 0 errors
2. flutter analyze — 0 errors
3. flutter test — tous passent
4. Compter : echo "Clés supprimées : $(wc -l /tmp/unused_keys.txt)"
5. git commit: "chore(i18n): W13 — delete ~1460 unused ARB keys + 3 deprecated methods"
```

---

## PROMPT 9 — W13 Fix : Scenario FK + missing indexes (from W12 residual)

```
Tu es un DBA senior. Vérifie et corrige les derniers problèmes
de schéma database.

## CONTEXTE
- Branche : feature/w13-db-schema
- Run pytest tests/ -q AVANT et APRÈS

## FIXES

### FIX 1: Créer une migration Alembic pour les nouveaux indexes
```bash
cd services/backend
alembic revision --autogenerate -m "w13_indexes_and_cleanup"
```
Vérifier que la migration auto-générée inclut :
- Index sur audit_event.created_at (si pas déjà fait en Grade A)
- Compound index (user_id, timestamp) sur analytics_events
- FK scenario.profile_id → profiles.id (si pas déjà corrigé)

Si la migration est vide (tout déjà appliqué), supprimer le fichier.

### FIX 2: Vérifier la chaîne de migrations
```bash
alembic history
alembic check
```
S'assurer que la chaîne est linéaire (pas de forks).

### VALIDATION
1. alembic upgrade head — pas d'erreur
2. pytest tests/ -q — tous passent
3. git commit: "fix(db): W13 — migration for indexes and FK cleanup"
```

---

## PROMPT 10 — W13 Fix : Naive datetimes backend

```
Tu es un ingénieur Python senior. Tu remplaces TOUS les
datetime.utcnow() par datetime.now(timezone.utc).

## CONTEXTE
- Branche : feature/w13-naive-datetimes
- Run pytest tests/ -q AVANT et APRÈS

## CE QU'IL FAUT FAIRE

### 1. Rechercher toutes les occurrences
```bash
grep -rn "datetime.utcnow\|utcnow()" services/backend/app/ --include="*.py"
```

### 2. Remplacer chaque occurrence
```python
# AVANT :
from datetime import datetime
created_at = datetime.utcnow()

# APRÈS :
from datetime import datetime, timezone
created_at = datetime.now(timezone.utc)
```

### 3. Vérifier les schemas aussi
File: services/backend/app/schemas/session.py
```python
# AVANT : default_factory=datetime.utcnow
# APRÈS : default_factory=lambda: datetime.now(timezone.utc)
```

### 4. Vérifier les modèles
Files: services/backend/app/models/*.py
Même remplacement pour tous les `default=datetime.utcnow`.

### VALIDATION
1. grep "utcnow" services/backend/ -r → 0 résultat
2. pytest tests/ -q — tous passent
3. git commit: "fix(backend): W13 — replace deprecated utcnow() with now(timezone.utc)"
```

---

## ORCHESTRATION

```
Tu es un orchestrateur de sprint. Ta mission : lancer les 10 prompts
du fichier docs/W13_GRADE_A_PROMPTS.md.

## RÈGLES
- Chaque prompt = sa propre feature branch depuis dev
- flutter analyze + flutter test + pytest tests/ -q après chaque merge
- Ne JAMAIS push sur dev/staging/main directement

## PLAN D'EXÉCUTION

### VAGUE 1 — W13 fixes indépendants (parallèle)
| Agent | Prompt | Branch | Fichiers |
|-------|--------|--------|----------|
| A | P5 (Provider state) | feature/w13-provider-state | app.dart, coach_profile_provider, locale_provider, subscription_provider |
| B | P6 (API contracts) | feature/w13-api-contracts | endpoints/*.py, schemas/*.py |
| C | P8 (ARB cleanup) | feature/w13-arb-cleanup | l10n/*.arb, 3 deprecated methods |
| D | P10 (Naive datetimes) | feature/w13-naive-datetimes | models/*.py, schemas/*.py, services/*.py |

Merger dans cet ordre : D → C → B → A

### VAGUE 2 — Features AVS (parallèle, indépendants)
| Agent | Prompt | Branch | Fichiers |
|-------|--------|--------|----------|
| E | P1 (Échelle 44) | feature/grade-a-echelle44-avs | avs_calculator.dart, social_insurance.dart, registry.py |
| F | P2 (AVS splitting) | feature/grade-a-avs-splitting | avs_calculator.dart (sections différentes de P1) |

ATTENTION : P1 et P2 touchent avs_calculator.dart.
P1 modifie renteFromRAMD() (lookup table).
P2 ajoute des params à computeMonthlyRente() (splitting).
Sections différentes → merger P1 AVANT P2.

### VAGUE 3 — Refactoring (séquentiel, gros changement)
| Agent | Prompt | Branch |
|-------|--------|--------|
| G | P3 (Refactoring coach_chat) | feature/grade-a-refactor-coach-chat |

Merger G → dev. Vérifier TOUS les tests.

### VAGUE 4 — Performance (après refactoring)
| Agent | Prompt | Branch |
|-------|--------|--------|
| H | P4 (Selector/RepaintBoundary) | feature/grade-a-performance |

Merger H → dev.

### VAGUE 5 — Cleanup final (parallèle)
| Agent | Prompt | Branch |
|-------|--------|--------|
| I | P7 (Calc guards) | feature/w13-calc-guards |
| J | P9 (DB schema) | feature/w13-db-schema |

Merger I, J → dev.

### VÉRIFICATION FINALE
1. flutter analyze — 0 errors
2. flutter test — tous passent
3. flutter gen-l10n — 0 errors
4. pytest tests/ -q — tous passent
5. git diff main --stat
6. grep "utcnow" services/backend/ -r → 0
7. grep "advisorMini" apps/mobile/lib/l10n/ → 0

## CRITÈRES DE SUCCÈS
- 10/10 branches mergées
- 0 test failures
- coach_chat_screen.dart < 1000 lignes
- AVS interpolation concave (Échelle 44)
- MintStateProvider auto-recompute wired
- ~1460 ARB keys supprimées
- 0 datetime.utcnow() dans le backend
```
