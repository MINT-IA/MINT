import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P8-C  La Clause 3a oubliée — OPP3 clause bénéficiaire
//  Charte : L5 (1 action) + L6 (Chiffre-choc)
//  Source : OPP3 art. 2 al. 1 let. a, CC art. 457-462
// ────────────────────────────────────────────────────────────

class Clause3aWidget extends StatefulWidget {
  const Clause3aWidget({
    super.key,
    required this.balance3a,
    this.hasClause = false,
    this.partnerName,
  });

  final double balance3a;
  final bool hasClause;
  final String? partnerName;

  @override
  State<Clause3aWidget> createState() => _Clause3aWidgetState();
}

class _Clause3aWidgetState extends State<Clause3aWidget> {
  late bool _hasClause;

  @override
  void initState() {
    super.initState();
    _hasClause = widget.hasClause;
  }

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final partner = widget.partnerName ?? 'ton·ta partenaire';

    return Semantics(
      label: 'Clause 3a bénéficiaire OPP3 succession',
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(s),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBalanceChip(),
                  const SizedBox(height: 20),
                  _buildChiffreChoc(partner),
                  const SizedBox(height: 16),
                  _buildClauseQuestion(s),
                  const SizedBox(height: 12),
                  _buildFeedback(s, partner),
                  const SizedBox(height: 16),
                  _buildSteps(s),
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

  Widget _buildHeader(S s) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          const Text('🔑', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.clause3aTitle,
                  style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'OPP3 art. 2 — Le 3e pilier ne suit PAS les règles successorales ordinaires.',
                  style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.savings_outlined, color: MintColors.primary, size: 18),
          const SizedBox(width: 10),
          Text(
            'Ton 3e pilier : CHF ${_fmt(widget.balance3a)}',
            style: MintTextStyles.bodyMedium(color: MintColors.primary).copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(String partner) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '💰 Sans clause : ton 3a de CHF ${_fmt(widget.balance3a)} part à tes parents, pas à $partner.',
            style: MintTextStyles.bodySmall(color: MintColors.scoreCritique).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'La clause bénéficiaire déroge à la succession ordinaire (OPP3 art. 2). '
            'Sans clause déposée auprès de ta fondation, la loi s\'applique par défaut.',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseQuestion(S s) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.clause3aQuestion,
          style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildToggle('Oui', true),
            const SizedBox(width: 8),
            _buildToggle('Non', false),
          ],
        ),
      ],
    );
  }

  Widget _buildToggle(String label, bool value) {
    final isSelected = _hasClause == value;
    final color = value ? MintColors.scoreExcellent : MintColors.scoreCritique;
    return GestureDetector(
      onTap: () => setState(() => _hasClause = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: MintTextStyles.bodySmall(color: isSelected ? color : MintColors.textPrimary).copyWith(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildFeedback(S s, String partner) {
    if (_hasClause) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintColors.scoreExcellent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: MintColors.scoreExcellent, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.clause3aFeedbackOk(partner),
                style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, height: 1.4),
              ),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: MintColors.scoreCritique.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: MintColors.scoreCritique, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                s.clause3aFeedbackNok,
                style: MintTextStyles.labelSmall(color: MintColors.scoreCritique).copyWith(fontSize: 12, fontWeight: FontWeight.w600, height: 1.4),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSteps(S s) {
    final steps = [
      'Contacte ta fondation 3a (banque ou assurance)',
      'Demande le formulaire "clause bénéficiaire"',
      'Désigne ton·ta partenaire ou tes héritiers',
      'Renouvelle à chaque changement de situation',
    ];

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.clause3aStepsTitle,
            style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ...steps.asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: MintColors.info,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${e.key + 1}',
                      style: MintTextStyles.micro(color: MintColors.white).copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.value,
                    style: MintTextStyles.labelSmall(color: MintColors.textPrimary).copyWith(fontSize: 12, height: 1.4),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil éducatif · ne constitue pas un conseil financier au sens de la LSFin. '
      'Source : OPP3 art. 2 al. 1 let. a, CC art. 457-462.',
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
