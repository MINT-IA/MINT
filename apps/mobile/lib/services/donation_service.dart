import 'dart:math';

import 'package:mint_mobile/l10n/app_localizations.dart';

// ────────────────────────────────────────────────────────────
//  DONATION SERVICE — Sprint S24
//  Calcul de l'impot sur les donations + impact successoral
//  CC art. 471 (nouveau droit 2023), lois fiscales cantonales
// ────────────────────────────────────────────────────────────

/// Result model for donation calculation.
class DonationResult {
  final double montantDonation;
  final double tauxImposition;
  final double impotDonation;
  final double reserveHereditaireTotale;
  final double quotiteDisponible;
  final bool donationDepasseQuotite;
  final double montantDepassement;
  final String impactSuccession;
  final List<String> checklist;
  final List<String> alerts;
  final String disclaimer;
  final List<String> sources;
  final String chiffreChoc;

  const DonationResult({
    required this.montantDonation,
    required this.tauxImposition,
    required this.impotDonation,
    required this.reserveHereditaireTotale,
    required this.quotiteDisponible,
    required this.donationDepasseQuotite,
    required this.montantDepassement,
    required this.impactSuccession,
    required this.checklist,
    required this.alerts,
    required this.disclaimer,
    required this.sources,
    required this.chiffreChoc,
  });
}

/// Service for calculating the tax impact of donations in Switzerland.
///
/// Covers cantonal donation tax rates, reserve hereditaire (2023 law),
/// quotite disponible, and impact on future succession.
class DonationService {
  // ── Cantonal donation tax rates by relationship ──
  // Source: cantonal tax laws on donations
  static const Map<String, Map<String, double>> tauxDonationCantonal = {
    'ZH': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.0,
      'fratrie': 0.06,
      'concubin': 0.18,
      'tiers': 0.24,
    },
    'BE': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.0,
      'fratrie': 0.06,
      'concubin': 0.18,
      'tiers': 0.24,
    },
    'VD': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.05,
      'fratrie': 0.07,
      'concubin': 0.25,
      'tiers': 0.25,
    },
    'GE': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.0,
      'fratrie': 0.10,
      'concubin': 0.24,
      'tiers': 0.30,
    },
    'LU': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.0,
      'fratrie': 0.08,
      'concubin': 0.20,
      'tiers': 0.25,
    },
    'BS': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.0,
      'fratrie': 0.08,
      'concubin': 0.22,
      'tiers': 0.28,
    },
    'SZ': {
      'conjoint': 0.0,
      'descendant': 0.0,
      'parent': 0.0,
      'fratrie': 0.0,
      'concubin': 0.0,
      'tiers': 0.0,
    },
  };

  // ── Reserve hereditaire (CC art. 471, nouveau droit 2023) ──
  // Fraction of legal share that is protected
  static const Map<String, double> reserves = {
    'descendant': 0.50, // 50% of legal share
    'conjoint': 0.50, // 50% of legal share
    'parent': 0.0, // No reserve since 2023
  };

  // ── Legal share fractions (CC art. 457-462) ──
  // Used to compute reserve hereditaire based on family composition
  static const Map<String, double> _partLegaleConjointAvecEnfants = {
    'conjoint': 0.50,
    'enfants': 0.50,
  };
  static const Map<String, double> _partLegaleConjointSansEnfants = {
    'conjoint': 0.75,
    'parents': 0.25,
  };

  /// Human-readable labels for relationship types.
  static Map<String, String> lienParenteLabelsLocalized(S s) => {
    'conjoint': s.donationServiceLienConjoint,
    'descendant': s.donationServiceLienDescendant,
    'parent': s.donationServiceLienParent,
    'fratrie': s.donationServiceLienFratrie,
    'concubin': s.donationServiceLienConcubin,
    'tiers': s.donationServiceLienTiers,
  };

  /// Calculate the tax and succession impact of a donation.
  static DonationResult calculate({
    required S s,
    required double montant,
    required int donateurAge,
    required String lienParente,
    required String canton,
    String typeDonation = 'especes',
    double valeurImmobiliere = 0,
    bool avancementHoirie = true,
    int nbEnfants = 0,
    double fortuneTotaleDonateur = 0,
    String regimeMatrimonial = 'participation_acquets',
  }) {
    // ── Effective donation amount ──
    final montantDonation =
        typeDonation == 'immobilier' && valeurImmobiliere > 0
            ? valeurImmobiliere
            : montant;

    // ── Tax rate lookup ──
    final cantonRates =
        tauxDonationCantonal[canton] ?? tauxDonationCantonal['VD']!;
    final tauxImposition = cantonRates[lienParente] ?? cantonRates['tiers']!;

    // ── Tax calculation ──
    final impotDonation = montantDonation * tauxImposition;

    // ── Reserve hereditaire calculation ──
    // Fortune base adjusted by matrimonial regime (CC art. 196ss)
    final fortuneBrute =
        fortuneTotaleDonateur > 0 ? fortuneTotaleDonateur : montantDonation;

    // Regime matrimonial affects the fortune entering succession:
    // - participation_acquets: conjoint reçoit 50% des acquêts avant partage
    //   → estimation simplifiée: ~75% de la fortune totale en masse successorale
    // - communaute_biens: 50% de la propriété commune revient au conjoint
    // - separation_biens: 100% de la fortune propre du donateur
    final double regimeFactor;
    switch (regimeMatrimonial) {
      case 'communaute_biens':
        regimeFactor = 0.50;
        break;
      case 'separation_biens':
        regimeFactor = 1.00;
        break;
      case 'participation_acquets':
      default:
        regimeFactor = 0.75;
        break;
    }
    final fortune = fortuneBrute * regimeFactor;

    double reserveHereditaireTotale = 0;
    double quotiteDisponible = 0;

    if (nbEnfants > 0) {
      // With children: conjoint gets 1/2, children share 1/2
      // Reserve = conjoint: 50% of 1/2 = 1/4 + children: 50% of 1/2 = 1/4
      final reserveConjoint = fortune *
          _partLegaleConjointAvecEnfants['conjoint']! *
          reserves['conjoint']!;
      final reserveEnfants = fortune *
          _partLegaleConjointAvecEnfants['enfants']! *
          reserves['descendant']!;
      reserveHereditaireTotale = reserveConjoint + reserveEnfants;
      quotiteDisponible = fortune - reserveHereditaireTotale;
    } else {
      // No children, with parents: conjoint gets 3/4, parents 1/4
      // But parents have no reserve since 2023 (CC art. 471 rev.)
      final reserveConjoint = fortune *
          _partLegaleConjointSansEnfants['conjoint']! *
          reserves['conjoint']!;
      reserveHereditaireTotale = reserveConjoint;
      quotiteDisponible = fortune - reserveHereditaireTotale;
    }

    quotiteDisponible = max(0, quotiteDisponible);

    // ── Check if donation exceeds quotite disponible ──
    final donationDepasseQuotite = montantDonation > quotiteDisponible;
    final montantDepassement =
        donationDepasseQuotite ? montantDonation - quotiteDisponible : 0.0;

    // ── Impact on succession ──
    String impactSuccession;
    if (avancementHoirie) {
      impactSuccession = s.donationServiceImpactAvancement;
    } else {
      if (donationDepasseQuotite) {
        impactSuccession = s.donationServiceImpactDepassement(
          quotiteDisponible.round().toString(),
        );
      } else {
        impactSuccession = s.donationServiceImpactQuotite(
          quotiteDisponible.round().toString(),
        );
      }
    }

    // ── Alerts ──
    final alerts = <String>[];

    if (donationDepasseQuotite) {
      alerts.add(
        s.donationServiceAlertDepassement(
          montantDepassement.round().toString(),
        ),
      );
    }

    if (lienParente == 'concubin' && tauxImposition > 0.15) {
      alerts.add(
        s.donationServiceAlertConcubin(
          canton,
          (tauxImposition * 100).toStringAsFixed(0),
        ),
      );
    }

    if (typeDonation == 'immobilier') {
      alerts.add(s.donationServiceAlertImmobilier);
    }

    if (donateurAge >= 70) {
      alerts.add(s.donationServiceAlertAgeDeces);
    }

    if (montantDonation > fortune * 0.5 && fortuneTotaleDonateur > 0) {
      alerts.add(s.donationServiceAlertFortune);
    }

    // ── Checklist ──
    final checklist = <String>[
      s.donationServiceChecklistNotaire,
      s.donationServiceChecklistActe,
      s.donationServiceChecklistFiscal,
      s.donationServiceChecklistHeritiers,
      s.donationServiceChecklistCopie,
    ];

    if (typeDonation == 'immobilier') {
      checklist.add(s.donationServiceChecklistRegistreFoncier);
    }

    if (avancementHoirie) {
      checklist.add(s.donationServiceChecklistRapportSuccessoral);
    }

    if (lienParente == 'concubin') {
      checklist.add(s.donationServiceChecklistTestament);
    }

    // ── Chiffre choc ──
    final chiffreChoc = impotDonation > 0
        ? s.donationServiceChiffreChocImpot(
            impotDonation.round().toString(),
            (tauxImposition * 100).toStringAsFixed(0),
          )
        : s.donationServiceChiffreChocExonere(canton);

    // ── Disclaimer ──
    final disclaimer = s.donationServiceDisclaimer;

    // ── Sources ──
    const sources = [
      'CC art. 457-471 (Droit successoral)',
      'CC art. 471 (Réserves héréditaires, révision 2023)',
      'CC art. 522 ss (Action en réduction)',
      'CC art. 527 (Donations contestables)',
      'Lois fiscales cantonales sur les donations',
      'CO art. 239 ss (Donation)',
    ];

    return DonationResult(
      montantDonation: montantDonation,
      tauxImposition: tauxImposition,
      impotDonation: impotDonation,
      reserveHereditaireTotale: reserveHereditaireTotale,
      quotiteDisponible: quotiteDisponible,
      donationDepasseQuotite: donationDepasseQuotite,
      montantDepassement: montantDepassement,
      impactSuccession: impactSuccession,
      checklist: checklist,
      alerts: alerts,
      disclaimer: disclaimer,
      sources: sources,
      chiffreChoc: chiffreChoc,
    );
  }
}
