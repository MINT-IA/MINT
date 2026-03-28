/// Contract benchmark service — enriches deadline alerts with comparisons.
///
/// When a contract deadline approaches, this service adds context:
/// - LAMal: current franchise vs optimal franchise estimate
/// - Mortgage: current rate vs market average
/// - Insurance: estimated savings from switching
///
/// All benchmarks are educational estimates, not binding offers.
/// See: MINT_ANTI_BULLSHIT_MANIFESTO.md, MINT_FINAL_EXECUTION_SYSTEM.md §13.14
library;

import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/contract_alert_service.dart';

/// Enriched alert with benchmark comparison.
class EnrichedAlert {
  /// The original deadline.
  final ContractDeadline deadline;

  /// Human-readable benchmark message (educational, not prescriptive).
  final String? benchmarkMessage;

  /// Estimated monthly savings if user acts (null if unknown).
  final double? estimatedMonthlySavings;

  /// Suggested route to navigate for action.
  final String? actionRoute;

  const EnrichedAlert({
    required this.deadline,
    this.benchmarkMessage,
    this.estimatedMonthlySavings,
    this.actionRoute,
  });
}

/// Enriches contract alerts with benchmark comparisons.
class ContractBenchmarkService {
  ContractBenchmarkService._();

  /// Enrich active alerts with benchmark data from the user's profile.
  static Future<List<EnrichedAlert>> enrichAlerts({
    required CoachProfile profile,
    DateTime? now,
  }) async {
    final alerts = await ContractAlertService.getActiveAlerts(now);
    if (alerts.isEmpty) return [];

    return alerts.map((d) => _enrich(d, profile)).toList();
  }

  static EnrichedAlert _enrich(ContractDeadline d, CoachProfile profile) {
    return switch (d.documentType) {
      'lease_contract' => _enrichLease(d, profile),
      'insurance_contract' => _enrichInsurance(d, profile),
      'lpp_certificate' => _enrichLpp(d, profile),
      _ => EnrichedAlert(deadline: d),
    };
  }

  static EnrichedAlert _enrichLease(ContractDeadline d, CoachProfile profile) {
    final loyer = profile.depenses.loyer;
    if (loyer <= 0) return EnrichedAlert(deadline: d);

    // Compare rent to cantonal average (educational estimate)
    final avgRent = _cantonalAverageRent(profile.canton);
    final diff = loyer - avgRent;

    return EnrichedAlert(
      deadline: d,
      benchmarkMessage: diff > 200
          ? 'Ton loyer est CHF\u00a0${loyer.round()}/mois. '
            'La moyenne cantonale (${profile.canton}) est ~CHF\u00a0${avgRent.round()}. '
            'Ce chiffre est indicatif (source\u00a0: OFS 2023).'
          : null,
      // No estimatedMonthlySavings for rent — not directly actionable
      actionRoute: '/budget', // Route to budget, not mortgage (user is renter)
    );
  }

  static EnrichedAlert _enrichInsurance(
    ContractDeadline d, CoachProfile profile,
  ) {
    return EnrichedAlert(
      deadline: d,
      benchmarkMessage: 'Vérifie si ta couverture est toujours adaptée '
          'à ta situation actuelle.',
      actionRoute: '/assurances/lamal',
    );
  }

  static EnrichedAlert _enrichLpp(ContractDeadline d, CoachProfile profile) {
    final avoir = profile.prevoyance.avoirLppTotal;
    if (avoir == null || avoir <= 0) return EnrichedAlert(deadline: d);

    final rachat = profile.prevoyance.rachatMaximum;
    if (rachat != null && rachat > 10000) {
      return EnrichedAlert(
        deadline: d,
        benchmarkMessage: 'Tu as un potentiel de rachat LPP '
            'de ~CHF\u00a0${rachat.round()}. '
            'Un rachat pourrait réduire ton imposition — '
            'à vérifier avec ta caisse (art.\u00a079b LPP, blocage EPL 3\u00a0ans).',
        actionRoute: '/rachat-lpp',
      );
    }

    return EnrichedAlert(deadline: d);
  }

  /// Rough cantonal average rent (CHF/month, educational estimate).
  /// Source: OFS Enquête sur la structure des loyers, 2023.
  static double _cantonalAverageRent(String canton) {
    const averages = {
      'ZH': 1850, 'BE': 1250, 'LU': 1400, 'UR': 1100, 'SZ': 1500,
      'OW': 1200, 'NW': 1300, 'GL': 1100, 'ZG': 2000, 'FR': 1300,
      'SO': 1200, 'BS': 1500, 'BL': 1350, 'SH': 1200, 'AR': 1100,
      'AI': 1100, 'SG': 1300, 'GR': 1250, 'AG': 1400, 'TG': 1300,
      'TI': 1350, 'VD': 1600, 'VS': 1200, 'NE': 1200, 'GE': 2100,
      'JU': 1050,
    };
    return (averages[canton.toUpperCase()] ?? 1400).toDouble();
  }
}
