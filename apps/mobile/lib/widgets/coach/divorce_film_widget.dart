import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    required this.annualTaxMarried,
    required this.annualTaxSingle,
    required this.childrenCount,
    this.hasAlimony = true,
  });

  final double myLpp;
  final double partnerLpp;
  final double annualTaxMarried;
  final double annualTaxSingle;
  final int childrenCount;
  final bool hasAlimony;

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  double get _equalShare => (myLpp + partnerLpp) / 2;
  double get _lppTransfer => (myLpp - _equalShare).clamp(0, double.infinity);
  // LPP rente loss using taux de conversion minimum (LPP art. 14)
  double get _lppMonthlyRenteLoss => _lppTransfer * (lppTauxConversionMin / 100) / 12;

  double get _annualTaxDelta => annualTaxSingle - annualTaxMarried;
  double get _monthlyTaxDelta => _annualTaxDelta / 12;

  // Montants indicatifs OFS / jurisprudence cantonale — remplacer par le jugement réel
  double get _monthlyChildPension => childrenCount * 1500.0;
  double get _monthlyAlimony => hasAlimony ? 500.0 : 0.0;
  double get _totalMonthlyPension => _monthlyChildPension + _monthlyAlimony;

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
                    content: _buildAct3Content(),
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
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Dans l\'ordre chronologique de ce que tu vas vivre — chiffres réels, pas de tabous.',
            style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary, height: 1.4),
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
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: MintColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: MintColors.textPrimary,
                    ),
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
                  style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
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
          style: GoogleFonts.inter(
            fontSize: 13,
            color: MintColors.textPrimary,
            fontStyle: FontStyle.italic,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildLppCard('Toi', myLpp, MintColors.scoreCritique)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 20, color: MintColors.textSecondary),
            ),
            Expanded(child: _buildLppCard('Toi (après)', _equalShare, MintColors.scoreAttention)),
          ],
        ),
        if (_lppTransfer > 0) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MintColors.scoreCritique.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'Tu transfères CHF ${_fmt(_lppTransfer)} → ta rente LPP baisse de ~CHF ${_fmt(_lppMonthlyRenteLoss)}/mois',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: MintColors.scoreCritique,
                height: 1.4,
              ),
            ),
          ),
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
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(amount)}',
            style: GoogleFonts.montserrat(fontSize: 14, fontWeight: FontWeight.w800, color: color),
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
            Expanded(child: _buildTaxCard('Mariés', annualTaxMarried, MintColors.scoreExcellent)),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.arrow_forward, size: 20, color: MintColors.textSecondary),
            ),
            Expanded(child: _buildTaxCard('Séparé·e', annualTaxSingle, MintColors.scoreCritique)),
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
            positive
                ? '+CHF ${_fmt(_monthlyTaxDelta)}/mois d\'impôts — tu perds le splitting marié.'
                : '-CHF ${_fmt(_monthlyTaxDelta.abs())}/mois d\'impôts — tu gagnes en indépendance.',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: positive ? MintColors.scoreCritique : MintColors.scoreExcellent,
              height: 1.4,
            ),
          ),
        ),
        if (childrenCount > 0)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '💡 Avec la garde des enfants, tu peux déduire les frais de garde (LIFD art. 35).',
              style: GoogleFonts.inter(fontSize: 11, color: MintColors.info, height: 1.4),
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
          Text(label, style: GoogleFonts.inter(fontSize: 11, color: MintColors.textSecondary)),
          const SizedBox(height: 4),
          Text(
            'CHF ${_fmt(amount)}/an',
            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w800, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildAct3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (childrenCount > 0)
          _buildPensionRow('Enfant${childrenCount > 1 ? 's' : ''} ($childrenCount)', _monthlyChildPension),
        if (hasAlimony)
          _buildPensionRow('Entretien conjoint·e (3-5 ans)', _monthlyAlimony),
        if (_totalMonthlyPension > 0) ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total mensuel', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: MintColors.textPrimary)),
              Text(
                'CHF ${_fmt(_totalMonthlyPension)}/mois',
                style: GoogleFonts.montserrat(fontSize: 15, fontWeight: FontWeight.w800, color: MintColors.info),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '⚠️ La pension versée est déductible de TES impôts. Elle est imposable pour l\'autre.',
            style: GoogleFonts.inter(fontSize: 11, color: MintColors.scoreAttention, height: 1.4),
          ),
        ],
      ],
    );
  }

  Widget _buildPensionRow(String label, double amount) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary)),
          Text(
            'CHF ${_fmt(amount)}/mois',
            style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: MintColors.info),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil juridique au sens de la LSFin. '
      'Source : CC art. 122 (partage LPP), LIFD art. 33/23/35 (pensions alimentaires). '
      'Pension indicative : CHF 1\'500/enfant + CHF 500 conjoint·e.',
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
