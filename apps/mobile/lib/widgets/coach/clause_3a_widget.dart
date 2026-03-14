import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

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
    final partner = widget.partnerName ?? s.clause3aDefaultPartner;

    return Semantics(
      label: s.clause3aSemanticsLabel,
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
                  _buildBalanceChip(),
                  const SizedBox(height: 20),
                  _buildChiffreChoc(partner),
                  const SizedBox(height: 16),
                  _buildClauseQuestion(),
                  const SizedBox(height: 12),
                  _buildFeedback(partner),
                  const SizedBox(height: 16),
                  _buildSteps(),
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
                  S.of(context)!.clause3aHeaderTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  S.of(context)!.clause3aHeaderSubtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
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
            S.of(context)!.clause3aBalanceChip(_fmt(widget.balance3a)),
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.primary,
            ),
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
            S.of(context)!.clause3aChiffreChoc(_fmt(widget.balance3a), partner),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context)!.clause3aChiffreChocDetail,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClauseQuestion() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context)!.clause3aQuestion,
          style: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildToggle(S.of(context)!.clause3aYes, true),
            const SizedBox(width: 8),
            _buildToggle(S.of(context)!.clause3aNo, false),
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
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isSelected ? color : MintColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildFeedback(String partner) {
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
                S.of(context)!.clause3aFeedbackYes(partner),
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: MintColors.textPrimary,
                  height: 1.4,
                ),
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
                S.of(context)!.clause3aFeedbackNo,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: MintColors.scoreCritique,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildSteps() {
    final s = S.of(context)!;
    final steps = [
      s.clause3aStep1,
      s.clause3aStep2,
      s.clause3aStep3,
      s.clause3aStep4,
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
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.info,
            ),
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
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: MintColors.white),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.value,
                    style: GoogleFonts.inter(fontSize: 12, color: MintColors.textPrimary, height: 1.4),
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
      S.of(context)!.clause3aDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
