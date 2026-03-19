import 'germany_pension.dart';
import 'austria_pension.dart';
import 'multi_country_lifecycle_service.dart';

// ────────────────────────────────────────────────────────────
//  COUNTRY PENSION SERVICE — S75+ / Phase 4 "La Référence"
// ────────────────────────────────────────────────────────────
//
// Educational comparison of DACH pension systems (CH, DE, AT).
// Read-only, no advice. Side-by-side comparison only.
//
// Pure functions — no side effects, deterministic, testable.
// ────────────────────────────────────────────────────────────

/// DACH countries supported by the pension comparison engine.
enum DachCountry { switzerland, germany, austria }

/// A pension pillar within a country's system.
class PensionPillar {
  /// Pillar number (1, 2, or 3).
  final int number;

  /// Short name (e.g. "AVS", "GRV", "PV").
  final String name;

  /// Country-specific local name.
  final String localName;

  /// Educational description (French).
  final String description;

  /// Annual max contribution if applicable (in local currency).
  final double? maxContribution;

  /// Legal reference (e.g. "LAVS", "SGB VI", "ASVG").
  final String? legalReference;

  const PensionPillar({
    required this.number,
    required this.name,
    required this.localName,
    required this.description,
    this.maxContribution,
    this.legalReference,
  });
}

/// A country's full pension system description.
class CountryPensionSystem {
  /// Which DACH country.
  final DachCountry country;

  /// Display name (French).
  final String name;

  /// List of pension pillars.
  final List<PensionPillar> pillars;

  /// Standard retirement age.
  final int retirementAge;

  /// Early retirement age (if applicable).
  final int? earlyRetirementAge;

  /// Currency code ("CHF" or "EUR").
  final String currencyCode;

  /// Tax system identifier.
  final String taxSystem;

  /// Disclaimer (educational, non-advisory).
  final String disclaimer;

  const CountryPensionSystem({
    required this.country,
    required this.name,
    required this.pillars,
    required this.retirementAge,
    this.earlyRetirementAge,
    required this.currencyCode,
    required this.taxSystem,
    required this.disclaimer,
  });
}

/// Side-by-side pension system comparison (educational).
class PensionComparison {
  /// Source country system.
  final CountryPensionSystem from;

  /// Target country system.
  final CountryPensionSystem to;

  /// Key differences (educational bullet points).
  final List<PensionDifference> differences;

  /// Educational disclaimer.
  final String disclaimer;

  /// Legal sources referenced.
  final List<String> sources;

  const PensionComparison({
    required this.from,
    required this.to,
    required this.differences,
    required this.disclaimer,
    required this.sources,
  });
}

/// A single difference between two pension systems.
class PensionDifference {
  /// Category of difference.
  final String category;

  /// Description of difference (French).
  final String description;

  /// Value in source country (if applicable).
  final String? fromValue;

  /// Value in target country (if applicable).
  final String? toValue;

  const PensionDifference({
    required this.category,
    required this.description,
    this.fromValue,
    this.toValue,
  });
}

/// Cross-border work/residence analysis.
class CrossBorderAnalysis {
  /// Country of residence.
  final DachCountry residence;

  /// Country of work.
  final DachCountry work;

  /// Age of the person.
  final int age;

  /// Applicable pension system(s).
  final List<String> applicableSystems;

  /// Tax considerations (educational).
  final List<String> taxConsiderations;

  /// Key warnings.
  final List<String> alertes;

  /// Educational disclaimer.
  final String disclaimer;

  /// Legal sources.
  final List<String> sources;

  const CrossBorderAnalysis({
    required this.residence,
    required this.work,
    required this.age,
    required this.applicableSystems,
    required this.taxConsiderations,
    required this.alertes,
    required this.disclaimer,
    required this.sources,
  });
}

/// Educational pension system comparison service for DACH countries.
///
/// Read-only, no advice. All comparisons are side-by-side, never ranked.
/// All text in French (app is French-first).
///
/// Disclaimer: outil éducatif, ne constitue pas un conseil financier.
class CountryPensionService {
  CountryPensionService._();

  // ── Swiss pension system ──────────────────────────────────

  static const _swissPillars = [
    PensionPillar(
      number: 1,
      name: 'AVS',
      localName: 'Assurance-vieillesse et survivants',
      description:
          'Premier pilier\u00a0: rente étatique couvrant les besoins vitaux. '
          'Financé par les cotisations salariales et patronales.',
      legalReference: 'LAVS art. 21-40',
    ),
    PensionPillar(
      number: 2,
      name: 'LPP',
      localName: 'Prévoyance professionnelle',
      description:
          'Deuxième pilier\u00a0: épargne professionnelle obligatoire. '
          'Capital accumulé converti en rente ou retiré.',
      legalReference: 'LPP art. 7-16',
    ),
    PensionPillar(
      number: 3,
      name: '3a',
      localName: 'Prévoyance individuelle liée',
      description:
          'Troisième pilier\u00a0: épargne volontaire avec avantage fiscal. '
          'Maximum 7\u00a0258\u00a0CHF/an (salarié avec LPP).',
      maxContribution: 7258,
      legalReference: 'OPP3',
    ),
  ];

  static const _swissSystem = CountryPensionSystem(
    country: DachCountry.switzerland,
    name: 'Système de prévoyance suisse',
    pillars: _swissPillars,
    retirementAge: 65,
    earlyRetirementAge: 63,
    currencyCode: 'CHF',
    taxSystem: 'LIFD',
    disclaimer:
        'Outil éducatif\u00a0: ne constitue pas un conseil en prévoyance. '
        'Consultez un·e spécialiste pour votre situation personnelle.',
  );

  // ── Get pension system ────────────────────────────────────

  /// Returns the pension system description for a given DACH country.
  static CountryPensionSystem getSystem(DachCountry country) {
    switch (country) {
      case DachCountry.switzerland:
        return _swissSystem;
      case DachCountry.germany:
        return GermanyPension.system;
      case DachCountry.austria:
        return AustriaPension.system;
    }
  }

  // ── Compare two systems ───────────────────────────────────

  /// Educational side-by-side comparison of two pension systems.
  ///
  /// Never ranked — differences shown neutrally.
  static PensionComparison compare(DachCountry from, DachCountry to) {
    final fromSystem = getSystem(from);
    final toSystem = getSystem(to);

    final differences = <PensionDifference>[];

    // Retirement age
    differences.add(PensionDifference(
      category: 'Âge de la retraite',
      description:
          'L\'âge légal de la retraite diffère entre les deux pays.',
      fromValue: '${fromSystem.retirementAge} ans',
      toValue: '${toSystem.retirementAge} ans',
    ));

    // Currency
    if (fromSystem.currencyCode != toSystem.currencyCode) {
      differences.add(PensionDifference(
        category: 'Devise',
        description:
            'Les systèmes utilisent des devises différentes.',
        fromValue: fromSystem.currencyCode,
        toValue: toSystem.currencyCode,
      ));
    }

    // Number of pillars
    differences.add(PensionDifference(
      category: 'Structure des piliers',
      description:
          'Les deux pays utilisent un système à piliers, '
          'mais avec des noms et structures différents.',
      fromValue: fromSystem.pillars.map((p) => p.name).join(', '),
      toValue: toSystem.pillars.map((p) => p.name).join(', '),
    ));

    // Tax system
    differences.add(PensionDifference(
      category: 'Système fiscal',
      description:
          'Les règles fiscales appliquées aux retraits et rentes diffèrent.',
      fromValue: fromSystem.taxSystem,
      toValue: toSystem.taxSystem,
    ));

    // Country-specific differences
    if ((from == DachCountry.switzerland && to == DachCountry.germany) ||
        (from == DachCountry.germany && to == DachCountry.switzerland)) {
      differences.add(const PensionDifference(
        category: 'Prévoyance individuelle',
        description:
            'L\'Allemagne propose deux produits distincts pour le 3e pilier\u00a0: '
            'Riester (subventionné) et Rürup (déductible). '
            'La Suisse a un seul pilier 3a avec plafond annuel.',
      ));
    }

    if ((from == DachCountry.switzerland && to == DachCountry.austria) ||
        (from == DachCountry.austria && to == DachCountry.switzerland)) {
      differences.add(const PensionDifference(
        category: 'Compte pension en ligne',
        description:
            'L\'Autriche offre un Pensionskonto en ligne permettant de '
            'consulter ses droits acquis. La Suisse n\'a pas d\'équivalent '
            'centralisé.',
      ));
    }

    return PensionComparison(
      from: fromSystem,
      to: toSystem,
      differences: differences,
      disclaimer:
          'Comparaison éducative uniquement. Chaque situation est unique\u00a0; '
          'consultez un·e spécialiste pour un conseil personnalisé.',
      sources: [
        if (from == DachCountry.switzerland || to == DachCountry.switzerland)
          'LAVS, LPP, OPP3 (droit suisse)',
        if (from == DachCountry.germany || to == DachCountry.germany)
          'SGB VI, EStG, AltZertG (droit allemand)',
        if (from == DachCountry.austria || to == DachCountry.austria)
          'ASVG, EStG-AT, PKG (droit autrichien)',
      ],
    );
  }

  // ── Lifecycle phases per country ──────────────────────────

  /// Returns country-specific lifecycle phases.
  static List<DachLifecyclePhase> getLifecyclePhases(DachCountry country) {
    return MultiCountryLifecycleService.getPhasesForCountry(country);
  }

  // ── Cross-border analysis ─────────────────────────────────

  /// Analyze a cross-border work/residence scenario (educational).
  ///
  /// Never provides advice — only highlights considerations.
  static CrossBorderAnalysis analyzeCrossBorder({
    required DachCountry residence,
    required DachCountry work,
    required int age,
  }) {
    final applicableSystems = <String>[];
    final taxConsiderations = <String>[];
    final alertes = <String>[];
    final sources = <String>[];

    // Same country = no cross-border
    if (residence == work) {
      final system = getSystem(residence);
      applicableSystems.add(system.name);
      return CrossBorderAnalysis(
        residence: residence,
        work: work,
        age: age,
        applicableSystems: applicableSystems,
        taxConsiderations: [
          'Pas de situation transfrontalière\u00a0: un seul système s\'applique.',
        ],
        alertes: [],
        disclaimer:
            'Outil éducatif\u00a0: ne constitue pas un conseil. '
            'Consultez un·e spécialiste.',
        sources: [_legalSourceFor(residence)],
      );
    }

    // Cross-border: social security follows place of work (EU regulation)
    final workSystem = getSystem(work);
    final residenceSystem = getSystem(residence);

    applicableSystems.add(
      '${workSystem.name} (cotisations sociales — lieu de travail)',
    );
    applicableSystems.add(
      '${residenceSystem.name} (éventuelles obligations fiscales — lieu de résidence)',
    );

    // Tax considerations
    taxConsiderations.add(
      'Les cotisations sociales sont généralement dues dans le pays de travail '
      '(règlement CE 883/2004, applicable à la Suisse via l\'ALCP).',
    );

    if (residence == DachCountry.switzerland && work == DachCountry.germany) {
      taxConsiderations.add(
        'Frontalier·ère CH→DE\u00a0: imposition possible dans les deux pays '
        'avec mécanisme d\'élimination de la double imposition '
        '(convention bilatérale CH-DE).',
      );
      sources.add('Convention de double imposition CH-DE');
    } else if (residence == DachCountry.germany &&
        work == DachCountry.switzerland) {
      taxConsiderations.add(
        'Frontalier·ère DE→CH\u00a0: impôt à la source en Suisse, '
        'crédit d\'impôt possible en Allemagne '
        '(convention bilatérale CH-DE art. 15a).',
      );
      sources.add('Convention de double imposition CH-DE art. 15a');
    } else if (residence == DachCountry.switzerland &&
        work == DachCountry.austria) {
      taxConsiderations.add(
        'Frontalier·ère CH→AT\u00a0: les conventions bilatérales CH-AT '
        'déterminent le droit d\'imposition.',
      );
      sources.add('Convention de double imposition CH-AT');
    } else if (residence == DachCountry.austria &&
        work == DachCountry.switzerland) {
      taxConsiderations.add(
        'Frontalier·ère AT→CH\u00a0: impôt à la source en Suisse, '
        'mécanisme de crédit d\'impôt en Autriche.',
      );
      sources.add('Convention de double imposition CH-AT');
    } else {
      // DE-AT cross-border (EU internal)
      taxConsiderations.add(
        'Frontalier·ère DE↔AT\u00a0: coordination via le règlement CE 883/2004 '
        'et la convention bilatérale DE-AT.',
      );
      sources.add('Règlement CE 883/2004, Convention DE-AT');
    }

    // Age-specific alerts
    final workRetirementAge = workSystem.retirementAge;
    final residenceRetirementAge = residenceSystem.retirementAge;
    if (workRetirementAge != residenceRetirementAge) {
      alertes.add(
        'Attention\u00a0: l\'âge de la retraite diffère entre les deux pays '
        '($workRetirementAge ans vs $residenceRetirementAge ans). '
        'Cela pourrait affecter la coordination des prestations.',
      );
    }

    sources.add('Règlement CE 883/2004');
    sources.add(_legalSourceFor(work));
    sources.add(_legalSourceFor(residence));

    return CrossBorderAnalysis(
      residence: residence,
      work: work,
      age: age,
      applicableSystems: applicableSystems,
      taxConsiderations: taxConsiderations,
      alertes: alertes,
      disclaimer:
          'Outil éducatif\u00a0: ne constitue pas un conseil. '
          'La situation transfrontalière est complexe\u00a0; '
          'consultez un·e spécialiste en droit international.',
      sources: sources,
    );
  }

  /// Legal source label for a country.
  static String _legalSourceFor(DachCountry country) {
    switch (country) {
      case DachCountry.switzerland:
        return 'LAVS, LPP, OPP3';
      case DachCountry.germany:
        return 'SGB VI, EStG, AltZertG';
      case DachCountry.austria:
        return 'ASVG, EStG-AT, PKG';
    }
  }
}
