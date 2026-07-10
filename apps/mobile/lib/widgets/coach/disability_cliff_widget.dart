import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P4-A  La Falaise — Timeline invalidité en 3 actes
//  Charte : L6 (Chiffre-choc) + L2 (Avant/Après) + L7 (Film)
//  Source : LAVS art. 28-29, LPP art. 23-26, LPGA art. 19
// ────────────────────────────────────────────────────────────

class DisabilityAct {
  const DisabilityAct({
    required this.label,
    required this.subtitle,
    required this.durationLabel,
    required this.monthlyIncome,
    required this.emoji,
    required this.color,
    this.detail,
  });

  final String label;
  final String subtitle;
  final String durationLabel;
  final double monthlyIncome;
  final String emoji;
  final Color color;
  final String? detail;
}

class DisabilityCliffWidget extends StatelessWidget {
  const DisabilityCliffWidget({
    super.key,
    required this.grossMonthly,
    required this.acts,
  });

  final double grossMonthly;
  final List<DisabilityAct> acts;

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
    final lastIncome = acts.isNotEmpty ? acts.last.monthlyIncome : grossMonthly;
    final lostMonthly = grossMonthly - lastIncome;
    final lostYearly15 = lostMonthly * 12 * 15;

    return Semantics(
      label: s.disabilityCliffSemantics,
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
                  _buildCurrentIncome(context),
                  const SizedBox(height: 20),
                  ...acts.asMap().entries.map(
                        (e) => _buildAct(context, e.key, e.value),
                      ),
                  const SizedBox(height: 8),
                  _buildPremierEclairage(
                    context,
                    lostMonthly,
                    lostYearly15,
                  ),
                  const SizedBox(height: 16),
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
        color: MintColors.urgentBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
                  s.disabilityCliffHeaderTitle,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            s.disabilityCliffSubtitle,
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentIncome(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.work_outline, color: MintColors.primary, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              s.disabilityCliffCurrentSalary(_fmt(grossMonthly)),
              style: MintTextStyles.bodyMedium(color: MintColors.primary)
                  .copyWith(fontWeight: FontWeight.w700),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAct(BuildContext context, int index, DisabilityAct act) {
    final s = S.of(context)!;
    final isLast = index == acts.length - 1;
    return Column(
      children: [
        if (index > 0) _buildArrow(),
        Container(
          margin: const EdgeInsets.only(bottom: 4),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: act.color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: act.color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(act.emoji, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.disabilityCliffActTitle(index + 1, act.label),
                          style: MintTextStyles.labelMedium(color: act.color)
                              .copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5),
                        ),
                        Text(
                          act.durationLabel,
                          style: MintTextStyles.labelMedium(
                              color: MintColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'CHF ${_fmt(act.monthlyIncome)}',
                        style: MintTextStyles.titleLarge(color: act.color)
                            .copyWith(fontWeight: FontWeight.w800),
                      ),
                      Text(
                        s.disabilityCliffPerMonth,
                        style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary),
                      ),
                    ],
                  ),
                ],
              ),
              if (act.subtitle.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  act.subtitle,
                  style: MintTextStyles.labelMedium(
                          color: MintColors.textSecondary)
                      .copyWith(height: 1.4),
                ),
              ],
              if (act.detail != null) ...[
                const SizedBox(height: 6),
                Text(
                  act.detail!,
                  style: MintTextStyles.labelSmall(color: act.color)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
              if (isLast && acts.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: MintColors.scoreCritique.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    s.disabilityCliffVsBefore(_fmt(grossMonthly)),
                    style: MintTextStyles.labelMedium(
                            color: MintColors.scoreCritique)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildArrow() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Icon(Icons.keyboard_arrow_down,
            color: MintColors.textSecondary, size: 24),
      ),
    );
  }

  Widget _buildPremierEclairage(
    BuildContext context,
    double lostMonthly,
    double lostYearly15,
  ) {
    final s = S.of(context)!;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.disabilityCliffShockTitle,
            style: MintTextStyles.labelMedium(color: MintColors.scoreCritique)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            s.disabilityCliffLostMonthly(_fmt(lostMonthly)),
            style: MintTextStyles.titleMedium(color: MintColors.scoreCritique)
                .copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            s.disabilityCliffLostOver15Years(_fmt(lostYearly15)),
            style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                .copyWith(height: 1.4),
          ),
          const SizedBox(height: 8),
          Text(
            '→ ${s.disabilityCliffAction}',
            style: MintTextStyles.bodySmall(color: MintColors.primary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(BuildContext context) {
    return Text(
      S.of(context)!.disabilityGapDisclaimer,
      style: MintTextStyles.micro(color: MintColors.textSecondary),
    );
  }
}
