import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

// ────────────────────────────────────────────────────────────
//  P4-F  Le Compte à rebours du délai de carence AI
//  Charte : L6 (Chiffre-choc) + L7 (Métaphore compte à rebours)
//  Source : LAI art. 28, LPGA art. 19
// ────────────────────────────────────────────────────────────

class DisabilityCountdownWidget extends StatefulWidget {
  const DisabilityCountdownWidget({
    super.key,
    required this.monthlyExpenses,
    required this.initialSavings,
  });

  final double monthlyExpenses;
  final double initialSavings;

  @override
  State<DisabilityCountdownWidget> createState() => _DisabilityCountdownWidgetState();
}

class _DisabilityCountdownWidgetState extends State<DisabilityCountdownWidget> {
  late double _savings;

  // Wire to social_insurance.dart single source of truth (LAI art. 28 + LPGA art. 19)
  static const int _aiDelayMonths = aiDecisionDelayMonths;

  @override
  void initState() {
    super.initState();
    _savings = widget.initialSavings;
  }

  double get _monthsCanHold => _savings / widget.monthlyExpenses;
  double get _gapMonths => (_aiDelayMonths - _monthsCanHold).clamp(0, _aiDelayMonths.toDouble());
  double get _gapAmount => _gapMonths * widget.monthlyExpenses;
  double get _holdFraction => (_monthsCanHold / _aiDelayMonths).clamp(0.0, 1.0);

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
    final hold = _monthsCanHold;
    final gap = _gapMonths;
    final isOk = hold >= _aiDelayMonths;
    final color = isOk
        ? MintColors.scoreExcellent
        : hold >= 6
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    final s = S.of(context)!;
    return Semantics(
      label: s.coachDisabilityCountdownSemantics,
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
                  _buildSavingsSlider(s),
                  const SizedBox(height: 20),
                  _buildTimeline(s, hold, gap, color),
                  const SizedBox(height: 16),
                  _buildChiffreChoc(s, hold, gap, color, isOk),
                  const SizedBox(height: 16),
                  if (!isOk) _buildActions(s),
                  if (!isOk) const SizedBox(height: 16),
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
        color: MintColors.amberWarm,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏱', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.coachDisabilityCountdownTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: MintColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.coachDisabilityCountdownSubtitle(_aiDelayMonths),
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsSlider(S s) {
    final maxSavings = _aiDelayMonths * widget.monthlyExpenses * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              s.coachDisabilityCountdownSavings,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: MintColors.textPrimary,
              ),
            ),
            Text(
              'CHF ${_fmt(_savings)}',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: MintColors.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: _savings,
          min: 0,
          max: maxSavings,
          divisions: 60,
          activeColor: MintColors.primary,
          onChanged: (v) => setState(() => _savings = v),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('CHF 0', style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary)),
            Text(
              'CHF ${_fmt(maxSavings)}',
              style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTimeline(S s, double hold, double gap, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.coachDisabilityCountdownDuration,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: MintColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Stack(
          children: [
            // Background bar (total AI delay)
            Container(
              height: 28,
              decoration: BoxDecoration(
                color: MintColors.scoreCritique.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            // Hold bar
            if (_holdFraction > 0)
              FractionallySizedBox(
                widthFactor: _holdFraction.clamp(0.0, 1.0),
                child: Container(
                  height: 28,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '◄── ${hold.toStringAsFixed(1)} mois ──►',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                Text(
                  s.coachDisabilityCountdownYouHold,
                  style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                ),
              ],
            ),
            if (gap > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '◄── ${gap.toStringAsFixed(1)} mois ──►',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: MintColors.scoreCritique,
                    ),
                  ),
                  Text(
                    s.coachDisabilityCountdownGap,
                    style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            s.coachDisabilityCountdownDayJ(_aiDelayMonths),
            style: GoogleFonts.inter(fontSize: 10, color: MintColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildChiffreChoc(S s, double hold, double gap, Color color, bool isOk) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isOk) ...[
            Text(
              '✅ ${s.coachDisabilityCountdownOk}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.scoreExcellent,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              s.coachDisabilityCountdownOkDetail(hold.toStringAsFixed(1), _aiDelayMonths),
              style: GoogleFonts.inter(fontSize: 12, color: MintColors.textSecondary),
            ),
          ] else ...[
            Text(
              '💰 ${s.coachDisabilityCountdownChiffreChoc(hold.toStringAsFixed(1))}',
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: MintColors.scoreCritique,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              s.coachDisabilityCountdownMissing(_fmt(_gapAmount)),
              style: GoogleFonts.inter(
                fontSize: 13,
                color: MintColors.textPrimary,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(S s) {
    return Column(
      children: [
        _buildAction(
          '→ ${s.coachDisabilityCountdownAction1}',
          MintColors.primary,
        ),
        const SizedBox(height: 8),
        _buildAction(
          '→ ${s.coachDisabilityCountdownAction2}',
          MintColors.info,
        ),
      ],
    );
  }

  Widget _buildAction(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      S.of(context)!.coachDisabilityCountdownDisclaimer,
      style: GoogleFonts.inter(
        fontSize: 10,
        color: MintColors.textSecondary,
        fontStyle: FontStyle.italic,
      ),
    );
  }
}
