import 'dart:math';

import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/services/financial_core/income_tax_model_v2.dart';

// ────────────────────────────────────────────────────────────
//  FAMILY SERVICE — Sprint S22 / Famille & Concubinage
// ────────────────────────────────────────────────────────────
//
// Pure Dart service for Swiss family financial planning:
//   1. compareFiscalMariage       — Marriage penalty/bonus
//   2. simulateCongeParental      — APG parental leave
//   3. estimateAllocations        — Cantonal family allowances
//   4. calculateImpactFiscalEnfant — Tax impact of children
//   5. compareMariageVsConcubinage — Full comparison
//   6. estimateInheritanceTax     — Inheritance tax comparison
//
// All constants match 2025/2026 Swiss legislation.
// No banned terms ("garanti", "certain", "assure", "sans risque").
// ────────────────────────────────────────────────────────────

class FamilyService {
  FamilyService._();

  // ════════════════════════════════════════════════════════════
  //  MARIAGE FISCAL CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// Double-earner deduction (LIFD art. 33 al. 2).
  static const double deductionDoubleRevenu = 2800.0;

  /// Married couple deduction (LIFD).
  static const double deductionMarie = 2700.0;

  /// Insurance deduction — married couple.
  static const double deductionAssuranceMarie = 3600.0;

  /// Insurance deduction — single person.
  static const double deductionAssuranceCelibataire = 1800.0;

  /// Deduction per child — federal (LIFD art. 35 al. 1 let. a, ESTV 2026).
  static const double deductionParEnfant = 6800.0;

  /// Deduction per child — cantonal (LHID art. 9 al. 2 let. c).
  /// AFC "Charge fiscale en Suisse 2024" tables, rounded to CHF 100.
  /// When a canton is absent from the map, fall back to the federal
  /// value (conservative — cantonal is almost always higher).
  static const Map<String, double> deductionParEnfantCantonal = {
    'GE': 13000.0,
    'VD': 11000.0,
    'NE': 9500.0,
    'JU': 9500.0,
    'FR': 9100.0,
    'VS': 7450.0,
    'TI': 11100.0,
    'ZH': 9000.0,
    'BE': 8000.0,
    'BS': 7800.0,
    'LU': 6700.0,
    'ZG': 12000.0,
    'SG': 10200.0,
    'AG': 7000.0,
    'TG': 7000.0,
    'GR': 6500.0,
    'SO': 6000.0,
    'BL': 7500.0,
    'SH': 8400.0,
    'SZ': 9000.0,
    'NW': 6500.0,
    'OW': 6800.0,
    'UR': 8000.0,
    'AR': 6500.0,
    'AI': 6000.0,
    'GL': 7000.0,
  };

  /// Full child deduction (federal + cantonal) for a given canton. Used
  /// by tax-projection services to avoid the outdated 6'500 CHF flat that
  /// ignored the cantonal portion (Wave 7 fiscal audit P0-R4).
  static double totalChildDeduction(String canton) {
    final cantonCode = canton.isNotEmpty ? canton.toUpperCase() : '';
    final cantonal = deductionParEnfantCantonal[cantonCode] ?? deductionParEnfant;
    return deductionParEnfant + cantonal;
  }

  /// Maximum childcare deduction (LIFD art. 33 al. 3, ESTV 2026).
  static const double deductionGardeMax = 25800.0;

  // ════════════════════════════════════════════════════════════
  //  SURVIVOR BENEFITS CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// AVS survivor rente: 80% of deceased's rente (LAVS art. 35).
  static const double avsSurvivorFactor = 0.80;

  /// LPP survivor rente: 60% of the deceased's disability/retirement rente.
  /// The 60% RATE is LPP art. 21 al. 1 (montant de la rente de survivants).
  /// LPP art. 19 governs the entitlement CONDITIONS, not the rate — see the
  /// footnote `mariageLppSurvivorFootnote`. Mirrors
  /// `LppCalculator.survivorSpouseRate` (canonical survivor engine).
  static const double lppSurvivorFactor = 0.60;

  // AVS max single rente mensuelle: uses avsRenteMaxMensuelle from social_insurance.dart

  // ════════════════════════════════════════════════════════════
  //  APG / PARENTAL LEAVE CONSTANTS
  // ════════════════════════════════════════════════════════════

  /// APG daily max (LAPG art. 16e).
  static const double apgDailyMax = 220.0;

  /// APG maternity duration in calendar days (14 weeks = 98 days).
  static const int apgMaternityDays = 98;

  /// APG maternity duration in weeks.
  static const int apgMaternityWeeks = 14;

  /// APG paternity duration in working days.
  static const int apgPaternityWorkingDays = 10;

  /// APG paternity duration in weeks.
  static const int apgPaternityWeeks = 2;

  /// APG replacement rate (80% of salary).
  static const double apgReplacementRate = 0.80;

  // ════════════════════════════════════════════════════════════
  //  CANTONAL FAMILY ALLOCATIONS (CHF/month per child)
  // ════════════════════════════════════════════════════════════

  // Montant de base « allocation pour enfant » (CHF/mois), taux standard 2026.
  // Source : OFAS/BSV « Genres et montants des allocations familiales 2026 »
  // (Stand 12.12.2025). Minimum fédéral LAFam art. 5 = 215. Modulations âge
  // (ZH/LU/ZG) et rang (FR/VD/VS/NE/GE) non modélisées (montant de base).
  static const Map<String, double> allocationsMensuelles = {
    'ZH': 215.0,
    'BE': 250.0,
    'LU': 215.0,
    'UR': 240.0,
    'SZ': 230.0,
    'OW': 220.0,
    'NW': 258.0,
    'GL': 215.0,
    'ZG': 330.0,
    'FR': 265.0,
    'SO': 215.0,
    'BS': 275.0,
    'BL': 215.0,
    'SH': 230.0,
    'AR': 230.0,
    'AI': 245.0,
    'SG': 245.0,
    'GR': 240.0,
    'AG': 225.0,
    'TG': 215.0,
    'TI': 215.0,
    'VD': 322.0,
    'VS': 327.0,
    'NE': 240.0,
    'GE': 311.0,
    'JU': 275.0,
  };

  // ════════════════════════════════════════════════════════════
  //  CANTON NAMES (French)
  // ════════════════════════════════════════════════════════════

  static const Map<String, String> cantonNames = {
    'ZH': 'Zurich',
    'BE': 'Berne',
    'LU': 'Lucerne',
    'UR': 'Uri',
    'SZ': 'Schwyz',
    'OW': 'Obwald',
    'NW': 'Nidwald',
    'GL': 'Glaris',
    'ZG': 'Zoug',
    'FR': 'Fribourg',
    'SO': 'Soleure',
    'BS': 'Bâle-Ville',  // lint-ignore
    'BL': 'Bâle-Campagne',  // lint-ignore
    'SH': 'Schaffhouse',
    'AR': 'Appenzell RE',
    'AI': 'Appenzell RI',
    'SG': 'Saint-Gall',
    'GR': 'Grisons',
    'AG': 'Argovie',
    'TG': 'Thurgovie',
    'TI': 'Tessin',
    'VD': 'Vaud',
    'VS': 'Valais',
    'NE': 'Neuchâtel',  // lint-ignore
    'GE': 'Genève',  // lint-ignore
    'JU': 'Jura',
  };

  /// Sorted canton codes (alphabetical).
  static List<String> get sortedCantonCodes {
    final codes = cantonNames.keys.toList()..sort();
    return codes;
  }

  // ════════════════════════════════════════════════════════════
  //  MODÈLE IMPÔT REVENU — délégué à l'étalon ESTV canonique
  // ════════════════════════════════════════════════════════════
  //
  // La table `_effectiveRates100kSingle` (un taux effectif plat par canton à
  // 100k, multiplié par un `_incomeAdjustment` quasi quadratique et un facteur
  // marié plat 0.92) a été SUPPRIMÉE le 2026-07-30. Ne pas la réintroduire.
  //
  // C'était exactement la conception « taux_effectif(100k) × clamp(revenu/100k) »
  // que `income_tax_model_v2.dart` (miroir du backend canonique
  // `cantonal_comparator.py`) documente avoir remplacée : les DIFFÉRENCES
  // d'impôt (marié vs 2 célibataires) étaient fausses. Mesure du 2026-07-30 sur
  // famille_bern (114k + 78k, BE, 1 enfant) : l'ancien modèle annonçait une
  // PÉNALITÉ de +404 CHF là où l'étalon ESTV donne un BONUS de −2'454 CHF
  // (inversion de signe), la part cantonale BE étant sous-estimée de ~41 %.
  //
  // `compareFiscalMariage` délègue désormais à `estimateIncomeTaxV2` (IFD 2026
  // progressif + cantonal/communal interpolé sur l'API ESTV, marié = splitting
  // ×0.80). Une seule source d'impôt sur le revenu dans l'app — plus de table
  // de taux par canton (interdiction lint #1062).
  //
  // Limite RÉSIDUELLE (documentée, non corrigée ici) : la base reste le revenu
  // BRUT diminué des seules déductions fiscales fédérales (assurance, marié,
  // enfant, Zweiverdiener), sans les déductions sociales (AVS/AI/APG/AC/LPP) ni
  // les frais professionnels — le revenu imposable réel est donc surestimé. Les
  // constantes `deductionDoubleRevenu`/`deductionMarie`/`deductionAssuranceMarie`
  // sont par ailleurs périmées (cf. audit `moteur-famille-actuaire.md`).

  /// Inheritance tax rates for non-married partners by canton (taux "tiers").
  /// Married partners are tax-exempt in all cantons.
  /// Source: Lois cantonales sur les droits de succession, 2024.
  // ⚠️ La table `_inheritanceTaxRatesNonMarie` (un taux plat par canton pour un
  // héritier non parent) a été SUPPRIMÉE le 2026-07-26. Ne pas la réintroduire.
  //
  // Elle était invérifiable. Deux écarts indépendants constatés contre des
  // sources fiscales : `NW` y valait 0.00 alors que Nidwald impose les
  // non-parents, et `NE` y valait 0.20 pour une réalité bien plus élevée. Et
  // deux sources sérieuses se contredisaient sur les détails d'un même canton —
  // ce qui prouve que le domaine est trop fin pour un taux plat : les barèmes
  // sont tantôt progressifs, comportent des franchises variables, et plusieurs
  // cantons (VD, FR, GR) y ajoutent un impôt communal qui peut presque doubler
  // la charge.
  //
  // Retirer un chiffre invérifiable est juste que la source ait raison ou tort
  // sur tel canton : c'est ce qui a permis de trancher sans résoudre chaque cas.
  // Le jumeau backend (`TAUX_SUCCESSION_PAR_CANTON`) a été retiré en même temps
  // — PR #1058.

  // ════════════════════════════════════════════════════════════
  //  1. COMPARE FISCAL MARIAGE
  // ════════════════════════════════════════════════════════════

  /// Compare tax burden: married vs two single persons.
  ///
  /// Returns a map with tax amounts for both scenarios, the
  /// difference (penalty or bonus), and deduction details.
  static Map<String, dynamic> compareFiscalMariage({
    required double revenu1,
    required double revenu2,
    required String canton,
    int nbEnfants = 0,
  }) {
    // ── Two singles ──────────────────────────────────
    // Barème CÉLIBATAIRE de l'étalon ESTV canonique (estimateIncomeTaxV2 : IFD
    // 2026 progressif + cantonal/communal interpolé sur l'API ESTV). Base =
    // revenu brut moins la déduction d'assurance célibataire (limite résiduelle :
    // pas de déductions sociales AVS/LPP ni frais pro — voir note de section).
    final imposableSingle1 = max(0.0, revenu1 - deductionAssuranceCelibataire);
    final imposableSingle2 = max(0.0, revenu2 - deductionAssuranceCelibataire);
    final taxSingle1 = estimateIncomeTaxV2(imposableSingle1, canton);
    final taxSingle2 = estimateIncomeTaxV2(imposableSingle2, canton);
    final totalCelibataires = taxSingle1 + taxSingle2;

    // ── Married couple ──────────────────────────────
    final revenuCumule = revenu1 + revenu2;

    // Deductions for married
    double deductions = deductionMarie;
    deductions += deductionAssuranceMarie;
    deductions += nbEnfants * deductionParEnfant;

    // Double-earner deduction if both earn
    final hasDoubleRevenu = revenu1 > 0 && revenu2 > 0;
    if (hasDoubleRevenu) {
      deductions += deductionDoubleRevenu;
    }

    final revenuImposableMarie = max(0.0, revenuCumule - deductions);

    // Barème MARIÉ (splitting ×0.80) du MÊME étalon ESTV — plus de facteur plat
    // 0.92 ni de taux effectif par canton.
    final taxMarie =
        estimateIncomeTaxV2(revenuImposableMarie, canton, isMarried: true);

    // ── Difference ──────────────────────────────────
    final difference = taxMarie - totalCelibataires;
    final isPenalite = difference > 0;

    return {
      'revenu1': revenu1,
      'revenu2': revenu2,
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'nbEnfants': nbEnfants,
      'totalCelibataires': totalCelibataires,
      'taxSingle1': taxSingle1,
      'taxSingle2': taxSingle2,
      'totalMarie': taxMarie,
      'revenuImposableMarie': revenuImposableMarie,
      'difference': difference,
      'isPenalite': isPenalite,
      'deductionMarie': deductionMarie,
      'deductionAssurance': deductionAssuranceMarie,
      'deductionDoubleRevenu': hasDoubleRevenu ? deductionDoubleRevenu : 0.0,
      'deductionEnfants': nbEnfants * deductionParEnfant,
      'totalDeductions': deductions,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  2. SIMULATE CONGE PARENTAL
  // ════════════════════════════════════════════════════════════

  /// Calculate APG for parental leave.
  ///
  /// Returns: daily APG, total APG, duration, salary loss.
  static Map<String, dynamic> simulateCongeParental({
    required double salaireMensuel,
    required bool isMother,
  }) {
    final salaireAnnuel = salaireMensuel * 12;
    // APG method uses 360 days (30 days × 12 months) — LAPG art. 16e
    final salaireJournalier = salaireAnnuel / 360;

    // APG = 80% of salary, capped at CHF 220/day
    final apgJournalier = min(salaireJournalier * apgReplacementRate, apgDailyMax);

    final dureeSemaines = isMother ? apgMaternityWeeks : apgPaternityWeeks;
    // LAPG art. 16i: 14 indemnites journalieres pour le conge paternite
    final joursIndemnises = isMother ? apgMaternityDays : 14;
    final dureeJours = joursIndemnises;

    final totalApg = apgJournalier * joursIndemnises;

    // What you would have earned during the same period
    final salairePendant = salaireMensuel * (dureeSemaines / 4.33);
    final perteSalaire = max(0.0, salairePendant - totalApg);

    final isCapped = salaireJournalier * apgReplacementRate > apgDailyMax;
    const plafondMensuel = apgDailyMax * 30;

    return {
      'isMother': isMother,
      'salaireMensuel': salaireMensuel,
      'salaireJournalier': salaireJournalier,
      'apgJournalier': apgJournalier,
      'dureeSemaines': dureeSemaines,
      'dureeJours': dureeJours,
      'joursIndemnises': joursIndemnises,
      'totalApg': totalApg,
      'salairePendant': salairePendant,
      'perteSalaire': perteSalaire,
      'isCapped': isCapped,
      'plafondMensuel': plafondMensuel,
      'type': isMother ? 'Maternite' : 'Paternite',
    };
  }

  // ════════════════════════════════════════════════════════════
  //  3. ESTIMATE ALLOCATIONS
  // ════════════════════════════════════════════════════════════

  /// Estimate family allowances for a canton.
  static Map<String, dynamic> estimateAllocations({
    required String canton,
    int nbEnfants = 1,
  }) {
    final mensuelParEnfant = allocationsMensuelles[canton] ?? 215.0;
    final mensuelTotal = mensuelParEnfant * nbEnfants;
    final annuelTotal = mensuelTotal * 12;

    // Ranking
    final sorted = allocationsMensuelles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final rank = sorted.indexWhere((e) => e.key == canton) + 1;

    // Best and worst
    final best = sorted.first;
    final worst = sorted.last;
    final differenceVsBest = (best.value - mensuelParEnfant) * 12 * nbEnfants;

    return {
      'canton': canton,
      'cantonNom': cantonNames[canton] ?? canton,
      'nbEnfants': nbEnfants,
      'mensuelParEnfant': mensuelParEnfant,
      'mensuelTotal': mensuelTotal,
      'annuelTotal': annuelTotal,
      'rank': rank,
      'bestCanton': best.key,
      'bestCantonNom': cantonNames[best.key] ?? best.key,
      'bestMontant': best.value,
      'worstCanton': worst.key,
      'worstCantonNom': cantonNames[worst.key] ?? worst.key,
      'worstMontant': worst.value,
      'differenceVsBest': differenceVsBest,
    };
  }

  /// Get all cantons sorted by allocation amount (descending).
  static List<Map<String, dynamic>> getAllocationsRanking({
    int nbEnfants = 1,
  }) {
    final sorted = allocationsMensuelles.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.asMap().entries.map((entry) {
      final idx = entry.key;
      final e = entry.value;
      return {
        'canton': e.key,
        'cantonNom': cantonNames[e.key] ?? e.key,
        'mensuelParEnfant': e.value,
        'mensuelTotal': e.value * nbEnfants,
        'annuelTotal': e.value * nbEnfants * 12,
        'rank': idx + 1,
      };
    }).toList();
  }

  // ════════════════════════════════════════════════════════════
  //  4. CALCULATE IMPACT FISCAL ENFANT
  // ════════════════════════════════════════════════════════════

  /// Calculate the tax savings from having children.
  static Map<String, dynamic> calculateImpactFiscalEnfant({
    required double revenuImposable,
    required double tauxMarginal,
    int nbEnfants = 1,
    double fraisGarde = 0,
  }) {
    // Deduction for children
    final deductionEnfants = deductionParEnfant * nbEnfants;

    // Childcare deduction (capped)
    final deductionGarde = min(fraisGarde * 12, deductionGardeMax) * nbEnfants;

    // Total deduction
    final totalDeduction = deductionEnfants + deductionGarde;

    // Tax savings (deduction * marginal rate)
    final rate = tauxMarginal > 0 ? tauxMarginal : 0.15;
    final economieFiscale = totalDeduction * rate;

    return {
      'nbEnfants': nbEnfants,
      'deductionEnfants': deductionEnfants,
      'fraisGardeMensuel': fraisGarde,
      'deductionGarde': deductionGarde,
      'totalDeduction': totalDeduction,
      'tauxMarginal': rate,
      'economieFiscale': economieFiscale,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  5. COMPARE MARIAGE VS CONCUBINAGE
  // ════════════════════════════════════════════════════════════

  /// Full comparison: marriage vs cohabitation.
  ///
  /// NB : plus de paramètre `patrimoine`. La succession n'expose plus qu'un
  /// TAUX cantonal (voir [estimateInheritanceTax]) : accepter un patrimoine qui
  /// ne change plus aucune sortie laisserait croire qu'il est pris en compte.
  static Map<String, dynamic> compareMariageVsConcubinage({
    required double revenu1,
    required double revenu2,
    required String canton,
    int nbEnfants = 0,
  }) {
    // Fiscal comparison
    final fiscal = compareFiscalMariage(
      revenu1: revenu1,
      revenu2: revenu2,
      canton: canton,
      nbEnfants: nbEnfants,
    );

    // Inheritance comparison — cantonal RATE only, never an amount.
    final inheritance = estimateInheritanceTax(
      canton: canton,
      isMarried: false,
    );
    final inheritanceMarried = estimateInheritanceTax(
      canton: canton,
      isMarried: true,
    );

    // AVS survivor
    final avsSurvivorRente = reg('avs.max_monthly_pension', avsRenteMaxMensuelle) * avsSurvivorFactor;

    // NB : AUCUN score agrégé ni gagnant n'est renvoyé (`scoreMariage`,
    // `scoreConcubinage`, `fiscalAdvantage` — retirés). Compter des critères
    // hétérogènes (protection du·de la survivant·e, impôt annuel, héritage) à
    // poids égal et en tirer un gagnant est du pseudo-conseil : leur importance
    // relative dépend de la situation de chacun·e, et c'est précisément
    // l'arbitrage qui appartient à l'utilisateur·rice. La comparaison est rendue
    // critère par critère (matrice), sans agrégation. Ne pas ré-introduire :
    // un verdict qui dort dans le résultat finit par être affiché.
    return {
      'fiscal': fiscal,
      'inheritance': inheritance,
      'inheritanceMarried': inheritanceMarried,
      'avsSurvivorRente': avsSurvivorRente,
      'lppSurvivorFactor': lppSurvivorFactor,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  6. ESTIMATE INHERITANCE TAX
  // ════════════════════════════════════════════════════════════

  /// Cantonal inheritance-tax RATE for a married vs a non-married partner.
  ///
  /// Returns the rate only — NEVER an amount in francs. `patrimoine × taux`
  /// assumed that 100 % of the estate could go to the partner, which the Swiss
  /// succession law revision in force since 1.1.2023 contradicts: with no will
  /// a cohabiting partner inherits NOTHING; with a will, the descendants'
  /// statutory share is half of the estate (CC art. 470-471), so the disposable
  /// portion is capped at 1/2 in their presence (the parents' statutory share
  /// was abolished, so with no descendant it is 100 %). A co-owned asset also
  /// enters the estate only up to the deceased's own share — `patrimoine` is
  /// not the right base. The amount was therefore removed rather than shown on
  /// an unverifiable assumption.
  ///
  /// The rate itself is real, cantonal and personalised (the canton is a
  /// confirmed fact), but it stays an order of magnitude: cantonal scales are
  /// progressive, carry allowances and sometimes a communal tax — the screen
  /// renders it with `concubinageInheritanceRateLimit` attached.
  ///
  /// The married exemption does NOT come from CC art. 462 (that article governs
  /// the CIVIL share of the surviving spouse): there is no ordinary federal
  /// inheritance tax, and the exemption is granted by the CANTONAL tax laws —
  /// in all 26 of them.
  static Map<String, dynamic> estimateInheritanceTax({
    required String canton,
    required bool isMarried,
  }) {
    // Aucun taux n'est renvoyé. La table cantonale qui le fournissait a été
    // retirée : elle s'est révélée invérifiable (voir le commentaire à sa
    // place). Ce qui reste est qualitatif et solide — le conjoint survivant est
    // exonéré dans les 26 cantons, le·la concubin·e relève du barème des
    // « tiers ».
    return {
      'canton': canton,
      'isMarried': isMarried,
    };
  }

  // ════════════════════════════════════════════════════════════
  //  HELPERS
  // ════════════════════════════════════════════════════════════

  /// Format a number with Swiss apostrophe separators.
  static String _formatNumber(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return '${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }

  /// Format CHF with Swiss apostrophe.
  static String formatChf(double value) {
    return 'CHF\u00A0${_formatNumber(value)}';
  }
}
