import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/lifecycle_phase_service.dart';

// ────────────────────────────────────────────────────────────
//  CONTENT ADAPTER SERVICE — S57 / Phase 2 "Le Compagnon"
// ────────────────────────────────────────────────────────────
//
// Adapts content (tone, vocabulary, priority, framing) based
// on the detected lifecycle phase + financial literacy level.
//
// Used by:
//   - Coach AI (system prompt injection)
//   - Educational inserts (complexity filter)
//   - Dashboard curator (priority ordering)
//   - Notification service (tone + timing)
//
// Pure functions — no side effects, deterministic, testable.
// ────────────────────────────────────────────────────────────

/// Adapted content configuration for a given user.
class ContentAdaptation {
  /// Communication tone descriptor for LLM system prompt.
  final String toneDirective;

  /// Max Flesch-Kincaid grade level for generated text.
  final int maxReadingLevel;

  /// Whether to show advanced projections (Monte Carlo, tornado).
  final bool showAdvancedProjections;

  /// Whether to show tax optimization details.
  final bool showTaxOptimization;

  /// Whether to show LPP buyback scenarios.
  final bool showLppBuyback;

  /// Whether to show withdrawal sequencing.
  final bool showWithdrawalSequencing;

  /// Whether to show estate planning.
  final bool showEstatePlanning;

  /// Vocabulary level: 'simple', 'standard', 'expert'.
  final String vocabularyLevel;

  /// Coach greeting style key (for i18n).
  final String greetingKey;

  /// Phase-specific focus areas for dashboard ordering.
  final List<String> dashboardFocusOrder;

  /// System prompt addition for coach AI.
  final String coachSystemPromptAddition;

  const ContentAdaptation({
    required this.toneDirective,
    required this.maxReadingLevel,
    required this.showAdvancedProjections,
    required this.showTaxOptimization,
    required this.showLppBuyback,
    required this.showWithdrawalSequencing,
    required this.showEstatePlanning,
    required this.vocabularyLevel,
    required this.greetingKey,
    required this.dashboardFocusOrder,
    required this.coachSystemPromptAddition,
  });
}

/// Adapts all content based on lifecycle phase + profile.
///
/// Pure function — deterministic, no side effects.
class ContentAdapterService {
  ContentAdapterService._();

  /// Build a complete content adaptation from the phase result.
  static ContentAdaptation adapt(
    LifecyclePhaseResult phaseResult,
    CoachProfile profile,
  ) {
    final tone = _buildToneDirective(phaseResult);
    final readingLevel = _maxReadingLevel(phaseResult);
    final features = _featureVisibility(phaseResult);
    final vocab = _vocabularyLevel(phaseResult);
    final greeting = _greetingKey(phaseResult);
    final dashboardOrder = _dashboardFocusOrder(phaseResult);
    final coachAddition = _coachSystemPrompt(phaseResult, profile);

    return ContentAdaptation(
      toneDirective: tone,
      maxReadingLevel: readingLevel,
      showAdvancedProjections: features['advancedProjections']!,
      showTaxOptimization: features['taxOptimization']!,
      showLppBuyback: features['lppBuyback']!,
      showWithdrawalSequencing: features['withdrawalSequencing']!,
      showEstatePlanning: features['estatePlanning']!,
      vocabularyLevel: vocab,
      greetingKey: greeting,
      dashboardFocusOrder: dashboardOrder,
      coachSystemPromptAddition: coachAddition,
    );
  }

  /// Tone directive for LLM system prompt.
  static String _buildToneDirective(LifecyclePhaseResult result) {
    switch (result.tone) {
      case LifecycleTone.encouraging:
        return 'Ton encourageant et motivant. Utilise des phrases positives. '
            'Célèbre chaque petit progrès. Évite le jargon technique — '
            'explique chaque terme avec des analogies du quotidien.';
      case LifecycleTone.empowering:
        return 'Ton confiant et orienté action. L\'utilisateur est dans sa '
            'phase d\'optimisation — propose des stratégies concrètes. '
            'Utilise le vocabulaire financier standard avec explications brèves.';
      case LifecycleTone.reassuring:
        return 'Ton calme et méthodique. L\'utilisateur prépare une transition '
            'importante — sois rassurant sans minimiser. Présente les scénarios '
            'de façon ordonnée (bas/moyen/haut). Insiste sur ce qui est sous contrôle.';
      case LifecycleTone.simple:
        return 'Ton clair et direct. Phrases courtes. Pas de jargon. '
            'Un concept par paragraphe. Utilise des montants mensuels '
            'plutôt qu\'annuels. Propose des actions immédiates et concrètes.';
    }
  }

  /// Max reading level (Flesch-Kincaid grade) per phase.
  static int _maxReadingLevel(LifecyclePhaseResult result) {
    switch (result.complexity) {
      case LifecycleComplexity.basic:
        return 6;  // 6th grade — simple, accessible
      case LifecycleComplexity.intermediate:
        return 10; // 10th grade — standard financial literacy
      case LifecycleComplexity.advanced:
        return 14; // College level — full technical depth
    }
  }

  /// Which advanced features to show per phase.
  static Map<String, bool> _featureVisibility(LifecyclePhaseResult result) {
    switch (result.phase) {
      case LifecyclePhase.demarrage:
        return {
          'advancedProjections': false,
          'taxOptimization': false,
          'lppBuyback': false,
          'withdrawalSequencing': false,
          'estatePlanning': false,
        };
      case LifecyclePhase.construction:
        return {
          'advancedProjections': false,
          'taxOptimization': true,
          'lppBuyback': false,
          'withdrawalSequencing': false,
          'estatePlanning': false,
        };
      case LifecyclePhase.acceleration:
        return {
          'advancedProjections': true,
          'taxOptimization': true,
          'lppBuyback': true,
          'withdrawalSequencing': false,
          'estatePlanning': false,
        };
      case LifecyclePhase.consolidation:
        return {
          'advancedProjections': true,
          'taxOptimization': true,
          'lppBuyback': true,
          'withdrawalSequencing': true,
          'estatePlanning': true,
        };
      case LifecyclePhase.transition:
        return {
          'advancedProjections': true,
          'taxOptimization': true,
          'lppBuyback': true,
          'withdrawalSequencing': true,
          'estatePlanning': true,
        };
      case LifecyclePhase.retraite:
        return {
          'advancedProjections': true,
          'taxOptimization': true,
          'lppBuyback': false,
          'withdrawalSequencing': true,
          'estatePlanning': true,
        };
      case LifecyclePhase.transmission:
        return {
          'advancedProjections': false,
          'taxOptimization': false,
          'lppBuyback': false,
          'withdrawalSequencing': false,
          'estatePlanning': true,
        };
    }
  }

  /// Vocabulary complexity level.
  static String _vocabularyLevel(LifecyclePhaseResult result) {
    switch (result.complexity) {
      case LifecycleComplexity.basic:
        return 'simple';
      case LifecycleComplexity.intermediate:
        return 'standard';
      case LifecycleComplexity.advanced:
        return 'expert';
    }
  }

  /// Greeting key for i18n (phase-specific welcome).
  static String _greetingKey(LifecyclePhaseResult result) {
    return 'lifecycleGreeting${result.phase.name[0].toUpperCase()}${result.phase.name.substring(1)}';
  }

  /// Dashboard section ordering per phase.
  ///
  /// Earlier items = higher on dashboard = user sees first.
  static List<String> _dashboardFocusOrder(LifecyclePhaseResult result) {
    switch (result.phase) {
      case LifecyclePhase.demarrage:
        return ['budget', '3a', 'education', 'goals', 'insurance'];
      case LifecyclePhase.construction:
        return ['3a', 'housing', 'patrimoine', 'budget', 'insurance'];
      case LifecyclePhase.acceleration:
        return ['lpp', 'tax', 'patrimoine', '3a', 'retirement'];
      case LifecyclePhase.consolidation:
        return ['retirement', 'lpp', 'rente_vs_capital', 'tax', 'patrimoine'];
      case LifecyclePhase.transition:
        return ['retirement', 'withdrawal', 'rente_vs_capital', 'budget', 'estate'];
      case LifecyclePhase.retraite:
        return ['budget', 'withdrawal', 'lamal', 'estate', 'patrimoine'];
      case LifecyclePhase.transmission:
        return ['estate', 'donation', 'simplify', 'budget', 'lamal'];
    }
  }

  /// Coach system prompt addition — injected into LLM context.
  ///
  /// This tells the AI coach how to behave for this user's phase.
  static String _coachSystemPrompt(
    LifecyclePhaseResult result,
    CoachProfile profile,
  ) {
    final age = result.age;
    final phase = result.phase.name;
    final years = result.yearsToRetirement;
    final priorityKeys = result.priorities.take(3).map((p) => p.key).join(', ');

    return 'CONTEXTE CYCLE DE VIE\u00a0: '
        'L\'utilisateur a $age ans, en phase "$phase" '
        '($years ans avant la retraite). '
        'Priorités principales\u00a0: $priorityKeys. '
        '${_buildToneDirective(result)} '
        'IMPORTANT\u00a0: Ne jamais mentionner le nom de la phase directement. '
        'Adapter le contenu naturellement sans étiqueter.';
  }
}
