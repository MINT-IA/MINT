import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

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
    this.allowSavingsAdjustment = true,
  });

  final double monthlyExpenses;
  final double initialSavings;
  final bool allowSavingsAdjustment;

  @override
  State<DisabilityCountdownWidget> createState() =>
      _DisabilityCountdownWidgetState();
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

  @override
  void didUpdateWidget(covariant DisabilityCountdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowSavingsAdjustment &&
        (oldWidget.initialSavings != widget.initialSavings ||
            oldWidget.allowSavingsAdjustment)) {
      _savings = widget.initialSavings;
    }
  }

  double get _monthsCanHold => _savings / widget.monthlyExpenses;
  double get _gapMonths =>
      (_aiDelayMonths - _monthsCanHold).clamp(0, _aiDelayMonths.toDouble());
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
    final s = S.of(context)!;
    final hold = _monthsCanHold;
    final gap = _gapMonths;
    final isOk = hold >= _aiDelayMonths;
    final color = isOk
        ? MintColors.scoreExcellent
        : hold >= 6
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Semantics(
      label: s.disabilityCountdownSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  widget.allowSavingsAdjustment
                      ? _buildSavingsSlider(context)
                      : _buildSavingsFact(),
                  const SizedBox(height: 20),
                  _buildTimeline(context, hold, gap, color),
                  const SizedBox(height: 16),
                  _buildPremierEclairage(context, hold, gap, color, isOk),
                  const SizedBox(height: 16),
                  if (!isOk) _buildActions(context),
                  if (!isOk) const SizedBox(height: 16),
                  _buildDisclaimer(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final s = S.of(context)!;
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
                  s.disabilityCountdownTitle,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.textPrimary)
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.disabilityCountdownDelayLabel(_aiDelayMonths),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsSlider(BuildContext context) {
    final maxSavings = _aiDelayMonths * widget.monthlyExpenses * 1.5;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context)!.disabilityAvailableSavings,
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              'CHF ${_fmt(_savings)}',
              style: MintTextStyles.bodyMedium(color: MintColors.primary)
                  .copyWith(fontWeight: FontWeight.w800),
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
            Text('CHF 0',
                style: MintTextStyles.micro(color: MintColors.textSecondary)),
            Text(
              'CHF ${_fmt(maxSavings)}',
              style: MintTextStyles.micro(color: MintColors.textSecondary),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSavingsFact() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_outlined,
              color: MintColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              S.of(context)!.disabilityAvailableSavings,
              style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
            ),
          ),
          Text(
            'CHF ${_fmt(_savings)}',
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(
    BuildContext context,
    double hold,
    double gap,
    Color color,
  ) {
    final s = S.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          s.disabilityCountdownTimelineTitle,
          style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
              .copyWith(fontWeight: FontWeight.w700),
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
                  s.disabilityCountdownHoldSpan(hold.toStringAsFixed(1)),
                  style: MintTextStyles.labelSmall(color: color)
                      .copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  s.disabilityCountdownHoldLabel,
                  style: MintTextStyles.micro(color: MintColors.textSecondary),
                ),
              ],
            ),
            if (gap > 0)
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    s.disabilityCountdownGapSpan(gap.toStringAsFixed(1)),
                    style: MintTextStyles.labelSmall(
                            color: MintColors.scoreCritique)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    s.disabilityCountdownGapLabel,
                    style:
                        MintTextStyles.micro(color: MintColors.textSecondary),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            s.disabilityCountdownDecisionLabel(_aiDelayMonths),
            style: MintTextStyles.micro(color: MintColors.textSecondary),
          ),
        ),
      ],
    );
  }

  Widget _buildPremierEclairage(
    BuildContext context,
    double hold,
    double gap,
    Color color,
    bool isOk,
  ) {
    final s = S.of(context)!;
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
              '✅ ${s.disabilityCountdownOkTitle}',
              style: MintTextStyles.bodySmall(color: MintColors.scoreExcellent)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              s.disabilityCountdownOkDetail(
                hold.toStringAsFixed(1),
                _aiDelayMonths,
              ),
              style:
                  MintTextStyles.labelMedium(color: MintColors.textSecondary),
            ),
          ] else ...[
            Text(
              '💰 ${s.disabilityCountdownShockDetail(hold.toStringAsFixed(1))}',
              style: MintTextStyles.bodySmall(color: MintColors.scoreCritique)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              s.disabilityCountdownGapAmount(_fmt(_gapAmount)),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(height: 1.4),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final s = S.of(context)!;
    return Column(
      children: [
        _buildAction(
          '→ ${s.disabilityCountdownEmergencyAction}',
          MintColors.primary,
        ),
        const SizedBox(height: 8),
        _buildAction(
          '→ ${s.disabilityCountdownApgAction}',
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
        style: MintTextStyles.bodySmall(color: color)
            .copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Text(
      S.of(context)!.disabilityCountdownDisclaimer,
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
