/// Advisor Specialization — Sprint S65 (Expert Tier).
///
/// Single source of truth for the [AdvisorSpecialization] enum used across
/// the Expert Tier services: DossierPreparationService, SessionSchedulerService,
/// and any future advisor-matching UI.
///
/// COMPLIANCE (NON-NEGOTIABLE):
/// - Term "conseiller" is BANNED — always "spécialiste".
/// - No ranking: specializations are presented side-by-side, never ordered by quality.
/// - No-Advice: MINT prepares the user; the specialist gives the advice.
///
/// Outil éducatif — ne constitue pas un conseil financier (LSFin art. 3).
library;

/// The 8 specialization areas available for human-specialist consultations.
///
/// Each value maps to a distinct set of dossier sections, suggested questions,
/// and ARB label keys (prefix `expertSpec`).
enum AdvisorSpecialization {
  /// Retraite, décaissement, rente vs capital, anticipation.
  retirement,

  /// Succession, donation, testament, pacte successoral.
  succession,

  /// Expatriation, frontalier, FATCA, conventions bilatérales, AVS à l'étranger.
  expatriation,

  /// Divorce, partage LPP, pension alimentaire, régime matrimonial.
  divorce,

  /// Indépendants, SARL/SA, LPP volontaire, statut AHV.
  selfEmployment,

  /// Immobilier, hypothèque, EPL (Early Pension Withdrawal), financement.
  realEstate,

  /// Fiscalité, déductions, rachat LPP, optimisation 3a.
  taxOptimization,

  /// Surendettement, assainissement, plan de désendettement.
  debtManagement,
}
