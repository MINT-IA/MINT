# BLUEPRINT : MINT Coach AI Layer — Mission Document

> **Scope**: Architecture technique du Coach AI (services, data flow, cache, guardrails).
> **Companions**: UX_REDESIGN_COACH.md (ce que l'utilisateur voit), MINT_COACH_VIVANT_ROADMAP.md (plan d'execution sprint).

> **Objectif** : Transformer MINT d'un conseiller financier reactif en une couche coach plus proactive, narrative et utile.
> **Principe** : Le LLM (BYOK) ne repond plus seulement aux questions. Il enrichit la narration, la personnalisation et l'orchestration du coach. Le coach n'est pas le produit: il sert le plan, les flows structures et les ecrans de preuve. Sans BYOK, l'app fonctionne exactement comme aujourd'hui (zero degradation).
> **Source de vérité** : partielle. Référence technique pour la couche coach IA, subordonnée au `MINT_UX_GRAAL_MASTERPLAN.md`.
> **Ne couvre pas** : vision umbrella, navigation globale, design system, taxonomie écran par écran.

---

## ARCHITECTURE CIBLE

```
CoachNarrativeService (NOUVEAU)
├── Input: CoachProfile + ScoreHistory + CheckIns + UserActivity + DateTime.now()
├── Engine: BYOK via RagService (si configure) OU templates statiques (fallback)
├── Output: CoachNarrative (greeting, scoreSummary, tips enrichis, chiffreChoc, trendMessage, milestoneAlert, scenarioNarration)
├── Cache: SharedPreferences, 24h TTL, cle = "coach_narrative_{yyyy-MM-dd}"
└── Guardrails: Compliance filter + disclaimers (existants dans coach_llm_service.dart)
```

**Principe dual obligatoire** : CHAQUE feature doit fonctionner en 2 modes :
- **Mode BYOK** : texte genere par LLM (personnalise, narratif, emotionnel)
- **Mode fallback** : templates statiques actuels (zero regression)

Le check se fait via `context.read<ByokProvider>().isConfigured`.

---

## CONVENTIONS TECHNIQUES (NON-NEGOTIABLE)

### Dart/Flutter
- **State** : Provider (ChangeNotifier). Jamais de setState hors widgets locaux.
- **Navigation** : GoRouter. Routes declarees dans `app.dart`.
- **Fonts** : `MintTextStyles` uniquement. Jamais de `GoogleFonts.*` ad hoc dans les écrans/widgets.
- **Colors** : `MintColors` de `lib/theme/colors.dart`. Jamais de couleurs hardcodees.
- **Style** : suivre `DESIGN_SYSTEM.md` et le template maître de l'écran concerné.
- **Imports** : `package:mint_mobile/...` — jamais de chemins relatifs.
- **Textes FR** : Tutoiement ("tu"), inclusif ("un·e specialiste"), jamais prescriptif.
- **Termes bannis** : `garanti`, `certain`, `assure`, `sans risque`, `optimal`, `meilleur`, `parfait`.
- **Disclaimer obligatoire** : "Outil educatif — ne constitue pas un conseil financier. LSFin."

### Fichiers existants a modifier (PAS de nouveaux fichiers sauf indication)
| Fichier | Lignes | Role |
|---------|--------|------|
| `lib/services/coach_llm_service.dart` | ~400 | Orchestrateur LLM existant |
| `lib/services/coaching_service.dart` | ~800 | 13 triggers coaching |
| `lib/screens/coach/coach_dashboard_screen.dart` | ~3400 | Dashboard principal |
| `lib/screens/coach/coach_agir_screen.dart` | ~1900 | Tab Agir |
| `lib/screens/coach/coach_checkin_screen.dart` | ~1466 | Check-in mensuel |
| `lib/widgets/coach/chiffre_choc_card.dart` | ~200 | Carte chiffre choc |
| `lib/services/streak_service.dart` | ~259 | Badges et milestones |
| `lib/app.dart` | ~400 | Router + app lifecycle |
| `lib/screens/main_navigation_shell.dart` | ~200 | Shell + WidgetsBindingObserver |
| `pubspec.yaml` | ~50 | Dependencies |

### Nouveaux fichiers autorises
| Fichier | Role |
|---------|------|
| `lib/services/coach_narrative_service.dart` | **NOUVEAU** — Service central Coach Layer |
| `lib/services/milestone_detection_service.dart` | **NOUVEAU** — Detection de milestones |
| `lib/services/notification_service.dart` | **NOUVEAU** — Local notifications |
| `lib/widgets/coach/milestone_celebration_sheet.dart` | **NOUVEAU** — Bottom sheet celebration |
| `lib/screens/coach/annual_refresh_screen.dart` | **NOUVEAU** — Check-up annuel |
| `test/services/coach_narrative_service_test.dart` | **NOUVEAU** — Tests |
| `test/services/milestone_detection_service_test.dart` | **NOUVEAU** — Tests |

---

## TACHE T1 — CoachNarrativeService (Le Cerveau)

### Fichier : `lib/services/coach_narrative_service.dart` (NOUVEAU)

### Specification

```dart
/// Le Coach Layer central. Genere tout le contenu narratif du dashboard
/// en un seul appel LLM (ou via templates statiques si pas de BYOK).
///
/// Usage :
///   final narrative = await CoachNarrativeService.generate(
///     profile: profile,
///     scoreHistory: scoreHistory,
///     byokConfig: config, // null si pas BYOK
///   );
///   // narrative.greeting, narrative.scoreSummary, etc.
class CoachNarrativeService {
  CoachNarrativeService._();

  /// Genere le narratif complet du dashboard.
  /// Si byokConfig != null et hasApiKey, utilise le LLM.
  /// Sinon, retourne des templates statiques (comportement actuel).
  /// Le resultat est cache 24h dans SharedPreferences.
  static Future<CoachNarrative> generate({
    required CoachProfile profile,
    required List<Map<String, dynamic>>? scoreHistory,
    required List<CoachingTip> tips,
    LlmConfig? byokConfig,
  }) async {
    // 1. Verifier le cache (cle: "coach_narrative_{yyyy-MM-dd}")
    // 2. Si cache valide ET < 24h → retourner depuis cache
    // 3. Si BYOK configure → appel LLM via _generateViaLlm()
    // 4. Sinon → _generateStatic() (templates actuels = zero regression)
    // 5. Sauvegarder en cache
  }
}

/// Resultat narratif du Coach Layer.
class CoachNarrative {
  /// Salutation personnalisee ("Salut Julien, ton score progresse...")
  final String greeting;

  /// Resume du score avec contexte ("62/100 — +4 pts ce mois. Ta discipline 3a paie.")
  final String scoreSummary;

  /// Message de tendance enrichi ("En progression — continue comme ca" OU narratif LLM)
  final String trendMessage;

  /// Tip principal enrichi (le top tip avec narration personnalisee)
  final String? topTipNarrative;

  /// Alerte urgente si applicable ("Il reste 28 jours pour ton 3a")
  final String? urgentAlert;

  /// Message milestone si nouveau ("Bravo ! Tu as atteint CHF 100k de patrimoine")
  final String? milestoneMessage;

  /// Narration des scenarios Forecaster (3 paragraphes)
  final List<String>? scenarioNarrations;

  /// Source (llm ou static) pour debug
  final bool isLlmGenerated;

  /// Timestamp de generation
  final DateTime generatedAt;
}
```

### System Prompt pour le LLM

```
Tu es le coach financier MINT. Tu parles a {firstName}, {age} ans, {etatCivil},
{employmentStatus} dans le canton de {canton}.

DONNEES FINANCIERES :
- Score Financial Fitness : {score}/100 (tendance : {trend})
- Revenu brut annuel : CHF {revenu}
- 3a : {montant3a}/{plafond3a} CHF (nombre comptes : {nombre3a})
- LPP : avoir CHF {avoirLpp}, lacune rachat CHF {lacuneLpp}
- Patrimoine total : CHF {patrimoine}
- Fonds urgence : {moisCouverts} mois (objectif : 3-6 mois)
- Dettes : CHF {dettes}
- Streak check-in : {streak} mois consecutifs
- Dernier check-in : {dernierCheckIn}

TIPS ACTIFS (par priorite) :
{tipsFormatted}

INSTRUCTIONS :
1. Genere un JSON avec les champs : greeting, scoreSummary, trendMessage, topTipNarrative, urgentAlert (null si aucune urgence), milestoneMessage (null si aucun nouveau milestone)
2. Le greeting doit etre personnel et chaleureux (max 2 phrases)
3. Le scoreSummary doit expliquer le score avec les chiffres de l'utilisateur (max 3 phrases)
4. Le trendMessage doit etre contextuel a la trajectoire (max 2 phrases)
5. Le topTipNarrative doit transformer le tip #1 en conseil emotionnel avec impact CHF (max 4 phrases)
6. Utilise le tutoiement ("tu")
7. JAMAIS de termes : garanti, certain, assure, sans risque, optimal, meilleur, parfait
8. Cite les sources legales quand pertinent (LPP art. X, LIFD art. Y)
9. Ton educatif, jamais prescriptif. "Tu pourrais" et non "Tu dois"
10. Reponds UNIQUEMENT en JSON valide
```

### Methode statique (fallback sans BYOK)

```dart
static CoachNarrative _generateStatic({
  required CoachProfile profile,
  required List<Map<String, dynamic>>? scoreHistory,
  required List<CoachingTip> tips,
}) {
  // Reproduire EXACTEMENT le comportement actuel du dashboard :
  // - greeting : "Bonjour {firstName}"
  // - scoreSummary : "{score}/100 — {level.label}"
  // - trendMessage : meme logique que _buildScoreTrendText() actuel
  // - topTipNarrative : tips.first.message (si non vide)
  // - urgentAlert : null (pas d'alerte dans le mode statique actuel)
  // - milestoneMessage : null
  // - scenarioNarrations : null
  // ZERO regression par rapport au comportement actuel
}
```

### Cache Strategy

```dart
static const _cacheKey = 'coach_narrative';
static const _cacheTtlHours = 24;

// Serialiser en JSON dans SharedPreferences
// Cle : "coach_narrative_{yyyy-MM-dd}"
// Invalider si : date differente OU profil.checkIns.length change
```

### Tests requis (`test/services/coach_narrative_service_test.dart`)
1. `generate() sans BYOK retourne template statique` — verifie zero regression
2. `generate() avec BYOK retourne CoachNarrative avec isLlmGenerated=true` (mock RAG)
3. `cache est utilise quand < 24h`
4. `cache est invalide quand > 24h`
5. `cache est invalide quand nouveau check-in`
6. `fallback vers static si LLM echoue` (resilience)
7. `greeting contient firstName`
8. `scoreSummary contient le score numerique`
9. `narratif ne contient pas de termes bannis`
10. `JSON parse du resultat LLM fonctionne`

---

## TACHE T2 — Tips Narratifs (Enrichissement LLM)

### Fichier : `lib/services/coaching_service.dart` (MODIFIER)

### Specification

Ajouter une methode statique `enrichTips()` qui prend les tips generes par `generateTips()` et les enrichit via le Coach Layer :

```dart
/// Enrichit les tips avec des narrations LLM personnalisees.
/// Si pas de BYOK, retourne les tips inchanges.
static Future<List<CoachingTip>> enrichTips({
  required List<CoachingTip> tips,
  required CoachProfile coachProfile,
  required CoachProfile fullProfile, // le CoachProfile complet (pas CoachingProfile)
  LlmConfig? byokConfig,
}) async {
  if (byokConfig == null || !byokConfig.hasApiKey) return tips;
  if (tips.isEmpty) return tips;

  // Enrichir les 3 premiers tips seulement (economie de tokens)
  // Pour chaque tip : envoyer au LLM avec le profil complet
  // Le LLM retourne un message enrichi qui croise toutes les dimensions
  // Remplacer tip.message par la version enrichie
  // Garder tip.title, tip.id, tip.source, tip.estimatedImpactChf intacts
}
```

### System Prompt pour enrichissement

```
Tu es le coach MINT. Voici un conseil financier a personnaliser pour {firstName} :

TIP ORIGINAL :
- Titre : {tip.title}
- Message : {tip.message}
- Impact estime : CHF {tip.estimatedImpactChf}
- Source legale : {tip.source}

PROFIL UTILISATEUR :
{profilComplet}

INSTRUCTION :
Reecris le message du tip en 3-4 phrases max. Personnalise-le en croisant :
- La situation familiale ({etatCivil}, {nombreEnfants} enfants)
- Le statut emploi ({employmentStatus}, {tauxActivite}%)
- L'age et le horizon retraite ({age} ans, {anneesAvantRetraite} ans)
- Les chiffres specifiques de l'utilisateur
Utilise le tutoiement. Ton chaleureux et educatif. Pas de termes bannis.
Retourne UNIQUEMENT le nouveau message (pas de JSON, juste le texte).
```

### Pattern d'appel (dans coach_dashboard_screen.dart)

```dart
// Dans _loadProfile() du dashboard, apres generation des tips :
if (_tips != null && _tips!.isNotEmpty) {
  final byok = context.read<ByokProvider>();
  if (byok.isConfigured) {
    _tips = await CoachingService.enrichTips(
      tips: _tips!,
      coachProfile: _coachingProfile!,
      fullProfile: _profile!,
      byokConfig: LlmConfig(
        apiKey: byok.apiKey!,
        provider: _toLlmProvider(byok.provider!),
        model: byok.model ?? 'gpt-4o',
      ),
    );
    if (mounted) setState(() {});
  }
}
```

---

## TACHE T3 — Chiffre Choc Emotionnel

### Fichier : `lib/widgets/coach/chiffre_choc_card.dart` (MODIFIER)

### Specification

Le `ChiffreChocCard` accepte deja `value`, `message`, `source`, `ctaLabel`, `ctaRoute`. Ajouter un champ optionnel `narrativeMessage` :

```dart
class ChiffreChocCard extends StatelessWidget {
  final double value;
  final String message;          // message actuel (statique)
  final String? narrativeMessage; // NOUVEAU : message LLM (si BYOK)
  final String source;
  final String? ctaLabel;
  final String? ctaRoute;

  // Dans build() : afficher narrativeMessage ?? message
  // Le narrativeMessage est genere par CoachNarrativeService
}
```

### Reframes emotionnels (dans le system prompt CoachNarrative)

Le system prompt du Coach Layer inclut deja les chiffres choc. Ajouter dans les instructions :

```
CHIFFRES CHOC — Transforme chaque chiffre en impact de vie :
- Economie fiscale → "c'est X semaines de vacances" ou "X mois de creche"
- Lacune LPP → "CHF Y de MOINS par mois a la retraite, pendant 20 ans"
- Fonds urgence manquant → "si tu perds ton emploi, tu tiens Z semaines"
- Dettes → "tu paies CHF W d'interets par an — c'est un loyer"
Utilise des comparaisons concretes et quotidiennes, pas des chiffres abstraits.
```

---

## TACHE T4 — Notifications Proactives

### Fichier : `lib/services/notification_service.dart` (NOUVEAU)
### Fichier : `pubspec.yaml` (MODIFIER — ajouter dependency)
### Fichier : `lib/app.dart` (MODIFIER — init)
### Fichier : `lib/screens/main_navigation_shell.dart` (MODIFIER — lifecycle)

### Phase A : Dependencies

Ajouter dans `pubspec.yaml` :
```yaml
dependencies:
  flutter_local_notifications: ^18.0.1
```

### Phase B : NotificationService

```dart
/// Service de notifications locales pour le coaching proactif.
///
/// Notifications schedulees localement (pas de backend, pas de Firebase).
/// Respecte le consentement coaching_notifications.
/// Deep-link vers les ecrans pertinents via GoRouter.
class NotificationService {
  static final NotificationService _instance = NotificationService._();
  factory NotificationService() => _instance;
  NotificationService._();

  late FlutterLocalNotificationsPlugin _plugin;

  /// Init au demarrage de l'app (dans app.dart initState)
  Future<void> init() async { /* ... */ }

  /// Demande la permission notifications (iOS)
  Future<bool> requestPermission() async { /* ... */ }

  /// Schedule les rappels recurrents basees sur le profil
  Future<void> scheduleCoachingReminders({
    required CoachProfile profile,
  }) async {
    await cancelAll(); // Reset

    // 1. Check-in mensuel : 1er du mois a 10h si pas fait
    //    "Check-in mensuel disponible — confirme tes versements en 2 min"

    // 2. Deadline 3a : J-30, J-14, J-7 avant le 31 dec
    //    "Il reste {n} jours pour maximiser ton 3a (CHF {restant} de marge)"

    // 3. Streak a risque : J-25 du mois si pas de check-in
    //    "Tu es a {n} mois consecutifs — ne casse pas ta serie !"

    // 4. Deadline impots : J-30, J-7 avant le 31 mars
    //    "Declaration fiscale dans {n} jours"
  }

  /// Handler de tap sur notification → deep link
  void _onNotificationTap(NotificationResponse response) {
    // Extraire la route du payload
    // Naviguer via GoRouter.of(context).go(route)
  }
}
```

### Phase C : App Lifecycle Detection

Dans `main_navigation_shell.dart`, ajouter `WidgetsBindingObserver` :

```dart
class _MainNavigationShellState extends State<MainNavigationShell>
    with WidgetsBindingObserver {

  DateTime? _lastPauseTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _lastPauseTime = DateTime.now();
    }
    if (state == AppLifecycleState.resumed && _lastPauseTime != null) {
      final away = DateTime.now().difference(_lastPauseTime!);
      if (away.inHours >= 1) {
        // Invalider le cache CoachNarrative pour refresh
        // Afficher snackbar si score a change : "Depuis ta derniere visite : +2 pts"
      }
    }
  }
}
```

---

## TACHE T5 — Milestones Celebrates

### Fichier : `lib/services/milestone_detection_service.dart` (NOUVEAU)
### Fichier : `lib/widgets/coach/milestone_celebration_sheet.dart` (NOUVEAU)
### Fichier : `pubspec.yaml` (MODIFIER — ajouter confetti)

### Phase A : Dependency

```yaml
dependencies:
  confetti: ^0.7.0
```

### Phase B : MilestoneDetectionService

```dart
/// Detecte les nouveaux milestones atteints depuis le dernier check-in.
/// Compare l'etat actuel vs l'etat persiste precedent.
///
/// Milestones detectes :
/// - patrimoine_50k, patrimoine_100k, patrimoine_250k, patrimoine_500k
/// - 3a_max_reached (7'258 CHF verse cette annee)
/// - emergency_fund_3m, emergency_fund_6m (mois couverts)
/// - streak_3, streak_6, streak_12 (mois consecutifs check-in)
/// - score_bon (score >= 60 pour la premiere fois)
/// - score_excellent (score >= 80 pour la premiere fois)
class MilestoneDetectionService {
  MilestoneDetectionService._();

  static const _achievedKey = 'achieved_milestones_v1';

  /// Detecte les nouveaux milestones (pas encore celebres).
  /// Retourne une liste de MilestoneEvent pour celebration.
  static Future<List<MilestoneEvent>> detectNew({
    required CoachProfile profile,
    required int currentScore,
    required StreakResult streak,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final achieved = prefs.getStringList(_achievedKey)?.toSet() ?? {};
    final newMilestones = <MilestoneEvent>[];

    // Verifier chaque milestone
    _checkPatrimoine(profile, achieved, newMilestones);
    _check3aMax(profile, achieved, newMilestones);
    _checkEmergencyFund(profile, achieved, newMilestones);
    _checkStreak(streak, achieved, newMilestones);
    _checkScore(currentScore, achieved, newMilestones);

    // Persister les nouveaux milestones comme "celebres"
    if (newMilestones.isNotEmpty) {
      achieved.addAll(newMilestones.map((m) => m.id));
      await prefs.setStringList(_achievedKey, achieved.toList());
    }

    return newMilestones;
  }
}

class MilestoneEvent {
  final String id;           // "patrimoine_100k"
  final String title;        // "Cap des CHF 100'000"
  final String description;  // "Ton patrimoine a franchi les 100k !"
  final IconData icon;
  final Color color;

  /// Message LLM optionnel (genere si BYOK actif)
  String? narrativeMessage;
}
```

### Phase C : MilestoneCelebrationSheet

```dart
/// Bottom sheet anime avec confetti pour celebrer un milestone.
///
/// Usage : apres un check-in, si MilestoneDetectionService.detectNew()
/// retourne des resultats, afficher ce sheet.
class MilestoneCelebrationSheet extends StatefulWidget {
  final MilestoneEvent milestone;
  const MilestoneCelebrationSheet({required this.milestone});
}

// Build :
// 1. ConfettiWidget (blast from center, 3 seconds)
// 2. Icon anime (scale + bounce, elasticOut)
// 3. Titre en Montserrat bold
// 4. Description (ou narrativeMessage si BYOK)
// 5. CTA "Continuer" qui dismiss le sheet
// 6. Fond : gradient leger vert/or
```

### Integration dans coach_checkin_screen.dart

Apres `_submitCheckIn()` et la celebration existante, ajouter :

```dart
// Detecter les nouveaux milestones
final milestones = await MilestoneDetectionService.detectNew(
  profile: _profile!,
  currentScore: newScore,
  streak: StreakService.compute(_profile!),
);

// Celebrer chaque milestone avec un delai
for (final milestone in milestones) {
  // Si BYOK, enrichir le message
  if (byok.isConfigured) {
    milestone.narrativeMessage = await _generateMilestoneNarrative(milestone);
  }
  await showModalBottomSheet(
    context: context,
    builder: (_) => MilestoneCelebrationSheet(milestone: milestone),
  );
}
```

---

## TACHE T6 — Refresh Annuel

### Fichier : `lib/screens/coach/annual_refresh_screen.dart` (NOUVEAU)

### Specification

Flow leger de 7 questions pour mettre a jour les donnees critiques :

```dart
/// Ecran de refresh annuel du profil financier.
/// Affiche quand le profil a > 11 mois (detecte dans le dashboard).
///
/// 7 questions pre-remplies avec les valeurs actuelles :
/// 1. Salaire mensuel (slider, pre-rempli)
/// 2. Changement d'emploi ? (oui/non)
/// 3. Avoir LPP actuel (input, aide "regarde ton certificat")
/// 4. Solde 3a approximatif (input, pre-rempli avec estimation)
/// 5. Projet immobilier ? (achat/vente/aucun)
/// 6. Changement familial ? (mariage/naissance/divorce/aucun)
/// 7. Tolerance au risque (conservateur/modere/agressif)
///
/// Apres submit : recalcul score → affiche delta → celebration si amelioration
class AnnualRefreshScreen extends StatefulWidget { /* ... */ }
```

### Detection dans le dashboard

Dans `coach_dashboard_screen.dart`, dans `_loadProfile()` :

```dart
// Detecter si le profil necessite un refresh
if (_profile != null && _profile!.updatedAt != null) {
  final monthsSinceUpdate = DateTime.now()
      .difference(_profile!.updatedAt!)
      .inDays ~/ 30;
  if (monthsSinceUpdate >= 11 && !_hasShownRefreshPrompt) {
    _hasShownRefreshPrompt = true;
    // Afficher banner "Check-up annuel disponible" avec CTA
  }
}
```

---

## TACHE T7 — Scenarios Narres (Forecaster)

### Fichier : `lib/screens/coach/coach_dashboard_screen.dart` (MODIFIER)

### Specification

Dans la section trajectoire du dashboard, sous le graphique `MintTrajectoryChart`, ajouter des narrations par scenario :

```dart
Widget _buildScenarioNarrations() {
  if (_narrative == null || _narrative!.scenarioNarrations == null) {
    return const SizedBox.shrink(); // Pas de narration sans BYOK
  }

  return Column(
    children: [
      for (int i = 0; i < _narrative!.scenarioNarrations!.length; i++)
        _buildScenarioCard(
          index: i,
          label: ['Prudent', 'Base', 'Optimiste'][i],
          color: [MintColors.textMuted, MintColors.coachAccent, MintColors.success][i],
          narration: _narrative!.scenarioNarrations![i],
        ),
    ],
  );
}

Widget _buildScenarioCard({
  required int index,
  required String label,
  required Color color,
  required String narration,
}) {
  return Container(
    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border(left: BorderSide(color: color, width: 3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w700, color: color, fontSize: 13)),
        const SizedBox(height: 8),
        Text(narration, style: GoogleFonts.inter(
          fontSize: 14, color: MintColors.textSecondary, height: 1.5)),
      ],
    ),
  );
}
```

### System Prompt pour scenarios (dans CoachNarrativeService)

```
SCENARIOS DE RETRAITE :
- Prudent ({rendementPrudent}%/an) : capital CHF {capitalPrudent}, rente CHF {rentePrudent}/mois
- Base ({rendementBase}%/an) : capital CHF {capitalBase}, rente CHF {renteBase}/mois
- Optimiste ({rendementOptimiste}%/an) : capital CHF {capitalOptimiste}, rente CHF {renteOptimiste}/mois

Genere 3 paragraphes narratifs (1 par scenario, 2-3 phrases chacun).
Chaque paragraphe doit :
- Traduire le capital en revenu mensuel concret
- Comparer au revenu actuel (taux de remplacement)
- Donner une image de vie ("confortable", "serré", "luxe")
- Le scenario prudent doit mentionner un plan B si necessaire
- Le scenario optimiste doit temperer ("attention, c'est le meilleur cas")
```

---

## INTEGRATION DASHBOARD — Vue d'ensemble

### Ordre d'execution dans `_loadProfile()` du dashboard :

```dart
Future<void> _loadProfile() async {
  // 1. Charger le profil (existant)
  // 2. Calculer le score (existant)
  // 3. Generer les tips (existant)
  // 4. NOUVEAU : Generer le CoachNarrative
  final byok = context.read<ByokProvider>();
  _narrative = await CoachNarrativeService.generate(
    profile: _profile!,
    scoreHistory: _scoreHistory,
    tips: _tips!,
    byokConfig: byok.isConfigured ? LlmConfig(
      apiKey: byok.apiKey!,
      provider: _toLlmProvider(byok.provider!),
    ) : null,
  );
  // 5. NOUVEAU : Detecter milestones (si check-in recent)
  // 6. NOUVEAU : Verifier si refresh annuel necessaire
  // 7. setState
}
```

### Remplacement des textes statiques dans le build :

```dart
// AVANT (statique) :
Text('Bonjour ${_profile!.firstName}')

// APRES (narratif ou fallback) :
Text(_narrative?.greeting ?? 'Bonjour ${_profile!.firstName}')

// AVANT (statique) :
_buildScoreTrendText() // "En progression — continue comme ca"

// APRES :
Text(_narrative?.trendMessage ?? _getStaticTrendText())

// AVANT (statique) :
Text(tip.message)

// APRES :
Text(tip.narrativeMessage ?? tip.message)
```

---

## SEQUENCEMENT & PARALLELISME

```
PHASE 1 (parallele, zero deps) :
├── Agent A : T1 — CoachNarrativeService + tests
├── Agent B : T5 — MilestoneDetectionService + CelebrationSheet + confetti
└── Agent C : T4 — NotificationService + pubspec + lifecycle

PHASE 2 (apres T1) :
├── Agent D : T2 — Tips enrichissement LLM (utilise CoachNarrativeService)
├── Agent E : T3 — Chiffre choc emotionnel (utilise CoachNarrative)
└── Agent F : T6 — Annual refresh screen

PHASE 3 (apres T1 + T5) :
└── Agent G : T7 — Scenarios narres + integration dashboard complete

PHASE 4 (tous) :
└── Audit : flutter analyze + flutter test + zero regression
```

---

## VERIFICATION FINALE

Apres chaque tache :
1. `cd apps/mobile && flutter analyze` → **0 errors**
2. `cd apps/mobile && flutter test` → **0 nouvelle regression**
3. Mode BYOK desactive → app fonctionne exactement comme avant
4. Mode BYOK active → textes narratifs affiches
5. Pas de termes bannis dans aucun texte genere
6. Disclaimer present sur tout contenu LLM
7. Cache 24h fonctionne (pas d'appel LLM a chaque ouverture)
8. Fallback gracieux si le LLM echoue (timeout, erreur API)

---

## CONSTANTES CRITIQUES (RAPPEL)

- Plafond 3a salarie : **7'258 CHF/an**
- Plafond 3a independant : **36'288 CHF/an** (20% du revenu net)
- Seuil LPP : **22'680 CHF/an**
- Taux conversion LPP minimum : **6.8%**
- Emergency fund objectif : **3-6 mois** de charges fixes
- Ratio dettes max : **33%** du revenu brut
- Taux theorique hypothecaire : **5%**

---

## NORTH STAR

> L'utilisateur ouvre l'app le matin. Le dashboard lui dit :
> "Salut Julien, depuis ton check-in de janvier tu as progresse de 4 points.
> Ta discipline 3a paie — 3'629 CHF verses sur 7'258. Mais ton fonds d'urgence
> ne couvre que 7 semaines. Si tu perds ton job demain, ca fait court.
> Mets CHF 500 de cote ce mois et tu passes a 2 mois. On y va ?"
>
> Il sourit. Il se sent compris. Il agit.
> C'est ca, un coach.
