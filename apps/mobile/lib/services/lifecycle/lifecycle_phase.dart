/// The 7 lifecycle phases for Swiss financial planning.
///
/// Based on the Noom 7-phase model adapted for Swiss finance.
/// See docs/ROADMAP_V2.md S57.
///
/// Age bands are indicative — actual phase detection in [LifecycleDetector]
/// uses age as primary signal with life event and employment modifiers.
library;

/// The 7 lifecycle phases covering the full adult financial life.
enum LifecyclePhase {
  /// Phase 1 (typical 18-25): First job, budget basics, 3a introduction.
  /// Tone: encouraging, simple.
  demarrage,

  /// Phase 2 (typical 25-35): Career growth, savings, first property, family.
  /// Tone: motivating, concrete.
  construction,

  /// Phase 3 (typical 35-45): Peak earning, LPP optimization, tax optimization.
  /// Tone: strategic, detailed.
  acceleration,

  /// Phase 4 (typical 45-55): Retirement planning, LPP buyback, succession prep.
  /// Tone: reassuring, precise.
  consolidation,

  /// Phase 5 (typical 55-60): Pre-retirement decisions, rente vs capital.
  /// Tone: calm, structured.
  transition,

  /// Phase 6 (typical 60-65+): Retirement execution, budget adaptation.
  /// Tone: serene, supportive.
  retraite,

  /// Phase 7 (typical 65+): Estate planning, donation, succession.
  /// Tone: wise, respectful.
  transmission,
}
