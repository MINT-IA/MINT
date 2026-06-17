/// Intent choisi par l'user au tour 2 de l'onboarding MVP wedge.
///
/// Diagnostic onboarding v1 — 4 intents visibles par événement de vie :
/// logement → impôts → prévoyance → situation. L'ordre évite de présenter
/// MINT comme une app retraite-first tout en gardant les valeurs enum stables
/// pour le flush et les tests existants.
///
/// Ref doctrine : `.planning/mvp-wedge-onboarding-2026-04-21/STORYBOARD-FINAL-LOCKED.md`
enum OnboardingIntent {
  retraite,
  achat,
  impots,
  explorer,
}

const int onbAxisSchemaVersion = 2;

enum OnboardingAxisV2 {
  lppRenteCapital,
  logementSignal,
  fiscalSignal,
  legacyExploreNeedsChoice,
}

extension OnboardingAxisV2Id on OnboardingAxisV2 {
  String get id => switch (this) {
        OnboardingAxisV2.lppRenteCapital => 'lpp_rente_capital',
        OnboardingAxisV2.logementSignal => 'logement_signal',
        OnboardingAxisV2.fiscalSignal => 'fiscal_signal',
        OnboardingAxisV2.legacyExploreNeedsChoice =>
          'legacy_explore_needs_choice',
      };

  OnboardingIntent? get legacyIntent => switch (this) {
        OnboardingAxisV2.lppRenteCapital => OnboardingIntent.retraite,
        OnboardingAxisV2.logementSignal => OnboardingIntent.achat,
        OnboardingAxisV2.fiscalSignal => OnboardingIntent.impots,
        OnboardingAxisV2.legacyExploreNeedsChoice => OnboardingIntent.explorer,
      };
}

OnboardingAxisV2 onboardingAxisV2FromLegacyIntent(
  OnboardingIntent intent,
) =>
    switch (intent) {
      OnboardingIntent.retraite => OnboardingAxisV2.lppRenteCapital,
      OnboardingIntent.achat => OnboardingAxisV2.logementSignal,
      OnboardingIntent.impots => OnboardingAxisV2.fiscalSignal,
      OnboardingIntent.explorer => OnboardingAxisV2.legacyExploreNeedsChoice,
    };
