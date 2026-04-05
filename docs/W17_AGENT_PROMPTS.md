# W17 — "MINT POUR TOUS" — Agent Prompts

> **⚠️ LEGACY NOTE (2026-04-05):** Sprint history. Uses "chiffre choc" (legacy → "premier éclairage", see `docs/MINT_IDENTITY.md`).
>
> **Diagnostic** : MINT est une app de retraite déguisée en app de vie financière.
> 45% des écrans sont centrés retraite. 0 écran s'adapte par âge.
> 3'700 lignes d'infra lifecycle existent mais n'atteignent jamais l'utilisateur.
>
> **Mission W17** : Faire que chaque écran sache à qui il parle.
> Un mec de 22 ans ne voit PAS la même app qu'une femme de 58 ans.
>
> Branche : `feature/S17-mint-pour-tous` depuis `dev`
> Lire CLAUDE.md et rules.md AVANT de coder.

---

## P1 — EXPLORER ADAPTATIF (Dart Agent)

### Fichier scope EXCLUSIF
- `apps/mobile/lib/screens/main_tabs/explore_tab.dart`

### Problème
Les 7 hubs Explorer sont affichés dans le MÊME ordre pour tous les âges.
"Retraite" est en position #1. Un utilisateur de 22 ans voit "Retraite" avant "Travail".
L'infrastructure existe : `LifecyclePhaseService` retourne une phase avec des priorités pondérées. `ContentAdapterService` retourne des feature flags. Aucun des deux n'est lu par cet écran.

### Tâche

**1. Importer et détecter la phase lifecycle**

```dart
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
```

Dans le `build()`, récupérer le profil et détecter la phase :
```dart
final profile = context.watch<CoachProfileProvider>().profile;
final phase = profile != null
    ? LifecyclePhaseService.detect(profile)
    : null;
```

**2. Réordonner les hubs selon la phase**

Créer une map d'ordre par phase :

```dart
static const Map<LifecyclePhase, List<String>> _hubOrder = {
  LifecyclePhase.demarrage: ['travail', 'fiscalite', 'logement', 'sante', 'famille', 'patrimoine', 'retraite'],
  LifecyclePhase.construction: ['logement', 'fiscalite', 'travail', 'famille', 'retraite', 'patrimoine', 'sante'],
  LifecyclePhase.acceleration: ['fiscalite', 'logement', 'retraite', 'patrimoine', 'famille', 'travail', 'sante'],
  LifecyclePhase.consolidation: ['retraite', 'fiscalite', 'patrimoine', 'logement', 'famille', 'sante', 'travail'],
  LifecyclePhase.transition: ['retraite', 'patrimoine', 'fiscalite', 'sante', 'logement', 'famille', 'travail'],
  LifecyclePhase.retraite: ['retraite', 'sante', 'patrimoine', 'fiscalite', 'famille', 'logement', 'travail'],
  LifecyclePhase.transmission: ['patrimoine', 'famille', 'sante', 'retraite', 'fiscalite', 'logement', 'travail'],
};
```

Logique :
- 18-24 (démarrage) → Travail #1 (premier job), Fiscalité #2 (premiers impôts), Retraite en dernier
- 25-34 (construction) → Logement #1 (acheter), Fiscalité #2, Retraite au milieu
- 35-44 (accélération) → Fiscalité #1 (optimiser), Retraite commence à monter
- 45-54 (consolidation) → Retraite #1, Fiscalité #2
- 55-64 (transition) → Retraite #1, Patrimoine #2 (succession commence)
- 65+ → Retraite #1 (mais "vivre sa retraite", pas "préparer")
- 75+ → Patrimoine #1 (transmission)

**3. Construire les hub cards depuis une liste ordonnée**

Aujourd'hui les 7 `_ExploreHubCard` sont hardcodés dans le `build()`. Les remplacer par une liste générée :

```dart
final orderedHubKeys = phase != null
    ? _hubOrder[phase.phase]!
    : _hubOrder[LifecyclePhase.acceleration]!; // default milieu de vie

final hubCards = orderedHubKeys.map((key) => _buildHubCard(key, l10n)).toList();
```

Créer `_buildHubCard(String key, S l10n)` qui retourne le `_ExploreHubCard` correspondant (switch sur les 7 clés). Reprendre EXACTEMENT les widgets existants — juste changer l'ORDRE.

**4. NE PAS masquer de hubs**

Tous les 7 hubs restent visibles. On change l'ORDRE, pas la visibilité. L'utilisateur peut toujours tout explorer. Mais ce qui est PERTINENT est en haut.

### Contraintes
- NE PAS modifier d'autres fichiers
- NE PAS ajouter de clés ARB (les textes existants suffisent)
- Garder TOUTES les animations existantes (MintEntrance delays)
- `flutter analyze` = 0 issues
- Si `profile == null` (pas de profil), utiliser l'ordre par défaut (accélération = le plus neutre)

### Test de validation
```
# Vérifier que LifecyclePhaseService est importé et utilisé
grep -n "LifecyclePhaseService" apps/mobile/lib/screens/main_tabs/explore_tab.dart
# Doit retourner au moins 1 ligne ✅
```

---

> **P2 — SUPPRIMÉ** : Le Pulse affiche déjà Budget (marge mensuelle) par défaut depuis le 2026-03-22 (ADR pulse_screen.dart:468). Le hero number N'EST PAS retraite pour les jeunes. Ce prompt est obsolète et aurait cassé ce qui marche.

---

## P3 — ONBOARDING REWIRE (Dart Agent)

### Fichier scope EXCLUSIF
- `apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart`
- `apps/mobile/lib/screens/landing_screen.dart`
- ARB files : 6 nouvelles clés `chocQuestion*` dans les 6 fichiers `lib/l10n/app_*.arb`

### Problème (3 câbles coupés)
1. L'instant chiffre choc ne call PAS `ChiffreChocSelector` → 18 ans voit "retraite"
2. La question post-chiffre-choc est générique ("Qu'est-ce que tu ressens ?")
3. L'émotion post-chiffre-choc va à `/auth/register` → perdue
4. Le landing ne passe PAS `birthYear` dans le route extra de "Calculer"

### Tâche

**1. Landing : ajouter `birthYear` au route extra**

Fichier `landing_screen.dart`, méthode `_onCalculate()` (lignes 518-526).
Ajouter `'birthYear': _birthYear!` dans le map `extra`.

**2. Landing : "Commencer" utilise les données si disponibles**

Méthode `_onCtaTap()` (lignes 85-97). Si les 3 champs sont remplis (`_canCalculate == true`), appeler `_onCalculate()` au lieu de `/onboarding/quick`. L'utilisateur passe par le chiffre choc, pas par le QuickStart.

```dart
void _onCtaTap() async {
  _analytics.trackCTAClick('cta_commencer_clicked', screenName: '/');
  if (_canCalculate) {
    _onCalculate(); // Même flux que "Calculer"
    return;
  }
  // Pas de données → ancien comportement
  final isCompleted = await ReportPersistenceService.isCompleted();
  final isMiniCompleted = await ReportPersistenceService.isMiniOnboardingCompleted();
  if (mounted) {
    (isCompleted || isMiniCompleted) ? context.go('/home') : context.go('/onboarding/quick');
  }
}
```

**3. Instant chiffre choc : appeler ChiffreChocSelector**

Dans `instant_chiffre_choc_screen.dart`, remplacer l'affichage hardcodé par le `ChiffreChoc` sélectionné.

a) Ajouter les imports :
```dart
import 'package:mint_mobile/services/minimal_profile_service.dart';
import 'package:mint_mobile/services/chiffre_choc_selector.dart';
import 'package:mint_mobile/models/minimal_profile_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
```

b) Ajouter des champs d'état :
```dart
ChiffreChoc? _choc;
int? _birthYear;
double _grossSalary = 0;
```

c) Dans `_loadFromRouteExtra()`, après extraction du route extra :
```dart
_birthYear = extra['birthYear'] as int?;
_grossSalary = (extra['grossSalary'] as num?)?.toDouble() ?? 0;
final age = _birthYear != null ? DateTime.now().year - _birthYear! : 35;

// Construire un profil minimal et sélectionner le chiffre choc
final profile = MinimalProfileService.computeLocally(
  age: age,
  grossAnnualSalary: _grossSalary,
  canton: _canton,
);
_choc = ChiffreChocSelector.select(profile);
```

ATTENTION : Vérifier la signature exacte de `MinimalProfileService.computeLocally()`. Lire le fichier `minimal_profile_service.dart` pour confirmer. Si la méthode est async, utiliser `await` et convertir `_loadFromRouteExtra` en `Future<void>`.

d) Adapter l'affichage du `MintHeroNumber` :
```dart
// Utiliser _choc au lieu de _monthlyTotal/_replacementPercent
MintHeroNumber(
  value: _choc?.value ?? _formatChf(_monthlyTotal),
  caption: _choc?.title ?? '$_replacementPercent\u00a0% de ton revenu actuel',
  color: _chocColor(_choc?.colorKey),
)
```

e) Adapter le glossaire : si `_choc?.type != retirementIncome && _choc?.type != retirementGap`, NE PAS afficher "AVS + LPP" (hors sujet pour compound growth).

**4. Question ciblée par type de choc**

Ajouter 6 clés ARB (dans les 6 fichiers, à la FIN avant `}`) :

```json
"chocQuestionCompoundGrowth": "Tu savais que le temps comptait autant\u00a0?",
"chocQuestionTaxSaving": "CHF {amount} d'imp\u00f4ts en moins. \u00c7a vaut 10 minutes\u00a0?",
"@chocQuestionTaxSaving": {"placeholders": {"amount": {"type": "String"}}},
"chocQuestionRetirementGap": "CHF {amount} de moins par mois. Tu y avais pens\u00e9\u00a0?",
"@chocQuestionRetirementGap": {"placeholders": {"amount": {"type": "String"}}},
"chocQuestionRetirementIncome": "{percent}\u00a0%, \u00e7a te suffit\u00a0?",
"@chocQuestionRetirementIncome": {"placeholders": {"percent": {"type": "String"}}},
"chocQuestionLiquidity": "Moins de {months} mois de r\u00e9serve. On en parle\u00a0?",
"@chocQuestionLiquidity": {"placeholders": {"months": {"type": "String"}}},
"chocQuestionHourlyRate": "CHF {rate} de l'heure. C'est ce que tu vaux\u00a0?",
"@chocQuestionHourlyRate": {"placeholders": {"rate": {"type": "String"}}}
```

Pour les 5 fichiers non-FR (en, de, es, it, pt) : traduire les questions. Pas de placeholder `@` en double.

Mapper dans le code :
```dart
String _questionForChoc(ChiffreChoc choc, S l10n) {
  return switch (choc.type) {
    ChiffreChocType.compoundGrowth => l10n.chocQuestionCompoundGrowth,
    ChiffreChocType.taxSaving3a => l10n.chocQuestionTaxSaving(choc.value),
    ChiffreChocType.retirementGap => l10n.chocQuestionRetirementGap(choc.value),
    ChiffreChocType.retirementIncome => l10n.chocQuestionRetirementIncome(
        '${(_choc!.rawValue > 0 && _grossSalary > 0 ? ((_choc!.rawValue / (_grossSalary / 12)) * 100).round() : 0)}'),
    ChiffreChocType.liquidityAlert => l10n.chocQuestionLiquidity(choc.value),
    ChiffreChocType.hourlyRate => l10n.chocQuestionHourlyRate(choc.value),
  };
}
```

Remplacer `l10n.chiffreChocSilenceQuestion` par `_questionForChoc(_choc!, l10n)` dans le moment de silence.

**5. Stocker les données d'onboarding + router vers la promesse**

Remplacer `_navigateToRegister()` :

```dart
Future<void> _navigateAfterEmotion() async {
  final userFeeling = _responseController.text.trim();
  final prefs = await SharedPreferences.getInstance();

  // Stocker pour le coach (lu par Agent P5)
  if (userFeeling.isNotEmpty) {
    await prefs.setString('onboarding_emotion', userFeeling);
  }
  if (_birthYear != null) await prefs.setInt('onboarding_birth_year', _birthYear!);
  await prefs.setDouble('onboarding_gross_salary', _grossSalary);
  await prefs.setString('onboarding_canton', _canton);
  await prefs.setString('onboarding_choc_type', _choc?.type.name ?? 'retirementIncome');
  await prefs.setDouble('onboarding_choc_value', _choc?.rawValue ?? 0);

  if (mounted) context.go('/auth/register');
}
```

NB : On route vers `/auth/register` (pas `/onboarding/promise`). L'écran promesse sera créé dans un sprint suivant. Pour W17, l'essentiel est que les données soient STOCKÉES et que le coach les LISE.

**6. Lancer `flutter gen-l10n` après les ARB**

### Contraintes
- NE PAS modifier `quick_start_screen.dart` (Agent P4)
- NE PAS modifier `coach_chat_screen.dart` (Agent P5)
- NE PAS créer de nouveaux écrans
- Tous les strings via ARB
- `flutter analyze` = 0 issues

### Tests de validation
```
# Câble 1 : birthYear dans le route extra du landing
grep -n "'birthYear'" apps/mobile/lib/screens/landing_screen.dart
# ✅ Doit trouver 'birthYear': _birthYear!

# Câble 2 : ChiffreChocSelector appelé dans instant flow
grep -n "ChiffreChocSelector" apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
# ✅ Doit trouver ChiffreChocSelector.select

# Câble 3 : Question ciblée (plus de générique)
grep -n "chiffreChocSilenceQuestion" apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
# ✅ NE DOIT PAS trouver (remplacé par chocQuestion*)

# Câble 4 : Émotion stockée dans SharedPreferences
grep -n "onboarding_emotion" apps/mobile/lib/screens/onboarding/instant_chiffre_choc_screen.dart
# ✅ Doit trouver prefs.setString('onboarding_emotion'
```

---

## P4 — QUICKSTART PRE-FILL + DEMOTION (Dart Agent)

### Fichier scope EXCLUSIF
- `apps/mobile/lib/screens/onboarding/quick_start_screen.dart`

### Problème
Defaults hardcodés (1981, 85000, ZH). Ne lit pas les données du landing. Si l'utilisateur a déjà saisi ses 3 champs sur le landing, le QuickStart les redemande.

### Pré-requis : corriger les defaults hardcodés

AVANT le pre-fill, changer les defaults initiaux (lignes ~49-51 du fichier) :
```dart
// AVANT (absurde — un 19 ans voit 1981 et 85000)
int _birthYear = 1981;
double _salary = 85000;
String _canton = 'ZH';

// APRÈS (neutre — médiane suisse, milieu de vie)
int _birthYear = DateTime.now().year - 30;
double _salary = 60000;  // Médiane salaire brut suisse
String _canton = 'ZH';   // ZH = canton le plus peuplé, OK comme default
```

### Tâche

**1. Lire les données d'onboarding depuis SharedPreferences**

Ajouter dans `initState()`, après `_checkAndRequestConsent()` :

```dart
_prefillFromOnboardingData();
```

Implémenter :
```dart
Future<void> _prefillFromOnboardingData() async {
  final prefs = await SharedPreferences.getInstance();
  final birthYear = prefs.getInt('onboarding_birth_year');
  final salary = prefs.getDouble('onboarding_gross_salary');
  final canton = prefs.getString('onboarding_canton');

  if (mounted) {
    setState(() {
      if (birthYear != null && birthYear >= 1940 && birthYear <= 2010) _birthYear = birthYear;
      if (salary != null && salary > 0) _salary = salary;
      if (canton != null && canton.isNotEmpty && _cantons.contains(canton)) _canton = canton;
    });
  }
}
```

**Ordre de priorité** : route extra > SharedPreferences > CoachProfileProvider > defaults hardcodés.

Lire aussi le route extra dans `didChangeDependencies()` :
```dart
@override
void didChangeDependencies() {
  super.didChangeDependencies();
  final extra = GoRouterState.of(context).extra;
  if (extra is Map<String, dynamic>) {
    final by = extra['birthYear'] as int?;
    final gs = (extra['grossSalary'] as num?)?.toDouble();
    final ct = extra['canton'] as String?;
    setState(() {
      if (by != null) _birthYear = by;
      if (gs != null && gs > 0) _salary = gs;
      if (ct != null && ct.isNotEmpty) _canton = ct;
    });
  }
}
```

Vérifier que `_cantons` est accessible (liste des 26 cantons). Si c'est `private`, utiliser la liste depuis `social_insurance.dart` ou la déclarer localement.

### Contraintes
- NE PAS modifier d'autres fichiers
- NE PAS ajouter de clés ARB
- `flutter analyze` = 0 issues
- Le QuickStart doit continuer à fonctionner SANS données pré-remplies (fallback aux defaults)

### Test de validation
```
grep -n "onboarding_birth_year\|onboarding_gross_salary\|onboarding_canton" apps/mobile/lib/screens/onboarding/quick_start_screen.dart
# ✅ Doit trouver les 3 clés lues depuis SharedPreferences
```

---

## P5 — COACH REÇOIT LE PAYLOAD (Dart Agent)

### Fichier scope EXCLUSIF
- `apps/mobile/lib/screens/coach/coach_chat_screen.dart`
- `apps/mobile/lib/services/coach/context_injector_service.dart`

### Problème
Le coach ne sait RIEN de ce qui s'est passé avant (chiffre choc vu, émotion, type de choc). Toute la richesse de l'onboarding est perdue quand l'utilisateur arrive au chat. L'infrastructure existe (`ContextInjectorService.buildContext()`) mais aucun block "onboarding" n'est injecté.

### Tâche

**1. Coach lit le payload d'onboarding**

Dans `coach_chat_screen.dart`, à l'initialisation (méthode `initState` ou équivalent post-frame) :

```dart
Future<void> _loadOnboardingPayload() async {
  final prefs = await SharedPreferences.getInstance();
  final emotion = prefs.getString('onboarding_emotion');
  final chocType = prefs.getString('onboarding_choc_type');
  final chocValue = prefs.getDouble('onboarding_choc_value');

  if (emotion != null || chocType != null) {
    setState(() {
      _onboardingEmotion = emotion;
      _onboardingChocType = chocType;
      _onboardingChocValue = chocValue;
    });

    // Clear one-shot data (ne pas polluer les sessions suivantes)
    await prefs.remove('onboarding_emotion');
    await prefs.remove('onboarding_choc_type');
    await prefs.remove('onboarding_choc_value');
    // Garder birth_year, salary, canton (profil permanent)
  }
}
```

Ajouter les champs d'état :
```dart
String? _onboardingEmotion;
String? _onboardingChocType;
double? _onboardingChocValue;
```

**2. Auto-envoyer l'émotion comme premier message**

Si `widget.initialPrompt == null` ET `_onboardingEmotion != null` ET l'émotion n'est pas vide :
```dart
if (widget.initialPrompt == null && _onboardingEmotion != null && _onboardingEmotion!.isNotEmpty) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _sendMessage(_onboardingEmotion!);
  });
}
```

Ainsi, le premier message du coach RÉAGIT à ce que l'utilisateur a ressenti au chiffre choc.

**3. Injecter le block onboarding dans le system prompt**

Dans `context_injector_service.dart`, dans la méthode `buildContext()`, ajouter une section :

```dart
// --- Onboarding context (one-shot) ---
static Future<String> _buildOnboardingBlock() async {
  final prefs = await SharedPreferences.getInstance();
  final chocType = prefs.getString('onboarding_choc_type');
  if (chocType == null) return '';

  final chocValue = prefs.getDouble('onboarding_choc_value');
  final emotion = prefs.getString('onboarding_emotion');
  final birthYear = prefs.getInt('onboarding_birth_year');

  final buf = StringBuffer();
  buf.writeln('\n--- CONTEXTE ONBOARDING ---');
  buf.writeln('Chiffre choc montré : $chocType (valeur: ${chocValue?.toStringAsFixed(0) ?? "??"})');
  if (emotion != null && emotion.isNotEmpty) {
    buf.writeln('Réaction utilisateur : "$emotion"');
  }
  if (birthYear != null) {
    final age = DateTime.now().year - birthYear;
    buf.writeln('Âge : $age ans');
  }
  buf.writeln('INSTRUCTION : Réagis au chiffre choc et à l\'émotion. Propose 3 actions concrètes avec des chiffres. Ne redemande PAS les informations déjà connues.');
  buf.writeln('--- FIN ONBOARDING ---');
  return buf.toString();
}
```

Appeler cette méthode dans `buildContext()` et concaténer au memory block :
```dart
final onboardingBlock = await _buildOnboardingBlock();
// Ajouter au memoryBlock existant
memoryBlock = '$memoryBlock$onboardingBlock';
```

ATTENTION : Vérifier la structure exacte de `buildContext()` avant de modifier. Lire le fichier d'abord. Ne pas casser les sections existantes (lifecycle, memory, goals, nudges, budget, screens).

### Contraintes
- NE PAS modifier les fichiers des autres agents
- NE PAS modifier le backend
- Garder le fallback : si aucun payload, comportement inchangé
- `flutter analyze` = 0 issues
- Le block onboarding est ONE-SHOT : lu une fois, puis supprimé des prefs (pour ne pas polluer les sessions suivantes)

### Tests de validation
```
# Câble 1 : Coach lit le payload
grep -n "onboarding_emotion\|onboarding_choc_type" apps/mobile/lib/screens/coach/coach_chat_screen.dart
# ✅ Doit trouver la lecture depuis SharedPreferences

# Câble 2 : ContextInjector injecte le block
grep -n "CONTEXTE ONBOARDING" apps/mobile/lib/services/coach/context_injector_service.dart
# ✅ Doit trouver la section
```

---

## P6 — CONTENT GATING PAR LIFECYCLE (Dart Agent)

### Fichier scope EXCLUSIF
- `apps/mobile/lib/screens/explore/retraite_hub_screen.dart`
- `apps/mobile/lib/screens/explore/patrimoine_hub_screen.dart`

### Problème
Le RetraiteHubScreen montre 10 outils retraite (rachat LPP, décaissement, rente vs capital, etc.) sans AUCUN filtre d'âge. Un utilisateur de 22 ans voit "Optimisation du décaissement" — c'est absurde.
Le PatrimoineHubScreen montre succession et donation à un mec de 25 ans.
`ContentAdapterService` retourne des feature flags (`showLppBuyback`, `showWithdrawalSequencing`, `showEstatePlanning`) mais AUCUN écran ne les lit.

### Tâche

**1. RetraiteHubScreen : filtrer les outils par lifecycle**

Importer `ContentAdapterService` et `LifecyclePhaseService` :
```dart
import 'package:mint_mobile/services/content_adapter_service.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';
```

Détecter la phase et obtenir l'adaptation :
```dart
final profile = context.watch<CoachProfileProvider>().profile;
final phase = profile != null ? LifecyclePhaseService.detect(profile) : null;
final adaptation = phase != null ? ContentAdapterService().adapt(phase, profile!) : null;
```

ATTENTION : Vérifier la signature exacte de `ContentAdapterService.adapt()`. Lire le fichier d'abord. Les noms des feature flags et la structure de `ContentAdaptation` doivent être confirmés.

Conditionner les outils avancés :
```dart
// Outils toujours visibles (tous âges)
_buildAlwaysVisibleTools(l10n),

// Outils conditionnels
if (adaptation?.showLppBuyback ?? true)
  _HubItemCard(title: l.retraiteHubRachatLpp, ...),
if (adaptation?.showWithdrawalSequencing ?? true)
  _HubItemCard(title: l.retraiteHubDecaissement, ...),
// etc.
```

Si `adaptation == null` (pas de profil), montrer TOUT (fallback permissif).

**2. PatrimoineHubScreen : conditionner succession/donation**

Même logique :
```dart
if (adaptation?.showEstatePlanning ?? true)
  _HubItemCard(title: l.patrimoineHubSuccession, ...),
```

**3. Ajouter un message éducatif pour les jeunes**

Si l'utilisateur est en phase démarrage/construction et accède au hub retraite, ajouter un petit badge informatif en haut :

```dart
if (phase?.phase == LifecyclePhase.demarrage || phase?.phase == LifecyclePhase.construction)
  Padding(
    padding: const EdgeInsets.only(bottom: MintSpacing.md),
    child: MintSurface(
      tone: MintSurfaceTone.craie,
      padding: const EdgeInsets.all(MintSpacing.md),
      child: Text(
        l10n.retraiteHubYoungDisclaimer,  // "C'est bien de s'y intéresser tôt. Les outils avancés apparaîtront quand ils seront pertinents pour toi."
        style: MintTextStyles.bodySmall(color: MintColors.textMuted),
      ),
    ),
  ),
```

Ajouter la clé ARB correspondante (6 fichiers).

### Contraintes
- NE PAS modifier d'autres fichiers
- NE PAS masquer le hub lui-même (seulement les outils à l'intérieur)
- Si `profile == null` → tout montrer (pas de régression)
- `flutter analyze` = 0 issues

### Tests de validation
```
# ContentAdapterService utilisé dans les hubs
grep -n "ContentAdapterService\|showLppBuyback\|showEstatePlanning" apps/mobile/lib/screens/explore/retraite_hub_screen.dart
# ✅ Doit trouver au moins 1 référence

grep -n "ContentAdapterService\|showEstatePlanning" apps/mobile/lib/screens/explore/patrimoine_hub_screen.dart
# ✅ Doit trouver au moins 1 référence
```
