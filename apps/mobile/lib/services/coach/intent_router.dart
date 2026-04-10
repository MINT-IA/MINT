/// Intent Router — maps onboarding chip ARB keys to goal metadata.
///
/// Source: Phase 03 CONTEXT.md decisions D-01 and D-02.
///
/// Used by IntentScreen._onChipTap() to:
///   - Write goalIntentTag to CapMemoryStore.declaredGoals
///   - Select stressType for PremierEclairageSelector.select()
///   - Navigate to suggestedRoute on MintHomeScreen CTA
///
/// IMPORTANT: Keys are ARB identifiers (e.g. 'intentChip3a'), NOT resolved
/// localized strings. Never pass chip.label — always pass the ARB key constant.
library;

/// Immutable mapping from a chip key to its goal intent metadata.
class IntentMapping {
  final String goalIntentTag;
  final String stressType;
  final String suggestedRoute;
  final String lifeEventFamily;

  const IntentMapping({
    required this.goalIntentTag,
    required this.stressType,
    required this.suggestedRoute,
    required this.lifeEventFamily,
  });
}

/// Static routing table from 9 onboarding chip ARB keys to intent metadata.
///
/// Never instantiate — use static accessors only.
class IntentRouter {
  IntentRouter._();

  static const Map<String, IntentMapping> _map = {
    'intentChip3a': IntentMapping(
      goalIntentTag: 'budget_overview',
      stressType: 'stress_budget',
      suggestedRoute: '/pilier-3a',
      lifeEventFamily: 'professionnel',
    ),
    'intentChipBilan': IntentMapping(
      goalIntentTag: 'retirement_choice',
      stressType: 'stress_retraite',
      suggestedRoute: '/retraite',
      lifeEventFamily: 'professionnel',
    ),
    'intentChipPrevoyance': IntentMapping(
      goalIntentTag: 'retirement_choice',
      stressType: 'stress_retraite',
      suggestedRoute: '/retraite',
      lifeEventFamily: 'professionnel',
    ),
    'intentChipFiscalite': IntentMapping(
      goalIntentTag: 'budget_overview',
      stressType: 'stress_impots',
      suggestedRoute: '/fiscal',
      lifeEventFamily: 'patrimoine',
    ),
    'intentChipProjet': IntentMapping(
      goalIntentTag: 'housing_purchase',
      stressType: 'stress_patrimoine',
      suggestedRoute: '/hypotheque',
      lifeEventFamily: 'patrimoine',
    ),
    'intentChipChangement': IntentMapping(
      goalIntentTag: 'budget_overview',
      stressType: 'stress_budget',
      suggestedRoute: '/coach/chat',
      lifeEventFamily: 'professionnel',
    ),
    'intentChipPremierEmploi': IntentMapping(
      goalIntentTag: 'first_job',
      stressType: 'stress_prevoyance',
      suggestedRoute: '/first-job',
      lifeEventFamily: 'professionnel',
    ),
    'intentChipNouvelEmploi': IntentMapping(
      goalIntentTag: 'new_job',
      stressType: 'stress_budget',
      suggestedRoute: '/rente-vs-capital',
      lifeEventFamily: 'professionnel',
    ),
    'intentChipAutre': IntentMapping(
      goalIntentTag: 'retirement_choice',
      stressType: 'stress_retraite',
      suggestedRoute: '/retraite',
      lifeEventFamily: 'professionnel',
    ),
  };

  /// Returns the [IntentMapping] for [chipKey], or null if not found.
  ///
  /// [chipKey] must be the ARB key identifier (e.g. 'intentChip3a'),
  /// not the resolved localized label.
  static IntentMapping? forChipKey(String chipKey) => _map[chipKey];

  /// Returns all registered chip key identifiers (exactly 9).
  static List<String> get allChipKeys => _map.keys.toList();
}
