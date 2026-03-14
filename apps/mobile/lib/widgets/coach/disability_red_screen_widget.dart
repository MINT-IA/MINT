import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P4-C  L'Ecran rouge de l'independant — filet vs vide
//  Charte : L6 (Chiffre-choc) + L4 (Raconte ne montre pas)
//  Source : LAMal art. 67-77, CO art. 324a, LAVS, LPP art. 23
// ────────────────────────────────────────────────────────────

class DisabilityRedScreenWidget extends StatefulWidget {
  const DisabilityRedScreenWidget({
    super.key,
    required this.monthlyExpenses,
    this.hasPerteDegain = false,
  });

  final double monthlyExpenses;
  final bool hasPerteDegain;

  @override
  State<DisabilityRedScreenWidget> createState() => _DisabilityRedScreenWidgetState();
}

class _DisabilityRedScreenWidgetState extends State<DisabilityRedScreenWidget> {
  int? _answer; // 0=oui, 1=non, 2=ne sais pas

  static String _fmt(double v) {
    final n = v.round().abs();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  // Valeur illustrative : APG 80% + rente AI sur salaire median CH (SFSO 2024 ~6'500/mois).
  // Varie selon salaire. Affiche avec ~ pour indiquer l'ordre de grandeur.
  static const double _salarieMonthly = 4320;
  // Wired to social_insurance.dart (LAVS art. 34)
  static const double _aiRenteMax = aiRenteEntiere;
  // Wired to social_insurance.dart (LAI art. 28 + LPGA art. 19)
  static const int _aiDelayMonths = aiDecisionDelayMonths;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final emergencyNeeded = widget.monthlyExpenses * _aiDelayMonths;

    return Semantics(
      label: s.disabilityRedSemantics,
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
                  _buildComparisonTable(s),
                  const SizedBox(height: 20),
                  _buildChiffreChoc(emergencyNeeded, s),
                  const SizedBox(height: 20),
                  _buildQuestion(s),
                  if (_answer != null) _buildAnswerFeedback(s),
                  const SizedBox(height: 16),
                  _buildDisclaimer(s),
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
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.scoreCritique,
            MintColors.scoreCritique.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('\ud83d\udea8', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.disabilityRedTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: MintColors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            s.disabilityRedSubtitle,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonTable(S s) {
    return Row(
      children: [
        Expanded(
          child: _buildColumn(
            title: s.disabilityRedEmployeeTitle,
            emoji: '\ud83d\udc54',
            color: MintColors.scoreExcellent,
            items: [
              s.disabilityRedEmployeeApg,
              s.disabilityRedEmployeeLpp,
              s.disabilityRedEmployeeAi,
            ],
            totalMonthly: _salarieMonthly,
            totalLabel: s.disabilityRedEmployeeTotal(_fmt(_salarieMonthly)),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildColumn(
            title: s.disabilityRedYouTitle,
            emoji: '\ud83e\uddd1\u200d\ud83d\udcbc',
            color: MintColors.scoreCritique,
            items: [
              s.disabilityRedYouNothing,
              s.disabilityRedYouDuring,
              s.disabilityRedYouMonths('$_aiDelayMonths'),
            ],
            totalMonthly: 0,
            totalLabel: s.disabilityRedYouTotal,
            isVoid: true,
          ),
        ),
      ],
    );
  }

  Widget _buildColumn({
    required String title,
    required String emoji,
    required Color color,
    required List<String> items,
    required double totalMonthly,
    required String totalLabel,
    bool isVoid = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 6),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isVoid ? MintColors.scoreCritique.withValues(alpha: 0.08) : MintColors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: items.map((item) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      fontSize: isVoid ? 16 : 12,
                      fontWeight: isVoid ? FontWeight.w800 : FontWeight.w400,
                      color: isVoid ? MintColors.scoreCritique : MintColors.textPrimary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            totalLabel,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChiffreChoc(double emergencyNeeded, S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.disabilityRedChiffreChocTitle('$_aiDelayMonths'),
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: MintColors.scoreCritique,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            s.disabilityRedChiffreChocBody(_fmt(emergencyNeeded)),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            s.disabilityRedAfterAi(_fmt(_aiRenteMax)),
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestion(S s) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.info.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.info.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('\ud83d\udca1', style: TextStyle(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            s.disabilityRedQuestion,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildAnswerButton(0, s.disabilityRedAnswerYes),
              const SizedBox(width: 8),
              _buildAnswerButton(1, s.disabilityRedAnswerNo),
              const SizedBox(width: 8),
              _buildAnswerButton(2, s.disabilityRedAnswerDontKnow),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(int value, String label) {
    final isSelected = _answer == value;
    return GestureDetector(
      onTap: () => setState(() => _answer = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? MintColors.primary : MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? MintColors.primary : MintColors.lightBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? MintColors.white : MintColors.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _buildAnswerFeedback(S s) {
    final (msg, color) = switch (_answer) {
      0 => (s.disabilityRedFeedbackYes, MintColors.scoreExcellent),
      1 => (s.disabilityRedFeedbackNo, MintColors.scoreCritique),
      _ => (s.disabilityRedFeedbackDontKnow, MintColors.scoreAttention),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Text(
          msg,
          style: GoogleFonts.inter(
            fontSize: 13,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDisclaimer(S s) {
    return Text(
      s.disabilityRedDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
