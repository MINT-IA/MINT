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
