import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P2-B  Le Film du divorce en 3 actes
//  Charte : L2 (Avant/Après) + L4 (Raconte)
//  Source : CC art. 122 (partage LPP), LIFD art. 33/23 (pensions),
//           LIFD art. 35 (déduction parent isolé)
// ────────────────────────────────────────────────────────────

class DivorceFilmWidget extends StatelessWidget {
  const DivorceFilmWidget({
    super.key,
    required this.myLpp,
    required this.partnerLpp,
    required this.lppTransfer,
    required this.lppTransferDirection,
    required this.annualTaxMarried,
    required this.annualTaxSingle,
    required this.childrenCount,
    required this.monthlyPension,
  });

  final double myLpp;
  final double partnerLpp;

  /// Transfert LPP RÉEL du service (part acquise pendant le mariage, CC art. 122
  /// / LFLP art. 22a) — la valeur affichée sur la carte Partage LPP / le hero.
  /// Le film ne recalcule JAMAIS un partage du solde total.
  final double lppTransfer;

  /// Sens du transfert : '1 → 2' (conjoint 1 = toi verses), '2 → 1' (tu reçois)
  /// ou '-' (aucun transfert).
  final String lppTransferDirection;

  final double annualTaxMarried;
  final double annualTaxSingle;
  final int childrenCount;

  /// Pension alimentaire mensuelle RÉELLE (calcul income-gap du service), la même
  /// valeur que la carte Pension de l'écran. Aucun forfait CHF/enfant + CHF
  /// conjoint codé en dur : chaque CHF du film trace une valeur réelle.
  final double monthlyPension;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  /// Solde LPP de l'utilisateur APRÈS le transfert réel : '1 → 2' = tu verses
  /// (soustrait), sinon tu reçois ou rien (ajoute 0). Jamais un partage du solde
  /// total : on applique le transfert RÉEL du service au solde de départ.
  double get _myLppAfter => (lppTransferDirection == '1 → 2'
          ? myLpp - lppTransfer
          : myLpp + lppTransfer)
      .clamp(0, double.infinity);

  // LPP rente loss using taux de conversion minimum (LPP art. 14), sur le
  // transfert RÉEL du service.
  double get _lppMonthlyRenteLoss =>
      lppTransfer * (lppTauxConversionMin / 100) / 12;

  double get _annualTaxDelta => annualTaxSingle - annualTaxMarried;
  double get _monthlyTaxDelta => _annualTaxDelta / 12;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Film du divorce LPP partage impôts pensions actes CC LIFD',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAct(
                    number: 'Acte 1',
                    emoji: '⚖️',
                    title: 'Le partage obligatoire',
                    color: MintColors.scoreCritique,
                    content: _buildAct1Content(),
                    legalRef: 'CC art. 122 — non négociable',
                  ),
                  const SizedBox(height: 12),
                  _buildAct(
                    number: 'Acte 2',
                    emoji: '📊',
                    title: 'L\'impôt change',
                    color: MintColors.scoreAttention,
                    content: _buildAct2Content(),
                    legalRef: 'LIFD art. 35 (déduction parent isolé)',
                  ),
                  const SizedBox(height: 12),
                  _buildAct(
                    number: 'Acte 3',
                    emoji: '👧',
                    title: 'Les pensions alimentaires',
                    color: MintColors.info,
                    content: _buildAct3Content(context),
                    legalRef: 'LIFD art. 33 (déductible) / art. 23 (imposable bénéficiaire)',
                  ),
                  const SizedBox(height: 16),
                  _buildDisclaimer(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🎬', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Le film du divorce en 3 actes',
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dans l\'ordre chronologique de ce que tu vas vivre — chiffres réels, pas de tabous.',
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildAct({
    required String number,
    required String emoji,
    required String title,
    required Color color,
    required Widget content,
    required String legalRef,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    number,
                    style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                const SizedBox(width: 8),
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                content,
                const SizedBox(height: 8),
                Text(
                  legalRef,
                  style: MintTextStyles.micro(color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAct1Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '"Vos LPP accumulés pendant le mariage sont coupés en deux. Point."',
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontStyle: FontStyle.italic, height: 1.4),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLppCard('Toi', myLpp, MintColors.scoreCritique)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 20, color: MintColors.textSecondary),
            ),
            Expanded(child: _buildLppCard('Toi (après)', _myLppAfter, MintColors.scoreAttention)),
          ],
        ),
        if (lppTransfer > 0) ...[
          const SizedBox(height: 10),
          Builder(builder: (context) {
            // Le sens du transfert vient du service (CC art. 122). '1 → 2' = TOI
            // (conjoint 1) verses à l'ex → ta rente baisse ; '2 → 1' = tu reçois
            // → ta rente augmente. Le montant est le même dans les deux sens ; la
            // phrase ne doit jamais dire « tu transfères » quand tu reçois.
            final userPays = lppTransferDirection == '1 → 2';
            final tone =
                userPays ? MintColors.scoreCritique : MintColors.scoreExcellent;
            final message = userPays
                ? 'Tu transfères CHF ${_fmt(lppTransfer)} → ta rente LPP baisse de ~CHF ${_fmt(_lppMonthlyRenteLoss)}/mois'
                : 'Tu reçois CHF ${_fmt(lppTransfer)} → ta rente LPP augmente de ~CHF ${_fmt(_lppMonthlyRenteLoss)}/mois';
            return Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: tone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                message,
                style: MintTextStyles.labelMedium(color: tone)
                    .copyWith(fontWeight: FontWeight.w700, height: 1.4),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildLppCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(amount)}',
            style: MintTextStyles.bodyMedium(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAct2Content() {
    final positive = _annualTaxDelta > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _buildTaxCard('Couple marié', annualTaxMarried, MintColors.scoreExcellent)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 20, color: MintColors.textSecondary),
            ),
            Expanded(child: _buildTaxCard('2 foyers séparés', annualTaxSingle, MintColors.scoreCritique)),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: (positive ? MintColors.scoreCritique : MintColors.scoreExcellent)
                .withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            // annualTaxSingle = impôt des DEUX ex-conjoints séparés (C1 + C2) ;
            // le delta est donc le changement au niveau du MÉNAGE, pas l'impôt
            // personnel de l'utilisateur. On ne dit jamais « tu perds » (la
            // répartition individuelle dépend du revenu de chacun).
            positive
                ? '+CHF ${_fmt(_monthlyTaxDelta)}/mois d\'impôts pour le ménage — la fin du splitting marié.'
                : '-CHF ${_fmt(_monthlyTaxDelta.abs())}/mois d\'impôts pour le ménage après la séparation.',
            style: MintTextStyles.labelMedium(color: positive ? MintColors.scoreCritique : MintColors.scoreExcellent).copyWith(fontWeight: FontWeight.w700, height: 1.4),
          ),
        ),
        if (childrenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            // Seul le NOMBRE d'enfants est confirmé — pas la garde ni des frais
            // de garde réels. On énonce la condition (« si »), jamais un « tu peux
            // déduire » qui présumerait la garde et l'éligibilité (LIFD art. 35).
            child: Text(
              '💡 Si tu as la garde et paies des frais de garde, ils peuvent être déductibles (LIFD art. 35).',
              style: MintTextStyles.labelSmall(color: MintColors.info).copyWith(height: 1.4),
            ),
          ),
      ],
    );
  }

  Widget _buildTaxCard(String label, double amount, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: MintTextStyles.labelSmall(color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(amount)}/an',
            style: MintTextStyles.bodySmall(color: color).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAct3Content(BuildContext context) {
    // Une SEULE pension réelle (service income-gap), jamais un forfait par
    // enfant/conjoint codé en dur — cohérent avec la carte Pension de l'écran.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPensionRow(
          S.of(context)!.divorceFilmPensionEstimee,
          monthlyPension,
        ),
        const SizedBox(height: 8),
        // Le service ne fournit PAS le sens du versement (montant non signé =
        // écart de revenus + enfants ; la direction du volet enfants dépend de la
        // garde, non captée). On énonce donc la règle fiscale GÉNÉRALE (vraie dans
        // les deux sens), jamais un « déductible de TES impôts » qui serait faux
        // quand c'est toi qui la reçois (LIFD art. 33/23).
        Text(
          '⚠️ La pension alimentaire est déductible du revenu de la personne qui la verse et imposable pour celle qui la reçoit.',
          style: MintTextStyles.labelSmall(color: MintColors.scoreAttention).copyWith(height: 1.4),
        ),
      ],
    );
  }

  Widget _buildPensionRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(child: Text(label, style: MintTextStyles.labelMedium(color: MintColors.textPrimary), overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Text(
            'CHF ${_fmt(amount)}/mois',
            style: MintTextStyles.labelMedium(color: MintColors.info).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil juridique au sens de la LSFin. '
      'Source : CC art. 122 (partage LPP), LIFD art. 33/23/35 (pensions alimentaires).',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
