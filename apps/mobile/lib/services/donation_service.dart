import 'dart:math';

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
  static const Map<String, String> lienParenteLabels = {
    'conjoint': 'Conjoint(e)',
    'descendant': 'Enfant / Descendant(e)',
    'parent': 'Parent',
    'fratrie': 'Frere / Soeur',
    'concubin': 'Concubin(e)',
    'tiers': 'Tiers',
  };

  /// Calculate the tax and succession impact of a donation.
  static DonationResult calculate({
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
      impactSuccession =
          'Cette donation en avancement d\'hoirie sera rapportee a '
          'la masse successorale. La part du donataire sera reduite '
          'd\'autant lors de la succession.';
    } else {
      if (donationDepasseQuotite) {
        impactSuccession =
            'Cette donation hors avancement d\'hoirie depasse la quotite '
            'disponible de CHF ${quotiteDisponible.round()}. '
            'Les heritiers reservataires pourraient la contester '
            'par action en reduction (CC art. 522).';
      } else {
        impactSuccession =
            'Cette donation hors avancement d\'hoirie est imputee sur '
            'la quotite disponible (CHF ${quotiteDisponible.round()}). '
            'Elle ne sera pas rapportee a la succession.';
      }
    }

    // ── Alerts ──
    final alerts = <String>[];

    if (donationDepasseQuotite) {
      alerts.add(
        'La donation depasse la quotite disponible de '
        'CHF ${montantDepassement.round()}. Les heritiers reservataires '
        'pourraient exercer une action en reduction (CC art. 522 ss).',
      );
    }

    if (lienParente == 'concubin' && tauxImposition > 0.15) {
      alerts.add(
        'Attention : le taux d\'imposition pour un·e concubin·e est '
        'eleve ($canton : ${(tauxImposition * 100).toStringAsFixed(0)}%). '
        'Un pacte successoral ou un testament pourrait etre plus avantageux.',
      );
    }

    if (typeDonation == 'immobilier') {
      alerts.add(
        'Pour une donation immobiliere, des droits de mutation '
        'supplementaires peuvent s\'appliquer selon le canton. '
        'Un passage devant notaire est obligatoire.',
      );
    }

    if (donateurAge >= 70) {
      alerts.add(
        'Attention : les donations effectuees peu avant le deces '
        'peuvent etre contestees (CC art. 527). Plus la donation est '
        'proche du deces, plus le risque de contestation est eleve.',
      );
    }

    if (montantDonation > fortune * 0.5 && fortuneTotaleDonateur > 0) {
      alerts.add(
        'Cette donation represente plus de 50% de ta fortune totale. '
        'Assure-toi de conserver suffisamment de reserves pour tes '
        'propres besoins (retraite, sante, imprevus).',
      );
    }

    // ── Checklist ──
    final checklist = <String>[
      'Verifier la quotite disponible avec un notaire',
      'Rediger un acte de donation (notarie si immobilier)',
      'Declarer la donation aux autorites fiscales cantonales',
      'Informer les heritiers reservataires si necessaire',
      'Conserver une copie de l\'acte dans tes documents',
    ];

    if (typeDonation == 'immobilier') {
      checklist.add('Proceder a l\'inscription au registre foncier');
    }

    if (avancementHoirie) {
      checklist.add(
        'Documenter le montant pour le rapport successoral futur',
      );
    }

    if (lienParente == 'concubin') {
      checklist.add(
        'Envisager un testament en complement de la donation',
      );
    }

    // ── Chiffre choc ──
    final chiffreChoc = impotDonation > 0
        ? 'Impot sur la donation : CHF ${impotDonation.round()} '
            '(${(tauxImposition * 100).toStringAsFixed(0)}%)'
        : 'Bonne nouvelle : cette donation est exoneree d\'impot '
            'dans le canton $canton';

    // ── Disclaimer ──
    const disclaimer =
        'Cet outil educatif fournit des estimations indicatives et '
        'ne constitue pas un conseil juridique, fiscal ou notarial '
        'personnalise au sens de la LSFin. Le droit des donations '
        'et successions comporte de nombreuses subtilites cantonales. '
        'Consulte un·e specialiste (notaire) pour ta situation.';

    // ── Sources ──
    const sources = [
      'CC art. 457-471 (Droit successoral)',
      'CC art. 471 (Reserves hereditaires, revision 2023)',
      'CC art. 522 ss (Action en reduction)',
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
