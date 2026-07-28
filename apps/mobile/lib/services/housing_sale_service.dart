import 'dart:math';

// ────────────────────────────────────────────────────────────
//  HOUSING SALE SERVICE — Sprint S24
//  Calcul de l'impot sur les gains immobiliers.
//
//  L'impot sur les gains immobiliers est delegue au modele calibre ci-dessous
//  (miroir de services/backend/app/services/fiscal/gains_immobiliers_calibres.py,
//  ADR 2026-07-28 P5). ZH / VD / GE sont chiffres depuis des sources primaires ;
//  les autres cantons ne portent AUCUN chiffre fabrique (verdict mecanisme /
//  inconnu + renvoi au calculateur cantonal).
// ────────────────────────────────────────────────────────────

// ══════════════════════════════════════════════════════════════
//  Modele calibre des gains immobiliers (ZH / VD / GE)
//  Chiffres retranscrits de l'archive de sources primaires ; ne rien
//  modifier sans mettre a jour l'archive et les tests de parite.
// ══════════════════════════════════════════════════════════════

/// Franchise ZH : les gains inferieurs a ce seuil ne sont pas imposes.
const double kFranchiseZh = 5000.0;

/// Tranches progressives ZH par portion de gain : (portion_chf | null, taux).
/// La derniere portion (null) couvre la part au-dela de 100'000 CHF.
const List<(double?, double)> kTranchesZh = [
  (4000.0, 0.10),
  (6000.0, 0.15),
  (8000.0, 0.20),
  (12000.0, 0.25),
  (20000.0, 0.30),
  (50000.0, 0.35),
  (null, 0.40),
];

/// Majoration ZH de courte duree (appliquee a l'impot déjà calcule).
const double kMajorationZhMoins1An = 0.50; // < 1 an : x 1.5
const double kMajorationZhMoins2Ans = 0.25; // < 2 ans : x 1.25

/// Rabais ZH de longue duree par annees pleines (plafonne a 50 % des 20 ans).
const Map<int, double> kRabaisZhTable = {
  5: 0.05, 6: 0.08, 7: 0.11, 8: 0.14, 9: 0.17,
  10: 0.20, 11: 0.23, 12: 0.26, 13: 0.29, 14: 0.32,
  15: 0.35, 16: 0.38, 17: 0.41, 18: 0.44, 19: 0.47,
  20: 0.50,
};
const double kRabaisZhPlafond = 0.50;

/// Bareme VD par duree de possession : (de_inclus, a_exclu | null, taux).
const List<(int, int?, double)> kBaremeVd = [
  (0, 1, 0.30), (1, 2, 0.27), (2, 3, 0.24), (3, 4, 0.22), (4, 5, 0.20),
  (5, 6, 0.18), (6, 7, 0.17), (7, 8, 0.16), (8, 9, 0.15), (9, 10, 0.15),
  (10, 11, 0.14), (11, 12, 0.14), (12, 13, 0.13), (13, 14, 0.13),
  (14, 15, 0.12), (15, 16, 0.12), (16, 17, 0.11), (17, 18, 0.11),
  (18, 19, 0.10), (19, 20, 0.10), (20, 21, 0.09), (21, 22, 0.09),
  (22, 23, 0.08), (23, 24, 0.08), (24, null, 0.07),
];

/// Bareme GE par duree de possession : (de_inclus, a_exclu | null, taux).
/// 2 % des 25 ans depuis la revision du 1.1.2025.
const List<(int, int?, double)> kBaremeGe = [
  (0, 2, 0.50),
  (2, 4, 0.40),
  (4, 6, 0.30),
  (6, 8, 0.20),
  (8, 10, 0.15),
  (10, 25, 0.10),
  (25, null, 0.02),
];

const String kSourceZh =
    'Tarif fur die Grundstuckgewinnsteuer, § 225 StG — Steueramt Kanton Zurich, ZStB Nr. 225-1.'; // lint-ignore
const String kSourceVd =
    'Loi sur les impots directs cantonaux (LI), RSV 642.11, art. 72 — Etat de Vaud (lexfind.ch).'; // lint-ignore
const String kSourceGe =
    'Loi generale sur les contributions publiques (LCP), rsGE D 3 05, art. 84 — Geneve, etat 1.1.2026.'; // lint-ignore
const String kSourceMecanisme =
    'Impot cantonal sur les gains immobiliers (LHID art. 12) — tarif non tabulable ici.'; // lint-ignore
const String kSourceInconnu =
    'Impot cantonal sur les gains immobiliers (LHID art. 12) — bareme non calibre sur source primaire.'; // lint-ignore

/// Cantons a mecanisme : impot reel, tarif non tabulable, renvoi a
/// l'administration fiscale cantonale (nom officiel, sans URL, sans chiffre).
const Map<String, String> kMecanismeCantons = {
  'BE': "l'administration fiscale du canton de Berne (Steuerverwaltung des Kantons Bern)", // lint-ignore
  'LU': "l'administration fiscale du canton de Lucerne (Dienststelle Steuern des Kantons Luzern)", // lint-ignore
  'BS': "l'administration fiscale du canton de Bale-Ville (Steuerverwaltung Basel-Stadt)", // lint-ignore
};

double _round2(double v) => (v * 100).roundToDouble() / 100;

/// Verdict d'impot sur les gains immobiliers (calibre / mecanisme / inconnu).
class GainImmobilierVerdict {
  final String canton;
  final String modele; // 'calibre' | 'mecanisme' | 'inconnu'
  final double? impotChf;
  final double? tauxEffectifPct;
  final List<String> mecanismes;
  final String source;

  const GainImmobilierVerdict({
    required this.canton,
    required this.modele,
    required this.impotChf,
    required this.tauxEffectifPct,
    required this.mecanismes,
    required this.source,
  });
}

/// Tarif de base ZH (Grundtarif) : somme progressive des tranches, sans
/// franchise ni majoration/rabais. C'est ce que rejouent les vecteurs officiels.
double impotBaseZh(double gainChf) {
  if (gainChf <= 0) return 0.0;
  double reste = gainChf;
  double impot = 0.0;
  for (final tranche in kTranchesZh) {
    if (reste <= 0) break;
    final portion = tranche.$1;
    final taux = tranche.$2;
    if (portion == null) {
      impot += reste * taux;
      reste = 0.0;
    } else {
      final part = min(reste, portion);
      impot += part * taux;
      reste -= part;
    }
  }
  return _round2(impot);
}

double _rabaisZh(int anneesPleines) {
  if (anneesPleines >= 20) return kRabaisZhPlafond;
  return kRabaisZhTable[anneesPleines] ?? 0.0;
}

/// Impot ZH complet : franchise, tarif progressif, majoration de courte duree,
/// puis rabais de longue duree (appliques a l'impot déjà calcule).
double impotZh(double gainChf, int anneesPleines) {
  if (gainChf < kFranchiseZh) return 0.0;
  double impot = impotBaseZh(gainChf);
  if (anneesPleines < 1) {
    impot *= 1.0 + kMajorationZhMoins1An;
  } else if (anneesPleines < 2) {
    impot *= 1.0 + kMajorationZhMoins2Ans;
  }
  final rabais = _rabaisZh(anneesPleines);
  if (rabais > 0) {
    impot *= 1.0 - rabais;
  }
  return _round2(impot);
}

/// Duree effective VD (art. 72 al. 4) : occupation personnelle prouvee comptee
/// double, plafonnee a la duree de possession reelle.
int dureeEffectiveVd(int anneesPossession, [int anneesOccupation = 0]) {
  final poss = max(anneesPossession, 0);
  final occCreditee = min(max(anneesOccupation, 0), poss);
  return poss + occCreditee;
}

double tauxVd(int dureeEffective) {
  final d = max(dureeEffective, 0);
  for (final ligne in kBaremeVd) {
    final de = ligne.$1;
    final aExclu = ligne.$2;
    final taux = ligne.$3;
    if (d >= de && (aExclu == null || d < aExclu)) return taux;
  }
  return kBaremeVd.last.$3;
}

double tauxGe(int annees) {
  final d = max(annees, 0);
  for (final ligne in kBaremeGe) {
    final de = ligne.$1;
    final aExclu = ligne.$2;
    final taux = ligne.$3;
    if (d >= de && (aExclu == null || d < aExclu)) return taux;
  }
  return kBaremeGe.last.$3;
}

String _mecanismeMessage(String administration) {
  return "L'impot sur les gains immobiliers existe dans ce canton, mais son tarif " // lint-ignore
      'depend de quotites communales et de baremes lies au revenu qui ne se ' // lint-ignore
      'tabulent pas de facon fiable ici. Pour un montant chiffre, adresse-toi ' // lint-ignore
      'au calculateur officiel de $administration.'; // lint-ignore
}

String _inconnuMessage() {
  return "Le bareme de l'impot sur les gains immobiliers de ce canton n'a pas " // lint-ignore
      'encore ete calibre sur une source primaire. Aucun montant n\'est estime ' // lint-ignore
      'ici : renseigne-toi aupres de l\'administration fiscale de ton canton.'; // lint-ignore
}

/// Dispatcher verdict : ZH / VD / GE calibres, BE / LU / BS mecanisme, reste
/// inconnu. JAMAIS de montant chiffre hors ZH / VD / GE.
GainImmobilierVerdict verdictGainImmobilier(
  String canton,
  double gainChf,
  int anneesPossession, [
  int anneesOccupation = 0,
]) {
  final c = canton.toUpperCase();
  final gain = max(gainChf, 0.0);

  if (c == 'ZH') {
    final impot = impotZh(gain, anneesPossession);
    final mecanismes = <String>["franchise 5'000 CHF"]; // lint-ignore
    if (anneesPossession < 1) {
      mecanismes.add('majoration de courte duree (< 1 an, +50 %)'); // lint-ignore
    } else if (anneesPossession < 2) {
      mecanismes.add('majoration de courte duree (< 2 ans, +25 %)'); // lint-ignore
    }
    if (_rabaisZh(anneesPossession) > 0) {
      mecanismes.add(
          'rabais de longue duree (${(_rabaisZh(anneesPossession) * 100).round()} %)'); // lint-ignore
    }
    mecanismes.add('tarif progressif par montant de gain'); // lint-ignore
    return GainImmobilierVerdict(
      canton: c,
      modele: 'calibre',
      impotChf: impot,
      tauxEffectifPct: gain > 0 ? _round2(impot / gain * 100) : 0.0,
      mecanismes: mecanismes,
      source: kSourceZh,
    );
  }

  if (c == 'VD') {
    final duree = dureeEffectiveVd(anneesPossession, anneesOccupation);
    final taux = tauxVd(duree);
    final mecanismes = <String>['bareme degressif par duree de possession']; // lint-ignore
    if (anneesOccupation > 0) {
      mecanismes.add(
          'double comptage des annees d\'occupation (art. 72 al. 4) : duree effective $duree ans'); // lint-ignore
    }
    return GainImmobilierVerdict(
      canton: c,
      modele: 'calibre',
      impotChf: _round2(gain * taux),
      tauxEffectifPct: _round2(taux * 100),
      mecanismes: mecanismes,
      source: kSourceVd,
    );
  }

  if (c == 'GE') {
    final taux = tauxGe(anneesPossession);
    return GainImmobilierVerdict(
      canton: c,
      modele: 'calibre',
      impotChf: _round2(gain * taux),
      tauxEffectifPct: _round2(taux * 100),
      mecanismes: const ['bareme degressif par duree de possession'], // lint-ignore
      source: kSourceGe,
    );
  }

  final administration = kMecanismeCantons[c];
  if (administration != null) {
    return GainImmobilierVerdict(
      canton: c,
      modele: 'mecanisme',
      impotChf: null,
      tauxEffectifPct: null,
      mecanismes: [_mecanismeMessage(administration)],
      source: kSourceMecanisme,
    );
  }

  return GainImmobilierVerdict(
    canton: c,
    modele: 'inconnu',
    impotChf: null,
    tauxEffectifPct: null,
    mecanismes: [_inconnuMessage()],
    source: kSourceInconnu,
  );
}

/// Result model for housing sale calculation.
///
/// Pour un canton non calibre (hors ZH / VD / GE), l'impot sur les gains
/// immobiliers n'est pas chiffre : [tauxImpositionPlusValue], [impotPlusValue],
/// [remploiReport], [impotEffectif] et [produitNet] valent alors `null`, et
/// [gainImmobilier] porte le mecanisme + le renvoi au calculateur cantonal.
class HousingSaleResult {
  final double plusValueBrute;
  final double plusValueImposable;
  final int dureeDetention;
  final String modeleGain; // 'calibre' | 'mecanisme' | 'inconnu'
  final double? tauxImpositionPlusValue;
  final double? impotPlusValue;
  final double? remploiReport;
  final double? impotEffectif;
  final double remboursementEplLpp;
  final double remboursementEpl3a;
  final double soldeHypotheque;
  final double? produitNet;
  final GainImmobilierVerdict gainImmobilier;
  final List<String> checklist;
  final List<String> alerts;
  final String disclaimer;
  final List<String> sources;
  final String premierEclairage;

  const HousingSaleResult({
    required this.plusValueBrute,
    required this.plusValueImposable,
    required this.dureeDetention,
    required this.modeleGain,
    required this.tauxImpositionPlusValue,
    required this.impotPlusValue,
    required this.remploiReport,
    required this.impotEffectif,
    required this.remboursementEplLpp,
    required this.remboursementEpl3a,
    required this.soldeHypotheque,
    required this.produitNet,
    required this.gainImmobilier,
    required this.checklist,
    required this.alerts,
    required this.disclaimer,
    required this.sources,
    required this.premierEclairage,
  });
}

/// Service for calculating the financial impact of selling a property in Switzerland.
///
/// Covers capital gains tax (impot sur les gains immobiliers, delegue au modele
/// calibre), EPL repayment obligations (LPP art. 30d, OPP2), and remploi
/// (report d'imposition sur l'impot).
class HousingSaleService {
  /// Calculate capital gains tax on property sale.
  ///
  /// Mirrors the backend logic (fiscal.gains_immobiliers_calibres) for the
  /// gains-tax model. Remploi defers the TAX (proportional to reinvestment).
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
    int anneesOccupation = 0,
  }) {
    // ── Duration of ownership ──
    final dureeDetention = anneeVente - anneeAchat;

    // ── Capital gain (plus-value), after value-adding deductions ──
    final coutAcquisitionTotal =
        prixAchat + investissementsValorisants + fraisAcquisition;
    final plusValueBrute = prixVente - coutAcquisitionTotal;
    final gainImposable = max(0.0, plusValueBrute);

    // ── Capital gains tax — delegated to the calibrated canton model ──
    final verdict = verdictGainImmobilier(
      canton,
      gainImposable,
      dureeDetention,
      anneesOccupation,
    );
    final impotChf = verdict.impotChf;

    double? tauxImposition;
    double? impotPlusValue;
    double? remploiReport;
    double? impotEffectif;
    double? produitNet;

    if (impotChf == null) {
      // Canton non calibre : aucun impot fabrique.
      tauxImposition = null;
      impotPlusValue = null;
      remploiReport = null;
      impotEffectif = null;
      produitNet = null;
    } else {
      impotPlusValue = impotChf;
      tauxImposition =
          gainImposable > 0 ? _round4(impotChf / gainImposable) : 0.0;

      // Remploi (report d'imposition) sur l'impot, LHID art. 12 al. 3.
      double report = 0;
      if (projetRemploi && residencePrincipale && prixRemploi > 0 && impotChf > 0) {
        if (prixRemploi >= prixVente) {
          report = impotChf;
        } else {
          report = _round2(impotChf * (prixRemploi / prixVente));
        }
      }
      remploiReport = report;
      impotEffectif = _round2(impotChf - report);

      final remboursementLpp = residencePrincipale ? eplLppUtilise : 0.0;
      final remboursement3a = residencePrincipale ? epl3aUtilise : 0.0;
      produitNet = prixVente -
          hypothequeRestante -
          impotEffectif -
          remboursementLpp -
          remboursement3a;
    }

    // ── EPL repayment obligations (LPP art. 30d, OPP2 art. 30e) ──
    final remboursementEplLpp = residencePrincipale ? eplLppUtilise : 0.0;
    final remboursementEpl3a = residencePrincipale ? epl3aUtilise : 0.0;

    // ── Solde hypotheque ──
    final soldeHypotheque = hypothequeRestante;

    // ── Alerts ──
    final alerts = <String>[];

    // Canton non calibre : dire honnetement qu'aucun impot n'est chiffre.
    if (impotChf == null && verdict.mecanismes.isNotEmpty) {
      alerts.add(verdict.mecanismes.first);
    }

    if (plusValueBrute < 0) {
      alerts.add(
        'Attention : la vente se fait à perte ' // lint-ignore
        '(moins-value de CHF ${plusValueBrute.abs().round()}). ' // lint-ignore
        'Aucun impôt sur les gains immobiliers ne sera dû.', // lint-ignore
      );
    }

    if (dureeDetention < 2) {
      alerts.add(
        'Vente spéculative : la détention est inférieure à 2 ans. ' // lint-ignore
        'Le taux d\'imposition est au maximum. ' // lint-ignore
        'Envisage de reporter la vente si possible.', // lint-ignore
      );
    }

    if (remboursementEplLpp > 0 || remboursementEpl3a > 0) {
      alerts.add(
        'Obligation de remboursement EPL : le remboursement est requis pour ' // lint-ignore
        'les fonds de prévoyance utilisés pour l\'achat ' // lint-ignore
        '(LPP art. 30d, OPP2 art. 30e).', // lint-ignore
      );
    }

    if (projetRemploi && !residencePrincipale) {
      alerts.add(
        'Le report d\'imposition (remploi) n\'est possible que ' // lint-ignore
        'pour la résidence principale. Vérifie ta situation.', // lint-ignore
      );
    }

    if (produitNet != null && produitNet < 0) {
      alerts.add(
        'Attention : le produit net est négatif. La vente ne couvre ' // lint-ignore
        'pas l\'ensemble des charges (hypothèque, impôts, EPL). ' // lint-ignore
        'Consulte un·e spécialiste avant de procéder.', // lint-ignore
      );
    }

    if (hypothequeRestante > prixVente * 0.8) {
      alerts.add(
        'Le solde hypothécaire dépasse 80% du prix de vente. ' // lint-ignore
        'Vérifie les conditions de remboursement anticipé ' // lint-ignore
        'avec ta banque (pénalité de sortie possible).', // lint-ignore
      );
    }

    // ── Checklist ──
    final checklist = <String>[
      'Demander une estimation immobilière professionnelle', // lint-ignore
      'Vérifier le délai de détention pour le taux d\'imposition', // lint-ignore
      'Contacter ta caisse de pension pour les modalités EPL', // lint-ignore
      'Vérifier les conditions de remboursement hypothécaire', // lint-ignore
      'Consulter un notaire pour la transaction', // lint-ignore
    ];

    if (projetRemploi) {
      checklist.add(
        'Préparer le dossier de remploi auprès de l\'administration fiscale', // lint-ignore
      );
    }

    if (eplLppUtilise > 0) {
      checklist.add(
        'Planifier le remboursement EPL LPP (CHF ${eplLppUtilise.round()})', // lint-ignore
      );
    }

    if (epl3aUtilise > 0) {
      checklist.add(
        'Planifier le remboursement EPL 3a (CHF ${epl3aUtilise.round()})', // lint-ignore
      );
    }

    checklist.add(
      'Declarer le gain immobilier dans ta prochaine declaration fiscale', // lint-ignore
    );

    // ── Chiffre choc ──
    final String premierEclairage;
    if (produitNet == null) {
      premierEclairage = verdict.mecanismes.isNotEmpty
          ? verdict.mecanismes.first
          : 'Impot sur le gain a estimer aupres de l\'administration cantonale.'; // lint-ignore
    } else if (produitNet >= 0) {
      premierEclairage =
          'Produit net de ta vente : CHF ${produitNet.round()}'; // lint-ignore
    } else {
      premierEclairage =
          'Attention : produit net negatif de CHF ${produitNet.abs().round()}'; // lint-ignore
    }

    // ── Disclaimer ──
    const disclaimer =
        'Cet outil educatif fournit des estimations indicatives et ' // lint-ignore
        'ne constitue pas un conseil fiscal, juridique ou immobilier ' // lint-ignore
        'personnalise au sens de la LSFin. Les taux d\'imposition ' // lint-ignore
        'sur les gains immobiliers varient selon la commune et les ' // lint-ignore
        'deductions applicables. ' // lint-ignore
        'Consulte un·e spécialiste pour ta situation personnelle.'; // lint-ignore

    // ── Sources ──
    final sources = <String>[
      'LHID art. 12 (Loi sur l\'harmonisation des impots directs)', // lint-ignore
      'LPP art. 30d (Remboursement EPL)', // lint-ignore
      'OPP2 art. 30e (Modalites EPL)', // lint-ignore
      'CC art. 712a ss (Propriete par etages)', // lint-ignore
      verdict.source,
    ];

    return HousingSaleResult(
      plusValueBrute: plusValueBrute,
      plusValueImposable: gainImposable,
      dureeDetention: dureeDetention,
      modeleGain: verdict.modele,
      tauxImpositionPlusValue: tauxImposition,
      impotPlusValue: impotPlusValue,
      remploiReport: remploiReport,
      impotEffectif: impotEffectif,
      remboursementEplLpp: remboursementEplLpp,
      remboursementEpl3a: remboursementEpl3a,
      soldeHypotheque: soldeHypotheque,
      produitNet: produitNet,
      gainImmobilier: verdict,
      checklist: checklist,
      alerts: alerts,
      disclaimer: disclaimer,
      sources: sources,
      premierEclairage: premierEclairage,
    );
  }
}

double _round4(double v) => (v * 10000).roundToDouble() / 10000;
