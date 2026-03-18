import 'country_pension_service.dart';

// ────────────────────────────────────────────────────────────
//  MULTI-COUNTRY LIFECYCLE SERVICE — S75+ / Phase 4
// ────────────────────────────────────────────────────────────
//
// Extends lifecycle phases for DACH countries.
// Each country has specific milestones and pension products
// that map to different life phases.
//
// Pure functions — no side effects, deterministic, testable.
// ────────────────────────────────────────────────────────────

/// A lifecycle phase adapted for a specific DACH country.
class DachLifecyclePhase {
  /// Phase name (French).
  final String name;

  /// Age range (approximate).
  final int ageFrom;
  final int ageTo;

  /// Key actions / milestones for this phase in this country.
  final List<String> keyActions;

  /// Country for which this phase applies.
  final DachCountry country;

  /// Relevant pension products to consider.
  final List<String> relevantProducts;

  const DachLifecyclePhase({
    required this.name,
    required this.ageFrom,
    required this.ageTo,
    required this.keyActions,
    required this.country,
    required this.relevantProducts,
  });
}

/// Cross-border combined lifecycle analysis.
class CrossBorderLifecycleAnalysis {
  /// Country of residence.
  final DachCountry residence;

  /// Country of work.
  final DachCountry work;

  /// Lifecycle phases from the work country (pension contributions).
  final List<DachLifecyclePhase> workPhases;

  /// Additional considerations from residence country.
  final List<String> residenceConsiderations;

  /// Combined retirement age considerations.
  final String retirementNote;

  const CrossBorderLifecycleAnalysis({
    required this.residence,
    required this.work,
    required this.workPhases,
    required this.residenceConsiderations,
    required this.retirementNote,
  });
}

/// Multi-country lifecycle service for DACH pension systems.
///
/// Provides country-specific lifecycle phases with appropriate
/// pension products and milestones for each life stage.
class MultiCountryLifecycleService {
  MultiCountryLifecycleService._();

  // ── Swiss lifecycle phases ────────────────────────────────

  static const _swissPhases = [
    DachLifecyclePhase(
      name: 'Démarrage',
      ageFrom: 22,
      ageTo: 28,
      keyActions: [
        'Ouvrir un compte 3a dès le premier emploi',
        'Comprendre les cotisations AVS sur la fiche de paie',
        'Vérifier l\'affiliation LPP auprès de l\'employeur',
      ],
      country: DachCountry.switzerland,
      relevantProducts: ['AVS', 'LPP', '3a'],
    ),
    DachLifecyclePhase(
      name: 'Construction',
      ageFrom: 28,
      ageTo: 35,
      keyActions: [
        'Maximiser le versement 3a chaque année',
        'Évaluer un rachat LPP si lacune détectée',
        'Planifier l\'achat immobilier (EPL possible)',
      ],
      country: DachCountry.switzerland,
      relevantProducts: ['AVS', 'LPP', '3a', 'EPL'],
    ),
    DachLifecyclePhase(
      name: 'Accélération',
      ageFrom: 35,
      ageTo: 45,
      keyActions: [
        'Optimiser les rachats LPP (déduction fiscale)',
        'Diversifier le 3e pilier (3a + 3b)',
        'Analyser le taux de remplacement projeté',
      ],
      country: DachCountry.switzerland,
      relevantProducts: ['AVS', 'LPP', '3a', '3b', 'Rachat LPP'],
    ),
    DachLifecyclePhase(
      name: 'Consolidation',
      ageFrom: 45,
      ageTo: 55,
      keyActions: [
        'Accélérer les rachats LPP (bonification 15-18\u00a0%)',
        'Simuler rente vs capital',
        'Vérifier les années AVS manquantes',
      ],
      country: DachCountry.switzerland,
      relevantProducts: ['AVS', 'LPP', 'Rachat LPP', 'Rente vs Capital'],
    ),
    DachLifecyclePhase(
      name: 'Transition',
      ageFrom: 55,
      ageTo: 65,
      keyActions: [
        'Décider rente, capital ou mixte',
        'Planifier l\'échelonnement des retraits (3a, LPP)',
        'Préparer la transition vers la retraite',
      ],
      country: DachCountry.switzerland,
      relevantProducts: ['AVS', 'LPP', '3a', 'Retrait échelonné'],
    ),
    DachLifecyclePhase(
      name: 'Retraite',
      ageFrom: 65,
      ageTo: 80,
      keyActions: [
        'Gérer le budget de retraite',
        'Surveiller l\'adaptation des rentes',
        'Planifier la succession',
      ],
      country: DachCountry.switzerland,
      relevantProducts: ['Rente AVS', 'Rente LPP', 'Patrimoine libre'],
    ),
  ];

  // ── German lifecycle phases ───────────────────────────────

  static const _germanPhases = [
    DachLifecyclePhase(
      name: 'Démarrage',
      ageFrom: 22,
      ageTo: 28,
      keyActions: [
        'Vérifier les cotisations GRV sur la fiche de paie',
        'Évaluer un contrat Riester dès le premier emploi',
        'Comprendre le système de points de retraite',
      ],
      country: DachCountry.germany,
      relevantProducts: ['GRV', 'Riester'],
    ),
    DachLifecyclePhase(
      name: 'Construction',
      ageFrom: 28,
      ageTo: 35,
      keyActions: [
        'Maximiser les subventions Riester (175\u00a0EUR + enfants)',
        'Explorer la prévoyance d\'entreprise (bAV)',
        'Consulter le relevé de pension annuel (Renteninformation)',
      ],
      country: DachCountry.germany,
      relevantProducts: ['GRV', 'Riester', 'bAV'],
    ),
    DachLifecyclePhase(
      name: 'Accélération',
      ageFrom: 35,
      ageTo: 45,
      keyActions: [
        'Optimiser Riester + bAV pour l\'avantage fiscal',
        'Envisager Rürup si indépendant·e',
        'Analyser les points GRV accumulés vs projection',
      ],
      country: DachCountry.germany,
      relevantProducts: ['GRV', 'Riester', 'Rürup', 'bAV'],
    ),
    DachLifecyclePhase(
      name: 'Consolidation',
      ageFrom: 45,
      ageTo: 55,
      keyActions: [
        'Vérifier les périodes manquantes au relevé GRV',
        'Augmenter les versements Rürup (déductibilité croissante)',
        'Simuler la rente projetée à 67 ans',
      ],
      country: DachCountry.germany,
      relevantProducts: ['GRV', 'Rürup', 'bAV', 'Épargne libre'],
    ),
    DachLifecyclePhase(
      name: 'Transition',
      ageFrom: 55,
      ageTo: 67,
      keyActions: [
        'Demander un relevé détaillé de pension (Rentenauskunft)',
        'Évaluer la retraite anticipée dès 63 ans (avec abattements)',
        'Planifier la transition progressive (Altersteilzeit)',
      ],
      country: DachCountry.germany,
      relevantProducts: ['GRV', 'Rente anticipée', 'Altersteilzeit'],
    ),
    DachLifecyclePhase(
      name: 'Retraite',
      ageFrom: 67,
      ageTo: 80,
      keyActions: [
        'Gérer le budget avec la rente GRV',
        'Déclarer les rentes imposables (Nachgelagerte Besteuerung)',
        'Surveiller les adaptations annuelles de rente',
      ],
      country: DachCountry.germany,
      relevantProducts: ['Rente GRV', 'Riester-Rente', 'Rürup-Rente'],
    ),
  ];

  // ── Austrian lifecycle phases ─────────────────────────────

  static const _austrianPhases = [
    DachLifecyclePhase(
      name: 'Démarrage',
      ageFrom: 22,
      ageTo: 28,
      keyActions: [
        'Vérifier les cotisations PV sur la fiche de paie',
        'Créer un accès au Pensionskonto en ligne',
        'Explorer la Zukunftsvorsorge (épargne-pension avec prime)',
      ],
      country: DachCountry.austria,
      relevantProducts: ['PV', 'Zukunftsvorsorge'],
    ),
    DachLifecyclePhase(
      name: 'Construction',
      ageFrom: 28,
      ageTo: 35,
      keyActions: [
        'Consulter régulièrement le Pensionskonto',
        'Vérifier si l\'employeur propose une Betriebspension',
        'Maximiser la Zukunftsvorsorge pour la prime étatique',
      ],
      country: DachCountry.austria,
      relevantProducts: ['PV', 'Betriebspension', 'Zukunftsvorsorge'],
    ),
    DachLifecyclePhase(
      name: 'Accélération',
      ageFrom: 35,
      ageTo: 45,
      keyActions: [
        'Analyser le Pensionskonto pour les projections',
        'Compléter la prévoyance avec épargne libre',
        'Évaluer la Betriebspension si disponible',
      ],
      country: DachCountry.austria,
      relevantProducts: ['PV', 'Betriebspension', 'Zukunftsvorsorge'],
    ),
    DachLifecyclePhase(
      name: 'Consolidation',
      ageFrom: 45,
      ageTo: 55,
      keyActions: [
        'Vérifier les périodes manquantes sur le Pensionskonto',
        'Simuler la rente projetée à 65 ans',
        'Augmenter l\'épargne complémentaire si nécessaire',
      ],
      country: DachCountry.austria,
      relevantProducts: ['PV', 'Betriebspension', 'Épargne libre'],
    ),
    DachLifecyclePhase(
      name: 'Transition',
      ageFrom: 55,
      ageTo: 65,
      keyActions: [
        'Demander un relevé détaillé du Pensionskonto',
        'Évaluer la Korridorpension (retraite anticipée dès 62 ans)',
        'Planifier la transition emploi → retraite',
      ],
      country: DachCountry.austria,
      relevantProducts: ['PV', 'Korridorpension', 'Betriebspension'],
    ),
    DachLifecyclePhase(
      name: 'Retraite',
      ageFrom: 65,
      ageTo: 80,
      keyActions: [
        'Gérer le budget de retraite',
        'Surveiller les adaptations annuelles de la pension',
        'Planifier la succession',
      ],
      country: DachCountry.austria,
      relevantProducts: ['Pension PV', 'Betriebspension', 'Patrimoine libre'],
    ),
  ];

  // ── Public API ────────────────────────────────────────────

  /// Get lifecycle phases for a specific DACH country.
  static List<DachLifecyclePhase> getPhasesForCountry(DachCountry country) {
    switch (country) {
      case DachCountry.switzerland:
        return _swissPhases;
      case DachCountry.germany:
        return _germanPhases;
      case DachCountry.austria:
        return _austrianPhases;
    }
  }

  /// Get the lifecycle phase for a given age in a specific country.
  static DachLifecyclePhase? getPhaseForAge(DachCountry country, int age) {
    final phases = getPhasesForCountry(country);
    for (final phase in phases) {
      if (age >= phase.ageFrom && age < phase.ageTo) {
        return phase;
      }
    }
    // Age beyond last phase — return last phase
    if (age >= phases.last.ageTo) return phases.last;
    return null;
  }

  /// Analyze a cross-border lifecycle scenario.
  ///
  /// Returns work-country phases with residence-country considerations.
  static CrossBorderLifecycleAnalysis analyzeCrossBorder({
    required DachCountry residence,
    required DachCountry work,
  }) {
    final workPhases = getPhasesForCountry(work);
    final residenceConsiderations = <String>[];

    final workSystem = CountryPensionService.getSystem(work);
    final residenceSystem = CountryPensionService.getSystem(residence);

    // Residence-specific considerations
    if (residence == DachCountry.switzerland) {
      residenceConsiderations.add(
        'En tant que résident·e suisse, le pilier 3a pourrait rester accessible '
        'en complément des cotisations dans le pays de travail.',
      );
    } else if (residence == DachCountry.germany) {
      residenceConsiderations.add(
        'En tant que résident·e allemand·e, les produits Riester pourraient '
        'être accessibles sous certaines conditions.',
      );
    } else if (residence == DachCountry.austria) {
      residenceConsiderations.add(
        'En tant que résident·e autrichien·ne, le Pensionskonto reste '
        'consultable en ligne pour suivre les droits acquis.',
      );
    }

    String retirementNote;
    if (workSystem.retirementAge == residenceSystem.retirementAge) {
      retirementNote =
          'L\'âge de la retraite est identique dans les deux pays '
          '(${workSystem.retirementAge} ans).';
    } else {
      retirementNote =
          'L\'âge de la retraite diffère\u00a0: '
          '${workSystem.retirementAge} ans (pays de travail) vs '
          '${residenceSystem.retirementAge} ans (pays de résidence). '
          'La coordination des prestations pourrait nécessiter une planification spécifique.';
    }

    return CrossBorderLifecycleAnalysis(
      residence: residence,
      work: work,
      workPhases: workPhases,
      residenceConsiderations: residenceConsiderations,
      retirementNote: retirementNote,
    );
  }
}
