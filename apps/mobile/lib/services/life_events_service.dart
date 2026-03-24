import 'package:mint_mobile/services/financial_core/tax_calculator.dart';

// ────────────────────────────────────────────────────────────
//  DIVORCE SERVICE
// ────────────────────────────────────────────────────────────

/// Matrimonial regime options under Swiss law.
enum MatrimonialRegime {
  participationAuxAcquets, // default CC 181 ss
  communauteDeBiens, // CC 221 ss
  separationDeBiens, // CC 247 ss
}

/// Input model for the divorce simulator.
class DivorceInput {
  final int marriageDurationYears;
  final int numberOfChildren;
  final MatrimonialRegime regime;
  final double incomeConjoint1;
  final double incomeConjoint2;
  final double lppConjoint1;
  final double lppConjoint2;
  final double pillar3aConjoint1;
  final double pillar3aConjoint2;
  final double fortuneCommune;
  final double dettesCommunes;

  const DivorceInput({
    required this.marriageDurationYears,
    required this.numberOfChildren,
    required this.regime,
    required this.incomeConjoint1,
    required this.incomeConjoint2,
    required this.lppConjoint1,
    required this.lppConjoint2,
    required this.pillar3aConjoint1,
    required this.pillar3aConjoint2,
    required this.fortuneCommune,
    required this.dettesCommunes,
  });
}

/// LPP split result.
class LppSplitResult {
  final double totalLpp;
  final double shareConjoint1;
  final double shareConjoint2;
  final double transferAmount;
  final String transferDirection; // "1 → 2" or "2 → 1"

  const LppSplitResult({
    required this.totalLpp,
    required this.shareConjoint1,
    required this.shareConjoint2,
    required this.transferAmount,
    required this.transferDirection,
  });
}

/// Tax impact result.
class TaxImpactResult {
  final double estimatedTaxMarried;
  final double estimatedTaxConjoint1;
  final double estimatedTaxConjoint2;
  final double totalTaxAfter;
  final double delta;

  const TaxImpactResult({
    required this.estimatedTaxMarried,
    required this.estimatedTaxConjoint1,
    required this.estimatedTaxConjoint2,
    required this.totalTaxAfter,
    required this.delta,
  });
}

/// Patrimoine split result.
class PatrimoineSplitResult {
  final double fortuneNette;
  final double shareConjoint1;
  final double shareConjoint2;

  const PatrimoineSplitResult({
    required this.fortuneNette,
    required this.shareConjoint1,
    required this.shareConjoint2,
  });
}

/// Full divorce simulation result.
class DivorceResult {
  final LppSplitResult lppSplit;
  final TaxImpactResult taxImpact;
  final PatrimoineSplitResult patrimoineSplit;
  final double pensionAlimentaireMonthly;
  final List<String> alerts;
  final List<String> checklist;

  const DivorceResult({
    required this.lppSplit,
    required this.taxImpact,
    required this.patrimoineSplit,
    required this.pensionAlimentaireMonthly,
    required this.alerts,
    required this.checklist,
  });
}

/// Service for simulating the financial impact of divorce under Swiss law.
class DivorceService {
  /// Run a full divorce financial simulation.
  static DivorceResult simulate({required DivorceInput input}) {
    // ---- LPP Split (CC 122 / LFLP 22) ----
    // During marriage, accumulated LPP is split 50/50.
    final totalLpp = input.lppConjoint1 + input.lppConjoint2;
    final halfLpp = totalLpp / 2;
    final lppTransfer = (input.lppConjoint1 - input.lppConjoint2).abs() / 2;
    final lppDirection =
        input.lppConjoint1 > input.lppConjoint2 ? '1 \u2192 2' : '2 \u2192 1';

    final lppSplit = LppSplitResult(
      totalLpp: totalLpp,
      shareConjoint1: halfLpp,
      shareConjoint2: halfLpp,
      transferAmount: lppTransfer,
      transferDirection: input.lppConjoint1 == input.lppConjoint2
          ? '-'
          : lppDirection,
    );

    // ---- 3a Split ----
    // Under participation aux acquêts, 3a accumulated during marriage is
    // considered an acquêt and split 50/50.
    // Under séparation de biens, no split.
    // Under communauté de biens, 100% pooled and split 50/50.
    // Note: 3a split depends on regime but is handled separately via
    // the LPP/3a partage logic. The patrimoine split below covers net wealth.

    // ---- Patrimoine Split ----
    final fortuneNette = input.fortuneCommune - input.dettesCommunes;
    double shareC1;
    double shareC2;

    switch (input.regime) {
      case MatrimonialRegime.participationAuxAcquets:
        // Each keeps own property; acquêts (= common fortune here) split 50/50
        shareC1 = fortuneNette / 2;
        shareC2 = fortuneNette / 2;
      case MatrimonialRegime.communauteDeBiens:
        // Everything pooled and split 50/50
        shareC1 = fortuneNette / 2;
        shareC2 = fortuneNette / 2;
      case MatrimonialRegime.separationDeBiens:
        // Each keeps their own — simplified: we split proportionally to income
        final totalIncome = input.incomeConjoint1 + input.incomeConjoint2;
        if (totalIncome > 0) {
          shareC1 = fortuneNette * (input.incomeConjoint1 / totalIncome);
          shareC2 = fortuneNette * (input.incomeConjoint2 / totalIncome);
        } else {
          shareC1 = fortuneNette / 2;
          shareC2 = fortuneNette / 2;
        }
    }

    final patrimoineSplit = PatrimoineSplitResult(
      fortuneNette: fortuneNette,
      shareConjoint1: shareC1,
      shareConjoint2: shareC2,
    );

    // ---- Tax Impact ----
    // Simplified Swiss tax estimation:
    // Married couples benefit from ~15-25% effective discount (splitting).
    // After divorce, each is taxed individually.
    final combinedIncome = input.incomeConjoint1 + input.incomeConjoint2;
    // Married rate via centralized calculator (splitting + canton-average)
    final marriedRate = RetirementTaxCalculator.estimateMarginalRate(
      combinedIncome, 'ZH', isMarried: true,
    );
    final taxMarried = combinedIncome * marriedRate;
    // Individual rates slightly higher per person
    final taxC1 = _estimateIndividualTax(input.incomeConjoint1);
    final taxC2 = _estimateIndividualTax(input.incomeConjoint2);
    final totalTaxAfter = taxC1 + taxC2;

    final taxImpact = TaxImpactResult(
      estimatedTaxMarried: taxMarried,
      estimatedTaxConjoint1: taxC1,
      estimatedTaxConjoint2: taxC2,
      totalTaxAfter: totalTaxAfter,
      delta: totalTaxAfter - taxMarried,
    );

    // ---- Pension Alimentaire ----
    // Simplified estimation based on Swiss practice.
    // Child contributions: CHF 600/month per child (base, age-independent).
    // Spousal maintenance: depends on marriage duration and income gap.
    // Aligned with backend (job_comparator/divorce_simulator) parameters.
    double pensionAlimentaire = 0;
    final incomeGap =
        (input.incomeConjoint1 - input.incomeConjoint2).abs();

    // Children contribution (always applies if children exist)
    final childContribution = input.numberOfChildren * 600.0;

    // Spousal maintenance: only for marriages >= 5 years with income gap
    double spouseContribution = 0;
    if (input.marriageDurationYears >= 10 && incomeGap > 0) {
      // Long marriage: ~15% of monthly income gap
      spouseContribution = (incomeGap / 12.0) * 0.15;
    } else if (input.marriageDurationYears >= 5 && incomeGap > 0) {
      // Shorter marriage: reduced spousal maintenance (~8%)
      spouseContribution = (incomeGap / 12.0) * 0.08;
    }

    pensionAlimentaire = childContribution + spouseContribution;

    // ---- Alerts ----
    final alerts = <String>[];

    if (lppTransfer > 100000) {
      alerts.add(
        'Le transfert LPP est significatif ('
        '${_formatChf(lppTransfer)}). Verifiez les montants exacts '
        'aupres de ta caisse de pension.',
      );
    }

    if (input.dettesCommunes > input.fortuneCommune * 0.5) {
      alerts.add(
        'Le niveau de dettes communes est eleve. Clarifiez la '
        'repartition des dettes avant de signer la convention.',
      );
    }

    if (taxImpact.delta > 5000) {
      alerts.add(
        'L\'impact fiscal du divorce est important : '
        '+${_formatChf(taxImpact.delta)}/an. Anticipez ce surcout '
        'dans ton budget.',
      );
    }

    if (input.marriageDurationYears >= 10 && incomeGap > 40000) {
      alerts.add(
        'Mariage de longue duree avec ecart de revenus important. '
        'Une contribution d\'entretien au conjoint est probable.',
      );
    }

    if (input.numberOfChildren > 0) {
      alerts.add(
        'Avec ${input.numberOfChildren} enfant(s), la garde et les '
        'contributions d\'entretien seront les points centraux de '
        'la convention.',
      );
    }

    if (input.regime == MatrimonialRegime.separationDeBiens) {
      alerts.add(
        'Regime de separation de biens : le partage du patrimoine '
        'est plus simple mais le 3a n\'est pas automatiquement '
        'partage.',
      );
    }

    // ---- Checklist ----
    final checklist = <String>[
      'Demander les certificats LPP des deux conjoints',
      'Demander le releve detaille des avoirs 3a',
      'Lister tous les biens communs et propres',
      'Consulter un(e) mediateur/trice agree(e)',
      'Verifier les clauses beneficiaires 3a et assurances-vie',
      'Etablir un budget post-divorce pour chaque conjoint',
      'Clarifier la garde des enfants et les contributions',
      'Preparer la convention de divorce (ou requete)',
      'Verifier l\'impact sur le logement familial',
      'Mettre a jour le testament et les directives anticipees',
    ];

    return DivorceResult(
      lppSplit: lppSplit,
      taxImpact: taxImpact,
      patrimoineSplit: patrimoineSplit,
      pensionAlimentaireMonthly: pensionAlimentaire,
      alerts: alerts,
      checklist: checklist,
    );
  }

  /// Simplified individual tax estimation (Swiss progressive).
  ///
  /// Delegates to RetirementTaxCalculator.estimateMarginalRate for the
  /// income-based marginal rate, then applies it as an effective rate.
  /// Canton defaults to 'ZH' (median tax burden) since the divorce
  /// service does not have canton in scope here.
  /// TODO(profile-injection): Pass canton from DivorceInput when available.
  static double _estimateIndividualTax(double income) {
    if (income <= 0) return 0;
    // Use centralized marginal rate (AFC taux marginaux 2025).
    // 'ZH' is used as a median proxy — not exact, but avoids fabricated brackets.
    final marginalRate =
        RetirementTaxCalculator.estimateMarginalRate(income, 'ZH');
    // Effective tax ≈ ~60-70% of marginal rate for progressive systems.
    // This approximation aligns with the old bracket-based approach.
    return income * marginalRate * 0.65;
  }

  /// Format CHF with Swiss apostrophe.
  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}

// ────────────────────────────────────────────────────────────
//  SUCCESSION SERVICE
// ────────────────────────────────────────────────────────────

/// Civil status for succession.
enum CivilStatus {
  marie,
  celibataire,
  divorce,
  veuf,
  concubinage,
}

/// Input model for the succession simulator.
class SuccessionInput {
  final CivilStatus civilStatus;
  final int numberOfChildren;
  final bool parentsVivants;
  final bool hasFratrie;
  final bool hasConcubin;
  final double fortuneTotale;
  final double avoirs3a;
  final double capitalDecesLpp;
  final String canton; // VD, GE, ZH, BE, LU, BS
  final bool hasTestament;
  final String? testamentBeneficiary; // "conjoint", "enfants", "concubin", "tiers"

  const SuccessionInput({
    required this.civilStatus,
    required this.numberOfChildren,
    required this.parentsVivants,
    required this.hasFratrie,
    required this.hasConcubin,
    required this.fortuneTotale,
    required this.avoirs3a,
    required this.capitalDecesLpp,
    required this.canton,
    required this.hasTestament,
    this.testamentBeneficiary,
  });
}

/// One heir's share.
class HeirShare {
  final String heirLabel;
  final double amount;
  final double percentage;
  final double reserve; // legally protected minimum
  final double? taxAmount;

  const HeirShare({
    required this.heirLabel,
    required this.amount,
    required this.percentage,
    required this.reserve,
    this.taxAmount,
  });
}

/// Full succession simulation result.
class SuccessionResult {
  final List<HeirShare> legalDistribution;
  final List<HeirShare>? testamentDistribution;
  final double quotiteDisponible;
  final double quotiteDisponiblePct;
  final double totalEstate;
  final List<String> alerts;
  final List<String> checklist;
  final Map<String, double> taxByHeir;
  final String pillar3aBeneficiaryOrder;

  const SuccessionResult({
    required this.legalDistribution,
    this.testamentDistribution,
    required this.quotiteDisponible,
    required this.quotiteDisponiblePct,
    required this.totalEstate,
    required this.alerts,
    required this.checklist,
    required this.taxByHeir,
    required this.pillar3aBeneficiaryOrder,
  });
}

/// Service for simulating succession under Swiss law (new 2023 revision).
class SuccessionService {
  /// Run a full succession simulation.
  static SuccessionResult simulate({required SuccessionInput input}) {
    final totalEstate = input.fortuneTotale;

    // ---- Legal Distribution ----
    final legalShares = _computeLegalShares(
      civilStatus: input.civilStatus,
      numberOfChildren: input.numberOfChildren,
      parentsVivants: input.parentsVivants,
      hasFratrie: input.hasFratrie,
      totalEstate: totalEstate,
    );

    // ---- Reserves (new 2023 law) ----
    // New law: descendants reserve = 1/2 (was 3/4)
    // Spouse reserve = 1/2 (unchanged)
    // Parents: no more reserve (was 1/2 of their share)
    final reserveData = _computeReserves(
      civilStatus: input.civilStatus,
      numberOfChildren: input.numberOfChildren,
      totalEstate: totalEstate,
    );

    final totalReserves = reserveData.values.fold(0.0, (a, b) => a + b);
    final quotiteDisponible = totalEstate - totalReserves;
    final quotiteDisponiblePct =
        totalEstate > 0 ? quotiteDisponible / totalEstate : 0.0;

    // Build legal distribution with reserves
    final legalDistribution = legalShares.entries.map((entry) {
      final reserve = reserveData[entry.key] ?? 0.0;
      return HeirShare(
        heirLabel: entry.key,
        amount: entry.value,
        percentage: totalEstate > 0 ? entry.value / totalEstate : 0,
        reserve: reserve,
      );
    }).toList();

    // ---- Testament Distribution ----
    List<HeirShare>? testamentDistribution;
    if (input.hasTestament && input.testamentBeneficiary != null) {
      testamentDistribution = _computeTestamentDistribution(
        civilStatus: input.civilStatus,
        numberOfChildren: input.numberOfChildren,
        totalEstate: totalEstate,
        quotiteDisponible: quotiteDisponible,
        beneficiary: input.testamentBeneficiary!,
        reserveData: reserveData,
      );
    }

    // ---- Tax by Heir ----
    final taxByHeir = <String, double>{};
    final distribution = testamentDistribution ?? legalDistribution;
    for (final heir in distribution) {
      final tax = _estimateSuccessionTax(
        amount: heir.amount,
        canton: input.canton,
        kinship: _kinshipFromLabel(heir.heirLabel),
      );
      taxByHeir[heir.heirLabel] = tax;
    }

    // ---- 3a Beneficiary Order (OPP3 art. 2) ----
    final pillar3aOrder = _get3aBeneficiaryOrder(input.civilStatus);

    // ---- Alerts ----
    final alerts = <String>[];

    if (input.civilStatus == CivilStatus.concubinage) {
      alerts.add(
        'En concubinage, ton/ta partenaire n\'a AUCUN droit '
        'successoral legal. Sans testament, il/elle ne recoit '
        'rien. La fiscalite est aussi nettement plus lourde '
        '(taux "tiers").',
      );
    }

    if (input.avoirs3a > 0 &&
        (input.civilStatus == CivilStatus.concubinage ||
            input.civilStatus == CivilStatus.celibataire)) {
      alerts.add(
        'Tes avoirs 3a (${_formatChf(input.avoirs3a)}) suivent '
        'l\'ordre de beneficiaires OPP3, pas ton testament. '
        'Verifie tes clauses beneficiaires aupres de ta '
        'fondation 3a.',
      );
    }

    if (input.capitalDecesLpp > 0) {
      alerts.add(
        'Le capital-deces LPP (${_formatChf(input.capitalDecesLpp)}) '
        'n\'entre pas dans la masse successorale. Il est verse '
        'selon le reglement de ta caisse de pension.',
      );
    }

    if (quotiteDisponiblePct > 0.49 && input.numberOfChildren > 0) {
      alerts.add(
        'Nouveau droit 2023 : la quotite disponible est desormais '
        'de ${(quotiteDisponiblePct * 100).toStringAsFixed(0)}% '
        'de ta succession. Tu as plus de liberte pour '
        'avantager certains heritiers.',
      );
    }

    if (input.numberOfChildren == 0 && !input.parentsVivants) {
      alerts.add(
        'Sans descendant ni parent, la fratrie herite. Sans '
        'fratrie non plus, la succession va au canton.',
      );
    }

    // ---- Checklist ----
    final checklist = <String>[
      'Testament redige / mis a jour ?',
      'Clause beneficiaire 3a verifiee ?',
      if (input.civilStatus == CivilStatus.concubinage ||
          input.civilStatus == CivilStatus.marie)
        'Concubin/conjoint annonce a la caisse de pension ?',
      'Mandat pour cause d\'inaptitude redige ?',
      'Directives anticipees redigees ?',
      'Inventaire des biens (immobilier, comptes, assurances) a jour ?',
      'Polices d\'assurance-vie verifiees ?',
      'Discussion avec les heritiers sur les volontes ?',
    ];

    return SuccessionResult(
      legalDistribution: legalDistribution,
      testamentDistribution: testamentDistribution,
      quotiteDisponible: quotiteDisponible,
      quotiteDisponiblePct: quotiteDisponiblePct,
      totalEstate: totalEstate,
      alerts: alerts,
      checklist: checklist,
      taxByHeir: taxByHeir,
      pillar3aBeneficiaryOrder: pillar3aOrder,
    );
  }

  /// Compute legal shares based on civil status and heirs.
  static Map<String, double> _computeLegalShares({
    required CivilStatus civilStatus,
    required int numberOfChildren,
    required bool parentsVivants,
    required bool hasFratrie,
    required double totalEstate,
  }) {
    final shares = <String, double>{};

    switch (civilStatus) {
      case CivilStatus.marie:
        if (numberOfChildren > 0) {
          // Spouse: 1/2, Children: 1/2 shared equally
          shares['Conjoint'] = totalEstate / 2;
          final childShare = totalEstate / 2 / numberOfChildren;
          for (int i = 1; i <= numberOfChildren; i++) {
            shares['Enfant $i'] = childShare;
          }
        } else if (parentsVivants) {
          // Spouse: 3/4, Parents: 1/4
          shares['Conjoint'] = totalEstate * 3 / 4;
          shares['Parents'] = totalEstate / 4;
        } else {
          // Spouse gets everything
          shares['Conjoint'] = totalEstate;
        }

      case CivilStatus.celibataire:
      case CivilStatus.divorce:
      case CivilStatus.concubinage:
        if (numberOfChildren > 0) {
          // Children share equally
          final childShare = totalEstate / numberOfChildren;
          for (int i = 1; i <= numberOfChildren; i++) {
            shares['Enfant $i'] = childShare;
          }
        } else if (parentsVivants) {
          // Parents get everything (or share with siblings)
          shares['Parents'] = totalEstate;
        } else if (hasFratrie) {
          shares['Fratrie'] = totalEstate;
        } else {
          shares['Canton'] = totalEstate;
        }

      case CivilStatus.veuf:
        if (numberOfChildren > 0) {
          final childShare = totalEstate / numberOfChildren;
          for (int i = 1; i <= numberOfChildren; i++) {
            shares['Enfant $i'] = childShare;
          }
        } else if (parentsVivants) {
          shares['Parents'] = totalEstate;
        } else if (hasFratrie) {
          shares['Fratrie'] = totalEstate;
        } else {
          shares['Canton'] = totalEstate;
        }
    }

    return shares;
  }

  /// Compute reserves under new 2023 law.
  static Map<String, double> _computeReserves({
    required CivilStatus civilStatus,
    required int numberOfChildren,
    required double totalEstate,
  }) {
    final reserves = <String, double>{};

    switch (civilStatus) {
      case CivilStatus.marie:
        // Spouse reserve: 1/2 of their legal share
        if (numberOfChildren > 0) {
          // Spouse legal share = 1/2 → reserve = 1/2 * 1/2 = 1/4
          reserves['Conjoint'] = totalEstate / 4;
          // Children legal share = 1/2 → reserve = 1/2 * 1/2 = 1/4 (total for all children)
          final childReserveTotal = totalEstate / 4;
          final childReserve = childReserveTotal / numberOfChildren;
          for (int i = 1; i <= numberOfChildren; i++) {
            reserves['Enfant $i'] = childReserve;
          }
        } else {
          // Spouse alone: reserve = 1/2 of estate
          reserves['Conjoint'] = totalEstate / 2;
          // Parents: no more reserve under 2023 law
        }

      case CivilStatus.celibataire:
      case CivilStatus.divorce:
      case CivilStatus.veuf:
      case CivilStatus.concubinage:
        if (numberOfChildren > 0) {
          // Children reserve: 1/2 of their legal share
          // Legal share = 100%, reserve = 1/2 each (total = 1/2)
          final childReserveTotal = totalEstate / 2;
          final childReserve = childReserveTotal / numberOfChildren;
          for (int i = 1; i <= numberOfChildren; i++) {
            reserves['Enfant $i'] = childReserve;
          }
        }
        // Parents: no reserve under 2023 law
    }

    return reserves;
  }

  /// Compute testament distribution respecting reserves.
  static List<HeirShare> _computeTestamentDistribution({
    required CivilStatus civilStatus,
    required int numberOfChildren,
    required double totalEstate,
    required double quotiteDisponible,
    required String beneficiary,
    required Map<String, double> reserveData,
  }) {
    final shares = <HeirShare>[];

    // Each reserved heir gets their reserve
    for (final entry in reserveData.entries) {
      shares.add(HeirShare(
        heirLabel: entry.key,
        amount: entry.value,
        percentage: totalEstate > 0 ? entry.value / totalEstate : 0,
        reserve: entry.value,
      ));
    }

    // Quotité disponible goes to the chosen beneficiary
    String beneficiaryLabel;
    switch (beneficiary) {
      case 'conjoint':
        beneficiaryLabel = 'Conjoint (testament)';
      case 'enfants':
        beneficiaryLabel = 'Enfants (testament)';
      case 'concubin':
        beneficiaryLabel = 'Concubin(e) (testament)';
      case 'tiers':
        beneficiaryLabel = 'Tiers (testament)';
      default:
        beneficiaryLabel = 'Beneficiaire (testament)';
    }

    // Check if beneficiary already has a reserved share (e.g. conjoint)
    final existingIndex =
        shares.indexWhere((s) => s.heirLabel == 'Conjoint' && beneficiary == 'conjoint');
    if (existingIndex >= 0) {
      final existing = shares[existingIndex];
      shares[existingIndex] = HeirShare(
        heirLabel: existing.heirLabel,
        amount: existing.amount + quotiteDisponible,
        percentage: totalEstate > 0
            ? (existing.amount + quotiteDisponible) / totalEstate
            : 0,
        reserve: existing.reserve,
      );
    } else {
      shares.add(HeirShare(
        heirLabel: beneficiaryLabel,
        amount: quotiteDisponible,
        percentage: totalEstate > 0 ? quotiteDisponible / totalEstate : 0,
        reserve: 0,
      ));
    }

    return shares;
  }

  /// Estimate succession tax by canton and kinship.
  static double _estimateSuccessionTax({
    required double amount,
    required String canton,
    required String kinship,
  }) {
    if (amount <= 0) return 0;

    // In most Swiss cantons, spouse and descendants are exempt or near-exempt.
    // Concubins and third parties pay significantly more.
    // Simplified rates:
    final rates = _successionTaxRates[canton] ?? _successionTaxRates['VD']!;
    final rate = rates[kinship] ?? rates['tiers']!;
    return amount * rate;
  }

  /// Simplified succession tax rates by canton and kinship.
  static const _successionTaxRates = <String, Map<String, double>>{
    'VD': {
      'conjoint': 0.0, // exempt
      'enfant': 0.0, // exempt
      'parent': 0.0, // exempt
      'fratrie': 0.07, // ~7%
      'concubin': 0.25, // ~25%
      'tiers': 0.25, // ~25%
    },
    'GE': {
      'conjoint': 0.0,
      'enfant': 0.0,
      'parent': 0.0,
      'fratrie': 0.06,
      'concubin': 0.24,
      'tiers': 0.26,
    },
    'ZH': {
      'conjoint': 0.0,
      'enfant': 0.02, // low rate
      'parent': 0.02,
      'fratrie': 0.06,
      'concubin': 0.18,
      'tiers': 0.24,
    },
    'BE': {
      'conjoint': 0.0,
      'enfant': 0.0,
      'parent': 0.0,
      'fratrie': 0.06,
      'concubin': 0.24,
      'tiers': 0.30,
    },
    'LU': {
      'conjoint': 0.0,
      'enfant': 0.0,
      'parent': 0.0,
      'fratrie': 0.08,
      'concubin': 0.20,
      'tiers': 0.28,
    },
    'BS': {
      'conjoint': 0.0,
      'enfant': 0.0,
      'parent': 0.0,
      'fratrie': 0.10,
      'concubin': 0.22,
      'tiers': 0.25,
    },
  };

  /// Determine kinship category from heir label.
  static String _kinshipFromLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('conjoint')) return 'conjoint';
    if (lower.contains('enfant')) return 'enfant';
    if (lower.contains('parent')) return 'parent';
    if (lower.contains('fratrie')) return 'fratrie';
    if (lower.contains('concubin')) return 'concubin';
    return 'tiers';
  }

  /// Get 3a beneficiary order per OPP3 art. 2.
  static String _get3aBeneficiaryOrder(CivilStatus status) {
    switch (status) {
      case CivilStatus.marie:
        return '1. Conjoint survivant\n'
            '2. Descendants directs / personnes a charge\n'
            '3. Parents\n'
            '4. Fratrie\n'
            '5. Autres heritiers';
      case CivilStatus.concubinage:
        return '1. Partenaire de vie (si clause beneficiaire deposee)\n'
            '2. Descendants directs / personnes a charge\n'
            '3. Parents\n'
            '4. Fratrie\n'
            '5. Autres heritiers\n\n'
            'IMPORTANT : Sans clause beneficiaire explicite, '
            'le/la concubin(e) n\'est PAS automatiquement '
            'beneficiaire.';
      case CivilStatus.celibataire:
      case CivilStatus.divorce:
      case CivilStatus.veuf:
        return '1. Descendants directs / personnes a charge\n'
            '2. Parents\n'
            '3. Fratrie\n'
            '4. Autres heritiers';
    }
  }

  /// Format CHF with Swiss apostrophe.
  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}
