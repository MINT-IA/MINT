import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/services/succession_donation_socle.dart';
import 'package:mint_mobile/utils/chf_formatter.dart' as chf;

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

  /// Canton de résidence RÉEL de l'utilisateur, utilisé pour le barème d'impôt
  /// (marié + individuel). Aucune valeur codée en dur : l'impôt du divorce d'un
  /// contribuable GE ne peut pas être présenté avec le barème d'un autre canton.
  /// La chaîne vide « » signifie « canton non confirmé » — l'écran bloque alors
  /// l'affichage du résultat (gate dur), la valeur ne sert qu'au calcul interne.
  final String canton;

  final double incomeConjoint1;
  final double incomeConjoint2;
  final double lppConjoint1;
  final double lppConjoint2;

  /// Avoir de prévoyance LPP de chaque conjoint AU MOMENT DU MARIAGE.
  ///
  /// CC art. 122 / LFLP art. 22a : le partage 50/50 ne porte que sur la
  /// prévoyance acquise PENDANT le mariage. La part constituée avant le
  /// mariage est exclue du partage. Sans cette donnée (null), le service
  /// renvoie un résultat marqué incomplet plutôt que de splitter l'avoir
  /// total.
  final double? avoirAuMariage1;
  final double? avoirAuMariage2;

  final double pillar3aConjoint1;
  final double pillar3aConjoint2;

  /// Repère INDICATIF sur le patrimoine du ménage. Ce n'est PAS une masse
  /// partageable et aucune part n'en est dérivée : la liquidation du régime
  /// exige les comptes de chaque époux séparément (voir la note au-dessus de
  /// [DivorceResult]). Seul le constat qualitatif sur le niveau d'endettement
  /// s'appuie dessus.
  final double fortuneCommune;

  /// Dettes du ménage, repère INDICATIF au même titre que [fortuneCommune].
  /// Sert uniquement au ratio qualitatif d'endettement, jamais à une part.
  final double dettesCommunes;

  const DivorceInput({
    required this.marriageDurationYears,
    required this.numberOfChildren,
    required this.regime,
    required this.canton,
    required this.incomeConjoint1,
    required this.incomeConjoint2,
    required this.lppConjoint1,
    required this.lppConjoint2,
    this.avoirAuMariage1,
    this.avoirAuMariage2,
    required this.pillar3aConjoint1,
    required this.pillar3aConjoint2,
    required this.fortuneCommune,
    required this.dettesCommunes,
  });
}

/// LPP split result.
class LppSplitResult {
  final double totalLpp;

  /// Part de prévoyance acquise PENDANT le mariage par chaque conjoint —
  /// seule base de partage (CC art. 122 / LFLP art. 22a).
  final double acquisConjoint1;
  final double acquisConjoint2;

  /// Solde de prévoyance de chaque conjoint APRÈS le partage : avoir actuel
  /// ∓ transfert. Ce n'est pas « la moitié des acquêts » — cette moitié n'est
  /// l'avoir de personne. Les deux soldes s'additionnent à [totalLpp].
  final double shareConjoint1;
  final double shareConjoint2;
  final double transferAmount;
  final String transferDirection; // "1 → 2" or "2 → 1"

  /// True quand l'avoir au mariage manque pour au moins un conjoint : le
  /// montant de transfert ne peut pas être calculé de façon certaine. L'UI
  /// doit demander la donnée plutôt qu'afficher un transfert.
  final bool isIncomplete;

  const LppSplitResult({
    required this.totalLpp,
    required this.acquisConjoint1,
    required this.acquisConjoint2,
    required this.shareConjoint1,
    required this.shareConjoint2,
    required this.transferAmount,
    required this.transferDirection,
    this.isIncomplete = false,
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

// ⚠️ Il n'existe PLUS de `PatrimoineSplitResult` — c'est délibéré.
//
// Aucune part personnelle de liquidation n'est calculée, pour aucun régime :
//  • participation aux acquêts (CC art. 215) : chacun a droit à la moitié du
//    bénéfice de L'AUTRE, puis les deux créances se compensent. Cela exige le
//    compte d'acquêts de CHAQUE époux, après réunions (art. 208), récompenses
//    (art. 206 et 209) et attribution de chaque dette à la bonne masse. Une
//    masse commune unique divisée par deux n'approche ce résultat que si aucun
//    de ces éléments n'existe — hypothèse que rien ne permet de poser ;
//  • communauté de biens : en cas de DIVORCE c'est CC art. 242 al. 1-2 (chacun
//    reprend d'abord les biens communs qui auraient été ses biens propres sous
//    participation, seul le solde se partage par moitié), et non l'art. 241 qui
//    ne vise que la dissolution par décès ou changement de régime ;
//  • séparation de biens (CC art. 247-251) : il n'y a pas de masse à partager.
//
// L'UI énonce ces mécaniques par régime au lieu d'un chiffre. Les champs de
// parts ont été SUPPRIMÉS plutôt que laissés calculés : une part indéfendable
// qui dort dans le résultat finit par être affichée (audit conseiller
// 2026-07-26, HIGH #3).

/// Full divorce simulation result.
///
/// AUCUN montant d'entretien n'est exposé — délibérément. Le droit suisse fait
/// dépendre l'entretien des revenus disponibles nets, du minimum vital, du
/// logement, des frais de garde, du taux de garde, du train de vie, de la
/// capacité de gain et du clean-break. L'ancienne heuristique (forfait par
/// enfant + pourcentage de l'écart de revenus + seuils de durée) ne correspondait
/// à aucune règle suisse et a été supprimée (audit conseiller 2026-07-26) : les
/// écrans énoncent les facteurs déterminants et renvoient vers un·e spécialiste.
/// L'alerte qualitative signale un point à EXAMINER au sens de CC art. 125 — le
/// droit résulte d'un examen individuel et une longue durée de mariage ne le
/// crée pas automatiquement (ATF 137 III 102 ; TF 5A_853/2024). Elle n'affirme
/// donc ni probabilité, ni droit, ni montant.
class DivorceResult {
  final LppSplitResult lppSplit;
  final TaxImpactResult taxImpact;
  final List<String> alerts;
  final List<String> checklist;

  const DivorceResult({
    required this.lppSplit,
    required this.taxImpact,
    required this.alerts,
    required this.checklist,
  });
}

/// Service for simulating the financial impact of divorce under Swiss law.
class DivorceService {
  /// Run a full divorce financial simulation.
  static DivorceResult simulate({required DivorceInput input}) {
    // ---- LPP Split (CC art. 122 / LFLP art. 22a) ----
    // Le partage 50/50 porte uniquement sur la pr\u00e9voyance acquise PENDANT le
    // mariage : part acquise_i = max(0, avoir actuel_i \u2212 avoir au mariage_i).
    // L'avoir constitu\u00e9 avant le mariage est exclu du partage. Splitter l'avoir
    // total surestime le transfert.
    final totalLpp = input.lppConjoint1 + input.lppConjoint2;
    final bool lppIncomplete =
        input.avoirAuMariage1 == null || input.avoirAuMariage2 == null;

    late final LppSplitResult lppSplit;
    double lppTransfer;
    if (lppIncomplete) {
      // Donn\u00e9e requise : sans l'avoir au mariage de chaque conjoint, on ne
      // peut pas isoler la part acquise pendant le mariage. On ne splitte PAS
      // l'avoir total \u2014 on signale un r\u00e9sultat incomplet \u00e0 l'UI.
      lppTransfer = 0;
      lppSplit = LppSplitResult(
        // L'avoir LPP total ACTUEL des deux conjoints est connu — on le conserve.
        // Seule la part acquise pendant le mariage (et donc le split/transfert)
        // reste bloquée faute d'avoir au mariage.
        totalLpp: totalLpp,
        acquisConjoint1: 0,
        acquisConjoint2: 0,
        shareConjoint1: 0,
        shareConjoint2: 0,
        transferAmount: 0,
        transferDirection: '-',
        isIncomplete: true,
      );
    } else {
      final acquis1 =
          (input.lppConjoint1 - input.avoirAuMariage1!).clamp(0.0, double.infinity);
      final acquis2 =
          (input.lppConjoint2 - input.avoirAuMariage2!).clamp(0.0, double.infinity);
      lppTransfer = (acquis1 - acquis2).abs() / 2;
      final lppDirection = acquis1 > acquis2 ? '1 \u2192 2' : '2 \u2192 1';

      // Solde de CHACUN après partage = son avoir actuel ∓ le transfert. C'est
      // la seule lecture honnête : la « moitié du pool acquis » n'est l'avoir de
      // personne et ne se réconcilie pas avec le total affiché (audit conseiller
      // 2026-07-26). Les deux soldes s'additionnent bien à `totalLpp`.
      final pays1 = acquis1 > acquis2;
      final solde1 = (pays1
              ? input.lppConjoint1 - lppTransfer
              : input.lppConjoint1 + lppTransfer)
          .clamp(0.0, double.infinity);
      final solde2 = (pays1
              ? input.lppConjoint2 + lppTransfer
              : input.lppConjoint2 - lppTransfer)
          .clamp(0.0, double.infinity);

      lppSplit = LppSplitResult(
        totalLpp: totalLpp,
        acquisConjoint1: acquis1,
        acquisConjoint2: acquis2,
        shareConjoint1: solde1,
        shareConjoint2: solde2,
        transferAmount: lppTransfer,
        transferDirection: acquis1 == acquis2 ? '-' : lppDirection,
      );
    }

    // ---- 3a Split ----
    // Under participation aux acquêts, 3a accumulated during marriage is
    // considered an acquêt and split 50/50.
    // Under séparation de biens, no split.
    // Under communauté de biens, 100% pooled and split 50/50.
    // Note: 3a split depends on regime but is handled separately via
    // the LPP/3a partage logic. The patrimoine split below covers net wealth.

    // ---- Liquidation du régime matrimonial ----
    // AUCUNE part n'est calculée (voir la note au-dessus de DivorceResult).
    // `fortuneCommune` / `dettesCommunes` ne servent plus qu'au constat
    // QUALITATIF sur le niveau d'endettement, jamais à une part personnelle.

    // ---- Tax Impact ----
    // Impôt EFFECTIF des deux côtés (marié vs deux célibataires), via la fonction
    // canonique estimateMonthlyIncomeTax (estimateIncomeTaxV2/12) — plus de
    // marginale × revenu (qui surestimait le côté marié) ni de coefficient 0.65.
    // Les deux côtés partagent le MÊME modèle effectif → le delta est symétrique
    // et révèle la « pénalité de mariage » réelle (le divorce baisse souvent
    // l'impôt du ménage à deux revenus). NEVER #3 : une seule source de vérité L1.
    final combinedIncome = input.incomeConjoint1 + input.incomeConjoint2;
    // Impôt marié au barème « marié » (splitting) du canton RÉEL du ménage —
    // jamais un canton codé en dur. nombreEnfants:0 : le facteur enfant vaut 1.0,
    // les enfants relèvent de la garde/pension, pas de ce partage d'impôt.
    final taxMarried = RetirementTaxCalculator.estimateMonthlyIncomeTax(
          revenuAnnuelImposable: combinedIncome,
          canton: input.canton,
          etatCivil: 'marie',
          nombreEnfants: 0,
        ) *
        12;
    // Les deux impôts individuels utilisent le canton (confirmé) du ménage. Au
    // moment du divorce le domicile est commun → base légale correcte pour la
    // comparaison marié/séparés ; le canton futur de l'ex n'est PAS connu et n'est
    // pas fabriqué (l'écran l'énonce via divorceImpactFiscalCantonNote).
    final taxC1 = _estimateIndividualTax(input.incomeConjoint1, input.canton);
    final taxC2 = _estimateIndividualTax(input.incomeConjoint2, input.canton);
    final totalTaxAfter = taxC1 + taxC2;

    final taxImpact = TaxImpactResult(
      estimatedTaxMarried: taxMarried,
      estimatedTaxConjoint1: taxC1,
      estimatedTaxConjoint2: taxC2,
      totalTaxAfter: totalTaxAfter,
      delta: totalTaxAfter - taxMarried,
    );

    // ---- Pension Alimentaire ----
    // ⚠️ AUCUN MONTANT D'ENTRETIEN N'EST CALCULÉ ICI — c'est délibéré.
    // L'ancien modèle (forfait CHF 600/enfant + 8-15 % de l'écart de revenus +
    // seuils à 5/10 ans) ne correspond à AUCUNE règle du droit de la famille
    // suisse : le montant dépend des revenus disponibles nets, du minimum vital,
    // du logement, des frais de garde, du taux de garde, du train de vie, de la
    // capacité de gain et du clean-break. Il a été supprimé plutôt que laissé
    // calculé (audit conseiller 2026-07-26) — un chiffre indéfendable qui dort
    // dans le résultat finit par être affiché. L'écart de revenus reste utilisé
    // pour l'alerte QUALITATIVE ci-dessous, qui signale un point à EXAMINER au
    // sens de CC art. 125 — jamais une probabilité, un droit ou un montant.
    final incomeGap =
        (input.incomeConjoint1 - input.incomeConjoint2).abs();

    // ---- Alerts ----
    final alerts = <String>[];

    if (lppTransfer > 100000) {
      alerts.add(
        'Le transfert LPP est significatif ('
        '${chf.formatChfWithPrefix(lppTransfer)}). Verifiez les montants exacts '
        'aupres de ta caisse de pension.',
      );
    }

    // Ratio purement qualitatif. Garde-fou : sans patrimoine renseigné
    // (fortuneCommune == 0 quand le fait n'est pas confirmé), le ratio se
    // calculerait contre un 0 fabriqué et affirmerait « dettes élevées » sans
    // base. On exige donc les deux montants pour émettre le constat.
    if (input.fortuneCommune > 0 &&
        input.dettesCommunes > input.fortuneCommune * 0.5) {
      alerts.add(
        'Les dettes du ménage sont élevées par rapport au patrimoine indiqué. '
        'L\'attribution de chaque dette à la bonne masse est un point à '
        'clarifier avant de signer la convention.',
      );
    }

    if (taxImpact.delta > 5000) {
      // taxImpact.delta = impôt des deux ex-conjoints séparés − impôt du couple
      // marié : c'est le surcoût du MÉNAGE (fin du splitting), pas l'impôt
      // personnel de l'utilisateur — on ne l'attribue jamais à « ton budget ».
      alerts.add(
        'L\'impact fiscal du divorce est important : '
        '+${chf.formatChfWithPrefix(taxImpact.delta)}/an pour le ménage. '
        'Anticipez ce surcoût dans le budget des deux foyers.',
      );
    }

    // CC art. 125 al. 1-2 : le droit à une contribution d'entretien résulte d'un
    // examen INDIVIDUEL (capacité de subvenir soi-même, répartition des tâches
    // pendant le mariage, durée, train de vie, âge et santé, revenus et fortune,
    // prise en charge des enfants, formation et perspectives de gain,
    // prévoyance). Une longue durée de mariage ne crée AUCUN droit automatique
    // (ATF 137 III 102 ; TF 5A_853/2024). L'alerte signale donc un point à
    // EXAMINER — jamais une probabilité, jamais un droit, jamais un montant.
    if (input.marriageDurationYears >= 10 && incomeGap > 40000) {
      alerts.add(
        'Mariage de longue durée avec un écart de revenus important : '
        'cela justifie d\'examiner une éventuelle contribution d\'entretien '
        'au conjoint (CC art. 125). Les éléments saisis ici n\'établissent '
        'aucun droit — celui-ci dépend d\'un examen individuel de la '
        'situation des deux conjoints.',
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
        'Régime de séparation de biens : il n\'y a pas de masse à partager '
        '(CC art. 247), mais la propriété de chaque bien doit être prouvée — '
        'à défaut, le bien est présumé en copropriété (CC art. 248). Le 3a '
        'n\'est pas automatiquement partagé.',
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
      alerts: alerts,
      checklist: checklist,
    );
  }

  /// Impôt individuel (célibataire) via la fonction canonique effective.
  ///
  /// Réutilise RetirementTaxCalculator.estimateMonthlyIncomeTax (impôt EFFECTIF
  /// estimateIncomeTaxV2/12, barème célibataire) au canton RÉEL fourni par
  /// DivorceInput (donnée réelle du profil) — jamais un proxy médian codé en dur,
  /// jamais la marginale × revenu × 0.65. Symétrique avec l'impôt marié : le delta
  /// compare deux impôts EFFECTIFS (NEVER #3 : une seule source de vérité L1).
  static double _estimateIndividualTax(double income, String canton) {
    if (income <= 0) return 0;
    return RetirementTaxCalculator.estimateMonthlyIncomeTax(
          revenuAnnuelImposable: income,
          canton: canton,
          etatCivil: 'celibataire',
          nombreEnfants: 0,
        ) *
        12;
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

  /// Verdict fiscal directionnel par héritier (socle ESTV 1.1.2025) —
  /// remplace l'ancien `taxByHeir` en montant × taux plat
  /// (ADR 2026-07-28 P4).
  final Map<String, SuccessionDonationVerdict> verdictByHeir;
  final String pillar3aBeneficiaryOrder;

  const SuccessionResult({
    required this.legalDistribution,
    this.testamentDistribution,
    required this.quotiteDisponible,
    required this.quotiteDisponiblePct,
    required this.totalEstate,
    required this.alerts,
    required this.checklist,
    required this.verdictByHeir,
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

    // ---- Verdict fiscal par héritier (socle ESTV — pas de montant × taux) ----
    final verdictByHeir = <String, SuccessionDonationVerdict>{};
    final distribution = testamentDistribution ?? legalDistribution;
    for (final heir in distribution) {
      verdictByHeir[heir.heirLabel] = SuccessionDonationSocle.verdict(
        canton: input.canton,
        categorie: _kinshipFromLabel(heir.heirLabel),
      );
    }

    // ---- 3a Beneficiary Order (OPP3 art. 2) ----
    final pillar3aOrder = _get3aBeneficiaryOrder(input.civilStatus);

    // ---- Alerts ----
    final alerts = <String>[];

    if (input.civilStatus == CivilStatus.concubinage) {
      // Message conservé, chiffre/étiquette plat retiré, bascule du socle
      // ajoutée (ADR 2026-07-28 P4).
      final concubinVerdict = SuccessionDonationSocle.verdict(
        canton: input.canton,
        categorie: 'concubin',
      );
      final fiscal = concubinVerdict.statut == 'exonere'
          ? 'Dans ton canton, une transmission au concubin peut être ' // lint-ignore
              'exonérée sous condition.' // lint-ignore
          : 'La fiscalité est aussi nettement plus lourde ' // lint-ignore
              '(souvent la classe la plus chargée du barème cantonal).'; // lint-ignore
      final bascule =
          concubinVerdict.bascule == null ? '' : ' ${concubinVerdict.bascule}';
      alerts.add(
        'En concubinage, ton/ta partenaire n\'a AUCUN droit '
        'successoral legal. Sans testament, il/elle ne recoit '
        'rien. $fiscal$bascule',
      );
    }

    if (input.avoirs3a > 0 &&
        (input.civilStatus == CivilStatus.concubinage ||
            input.civilStatus == CivilStatus.celibataire)) {
      alerts.add(
        'Tes avoirs 3a (${chf.formatChfWithPrefix(input.avoirs3a)}) suivent '
        'l\'ordre de beneficiaires OPP3, pas ton testament. '
        'Verifie tes clauses beneficiaires aupres de ta '
        'fondation 3a.',
      );
    }

    if (input.capitalDecesLpp > 0) {
      alerts.add(
        'Le capital-deces LPP (${chf.formatChfWithPrefix(input.capitalDecesLpp)}) '
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
      verdictByHeir: verdictByHeir,
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

  // --------------------------------------------------------------------
  // Pas de table de taux successoral par canton — NE PAS EN RECRÉER UNE.
  //
  // _successionTaxRates (6 cantons + fallback VD) vivait ici : des taux
  // plats non sourcés, à l'envers du socle ESTV 1.1.2025 sur au moins
  // deux cantons (VD enfant 0.0 alors que la ligne directe y est TAXÉE,
  // déduction 1M par souche ; ZH enfant 0.02 alors que les descendants y
  // sont EXONÉRÉS). La source de vérité mobile est
  // lib/services/succession_donation_socle.dart (mini-socle généré,
  // parité verrouillée sur l'archive ESTV). ADR :
  // .planning/decisions/2026-07-28-remplacements-succession-donation-immo-lamal.md
  // --------------------------------------------------------------------

  /// Map heir label to a socle categorie.
  static String _kinshipFromLabel(String label) {
    final lower = label.toLowerCase();
    if (lower.contains('conjoint')) return 'conjoint';
    if (lower.contains('enfant')) return 'descendant';
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

}
