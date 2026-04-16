import 'dart:math';

// ────────────────────────────────────────────────────────────
//  HOUSING SALE SERVICE — Sprint S24
//  Calcul de l'impot sur les gains immobiliers (LHID art. 12)
// ────────────────────────────────────────────────────────────

/// Result model for housing sale calculation.
class HousingSaleResult {
  final double plusValueBrute;
  final double plusValueImposable;
  final int dureeDetention;
  final double tauxImpositionPlusValue;
  final double impotPlusValue;
  final double remploiReport;
  final double impotEffectif;
  final double remboursementEplLpp;
  final double remboursementEpl3a;
  final double soldeHypotheque;
  final double produitNet;
  final List<String> checklist;
  final List<String> alerts;
  final String disclaimer;
  final List<String> sources;
  final String premierEclairage;
  final bool cantonExplicit;

  const HousingSaleResult({
    required this.plusValueBrute,
    required this.plusValueImposable,
    required this.dureeDetention,
    required this.tauxImpositionPlusValue,
    required this.impotPlusValue,
    required this.remploiReport,
    required this.impotEffectif,
    required this.remboursementEplLpp,
    required this.remboursementEpl3a,
    required this.soldeHypotheque,
    required this.produitNet,
    required this.checklist,
    required this.alerts,
    required this.disclaimer,
    required this.sources,
    required this.premierEclairage,
    required this.cantonExplicit,
  });
}

/// Service for calculating the financial impact of selling a property in Switzerland.
///
/// Covers capital gains tax (impot sur les gains immobiliers), EPL repayment
/// obligations (LPP art. 30d, OPP2), and remploi (report d'imposition).
class HousingSaleService {
  // ── Capital gains tax rate schedules by canton ──
  // Format: (minYears, maxYears, rate)
  // Source: LHID art. 12, cantonal tax laws
  static const Map<String, List<(int, int, double)>>
      tauxPlusValueImmobiliere = {
    'ZH': [
      (0, 2, 0.50),
      (2, 5, 0.40),
      (5, 10, 0.30),
      (10, 15, 0.20),
      (15, 20, 0.15),
      (20, 999, 0.0),
    ],
    'BE': [
      (0, 1, 0.45),
      (1, 4, 0.35),
      (4, 10, 0.25),
      (10, 15, 0.18),
      (15, 25, 0.10),
      (25, 999, 0.0),
    ],
    'VD': [
      (0, 1, 0.30),
      (1, 5, 0.25),
      (5, 10, 0.20),
      (10, 25, 0.15),
      (25, 999, 0.07),
    ],
    'GE': [
      (0, 2, 0.50),
      (2, 4, 0.40),
      (4, 6, 0.30),
      (6, 8, 0.25),
      (8, 10, 0.20),
      (10, 25, 0.10),
      (25, 999, 0.0),
    ],
    'LU': [
      (0, 1, 0.36),
      (1, 2, 0.33),
      (2, 5, 0.27),
      (5, 10, 0.21),
      (10, 15, 0.15),
      (15, 20, 0.09),
      (20, 999, 0.0),
    ],
    'BS': [
      (0, 5, 0.32),
      (5, 10, 0.25),
      (10, 15, 0.20),
      (15, 20, 0.15),
      (20, 999, 0.10),
    ],
  };

  /// Calculate capital gains tax on property sale.
  ///
  /// Mirrors the backend logic exactly for consistency.
  static HousingSaleResult calculate({
    required double prixAchat,
    required double prixVente,
    required int anneeAchat,
    int anneeVente = 2025,
    double investissementsValorisants = 0,
    double fraisAcquisition = 0,
    required String canton,
    bool residencePrincipale = true,
    double eplLppUtilise = 0,
    double epl3aUtilise = 0,
    double hypothequeRestante = 0,
    bool projetRemploi = false,
    double prixRemploi = 0,
  }) {
    // ── Canton coverage check ──
    final cantonExplicit = tauxPlusValueImmobiliere.containsKey(canton);

    // ── Duration of ownership ──
    final dureeDetention = anneeVente - anneeAchat;

    // ── Capital gain (plus-value) ──
    // Deductible: purchase price + value-adding investments + acquisition costs
    final coutAcquisitionTotal =
        prixAchat + investissementsValorisants + fraisAcquisition;
    final plusValueBrute = prixVente - coutAcquisitionTotal;

    // ── Remploi (report d'imposition) ──
    // If replacing primary residence, deferred taxation on reinvested portion
    // LHID art. 12 al. 3
    double remploiReport = 0;
    double plusValueImposable = plusValueBrute;

    if (projetRemploi && residencePrincipale && prixRemploi > 0) {
      if (prixRemploi >= prixVente) {
        // Full remploi: entire gain is deferred
        remploiReport = plusValueBrute;
        plusValueImposable = 0;
      } else {
        // Partial remploi: proportional deferral
        final ratio = prixRemploi / prixVente;
        remploiReport = plusValueBrute * ratio;
        plusValueImposable = plusValueBrute - remploiReport;
      }
    }

    // No tax on losses
    plusValueImposable = max(0, plusValueImposable);

    // ── Tax rate lookup ──
    final tauxSchedule =
        tauxPlusValueImmobiliere[canton] ?? tauxPlusValueImmobiliere['VD']!;
    double tauxImposition = 0;
    for (final bracket in tauxSchedule) {
      if (dureeDetention >= bracket.$1 && dureeDetention < bracket.$2) {
        tauxImposition = bracket.$3;
        break;
      }
    }

    // ── Tax calculation ──
    final impotPlusValue = plusValueImposable * tauxImposition;
    final impotEffectif = impotPlusValue; // After remploi deduction

    // ── EPL repayment obligations ──
    // LPP art. 30d: EPL must be repaid upon sale of primary residence
    // OPP2 art. 30e: repayment to pension fund
    final remboursementEplLpp =
        residencePrincipale ? eplLppUtilise : 0.0;
    final remboursementEpl3a =
        residencePrincipale ? epl3aUtilise : 0.0;

    // ── Solde hypotheque ──
    final soldeHypotheque = hypothequeRestante;

    // ── Produit net ──
    final produitNet = prixVente -
        hypothequeRestante -
        impotEffectif -
        remboursementEplLpp -
        remboursementEpl3a;

    // ── Alerts ──
    final alerts = <String>[];

    if (plusValueBrute < 0) {
      alerts.add(
        'Attention : la vente se fait à perte '
        '(moins-value de CHF ${plusValueBrute.abs().round()}). '
        'Aucun impôt sur les gains immobiliers ne sera dû.',
      );
    }

    if (dureeDetention < 2) {
      alerts.add(
        'Vente spéculative : la détention est inférieure à 2 ans. '
        'Le taux d\'imposition est au maximum. '
        'Envisage de reporter la vente si possible.',
      );
    }

    if (remboursementEplLpp > 0 || remboursementEpl3a > 0) {
      alerts.add(
        'Obligation de remboursement EPL : le remboursement est requis pour '
        'les fonds de prévoyance utilisés pour l\'achat '
        '(LPP art. 30d, OPP2 art. 30e).',
      );
    }

    if (projetRemploi && !residencePrincipale) {
      alerts.add(
        'Le report d\'imposition (remploi) n\'est possible que '
        'pour la résidence principale. Vérifie ta situation.',
      );
    }

    if (produitNet < 0) {
      alerts.add(
        'Attention : le produit net est négatif. La vente ne couvre '
        'pas l\'ensemble des charges (hypothèque, impôts, EPL). '
        'Consulte un·e spécialiste avant de procéder.',
      );
    }

    if (hypothequeRestante > prixVente * 0.8) {
      alerts.add(
        'Le solde hypothécaire dépasse 80% du prix de vente. '
        'Vérifie les conditions de remboursement anticipé '
        'avec ta banque (pénalité de sortie possible).',
      );
    }

    if (!cantonExplicit) {
      alerts.add(
        'Ton canton ($canton) n\'a pas de bareme detaille dans notre base. '
        'Les taux de Vaud (VD) sont utilises par defaut. '
        'Consulte l\'administration fiscale de ton canton pour des chiffres precis.',
      );
    }

    // ── Checklist ──
    final checklist = <String>[
      'Demander une estimation immobilière professionnelle',
      'Vérifier le délai de détention pour le taux d\'imposition',
      'Contacter ta caisse de pension pour les modalités EPL',
      'Vérifier les conditions de remboursement hypothécaire',
      'Consulter un notaire pour la transaction',
    ];

    if (projetRemploi) {
      checklist.add(
        'Préparer le dossier de remploi auprès de l\'administration fiscale',
      );
    }

    if (eplLppUtilise > 0) {
      checklist.add(
        'Planifier le remboursement EPL LPP (CHF ${eplLppUtilise.round()})',
      );
    }

    if (epl3aUtilise > 0) {
      checklist.add(
        'Planifier le remboursement EPL 3a (CHF ${epl3aUtilise.round()})',
      );
    }

    checklist.add(
      'Declarer le gain immobilier dans ta prochaine declaration fiscale',
    );

    // ── Chiffre choc ──
    final premierEclairage = produitNet >= 0
        ? 'Produit net de ta vente : CHF ${produitNet.round()}'
        : 'Attention : produit net negatif de CHF ${produitNet.abs().round()}';

    // ── Disclaimer ──
    final disclaimer =
        'Cet outil educatif fournit des estimations indicatives et '
        'ne constitue pas un conseil fiscal, juridique ou immobilier '
        'personnalise au sens de la LSFin. Les taux d\'imposition '
        'sont simplifies et peuvent varier selon la commune et les '
        'deductions applicables. ${!cantonExplicit ? "Le bareme utilise est celui de VD par defaut. " : ""}'
        'Consulte un·e specialiste pour ta situation personnelle.';

    // ── Sources ──
    const sources = [
      'LHID art. 12 (Loi sur l\'harmonisation des impots directs)',
      'LPP art. 30d (Remboursement EPL)',
      'OPP2 art. 30e (Modalites EPL)',
      'CC art. 712a ss (Propriete par etages)',
      'Lois fiscales cantonales (ZH, BE, VD, GE, LU, BS)',
    ];

    return HousingSaleResult(
      plusValueBrute: plusValueBrute,
      plusValueImposable: plusValueImposable,
      dureeDetention: dureeDetention,
      tauxImpositionPlusValue: tauxImposition,
      impotPlusValue: impotPlusValue,
      remploiReport: remploiReport,
      impotEffectif: impotEffectif,
      remboursementEplLpp: remboursementEplLpp,
      remboursementEpl3a: remboursementEpl3a,
      soldeHypotheque: soldeHypotheque,
      produitNet: produitNet,
      checklist: checklist,
      alerts: alerts,
      disclaimer: disclaimer,
      sources: sources,
      premierEclairage: premierEclairage,
      cantonExplicit: cantonExplicit,
    );
  }
}
