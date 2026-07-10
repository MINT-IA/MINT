import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class UnemploymentCounterWidget extends StatelessWidget {
  const UnemploymentCounterWidget({
    super.key,
    required this.age,
    required this.monthlyBenefit,
    this.daysConsumed = 0,
    this.totalBenefitDays,
    this.coverageMonths,
  });

  final int age;
  final double monthlyBenefit;
  final int daysConsumed;
  final int? totalBenefitDays;
  final double? coverageMonths;

  static int _maxDays(int age) {
    if (age < 25) return acJoursMinCotisation;
    if (age < acAgeSeuillSenior) return acJoursStandard;
    return acJoursSenior;
  }

  static String _eligibilityLabel(S l10n, int age, int benefitDays) {
    if (benefitDays == acJoursMinCotisation) {
      return l10n.unemploymentCounterBracketUnder25NoChildren;
    }
    if (benefitDays == acJoursIntermediaireCotisation) {
      return l10n.unemploymentCounterBracket12To17Months;
    }
    if (benefitDays == acJoursStandard) {
      return l10n.unemploymentCounterBracket18PlusMonths;
    }
    if (benefitDays == acJoursSenior) {
      return l10n.unemploymentCounterBracketSeniorOrDisability;
    }
    if (age < 25) return l10n.unemploymentCounterAgeUnder25;
    if (age < acAgeSeuillSenior) return l10n.unemploymentCounterAge25To54;
    return l10n.unemploymentCounterAge55Plus;
  }

  static String _fmt(double value) {
    final n = value.round();
    if (n >= 1000) {
      final thousands = n ~/ 1000;
      final rest = n % 1000;
      return rest == 0
          ? "$thousands'000"
          : "$thousands'${rest.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final maxDays = totalBenefitDays ?? _maxDays(age);
    final remaining = (maxDays - daysConsumed).clamp(0, maxDays);
    final progressFraction = daysConsumed / maxDays;
    final monthsRemaining = coverageMonths == null
        ? remaining / acJoursOuvrablesMoisMoyen
        : coverageMonths! * remaining / maxDays;

    return Semantics(
      label: l10n.unemploymentCounterSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n, maxDays),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBar(l10n, progressFraction, remaining, maxDays),
                  const SizedBox(height: 20),
                  _buildStatsRow(l10n, remaining, monthsRemaining),
                  const SizedBox(height: 20),
                  _buildAgeTable(l10n, maxDays),
                  const SizedBox(height: 16),
                  _buildPremierEclairage(l10n),
                  const SizedBox(height: 16),
                  _buildDisclaimer(l10n),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(S l10n, int maxDays) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: MintColors.neutralBg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('⏳', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.unemploymentCounterTitle,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ).copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.unemploymentCounterMaxDaysSubtitle(
              _eligibilityLabel(l10n, age, maxDays),
              maxDays,
            ),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatChip(
                label: l10n.unemploymentCounterMonthlyBenefitChip(
                  _fmt(monthlyBenefit),
                ),
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: l10n.unemploymentCounterApproxMonthsChip(
                  (maxDays / acJoursOuvrablesMoisMoyen).toStringAsFixed(0),
                ),
                color: MintColors.info,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: MintTextStyles.labelMedium(
          color: color,
        ).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _buildProgressBar(
    S l10n,
    double fraction,
    int remaining,
    int maxDays,
  ) {
    final color = fraction < 0.5
        ? MintColors.scoreExcellent
        : fraction < 0.75
            ? MintColors.scoreAttention
            : MintColors.scoreCritique;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.unemploymentCounterDaysUsed(daysConsumed),
              style:
                  MintTextStyles.labelMedium(color: MintColors.textSecondary),
            ),
            Text(
              l10n.unemploymentCounterDaysRemaining(remaining),
              style: MintTextStyles.labelMedium(
                color: color,
              ).copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 14,
            backgroundColor: color.withValues(alpha: 0.15),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              l10n.unemploymentCounterDayStart,
              style: MintTextStyles.micro(
                color: MintColors.textSecondary,
              ).copyWith(fontStyle: FontStyle.normal),
            ),
            Text(
              l10n.unemploymentCounterDayEnd(maxDays),
              style: MintTextStyles.micro(color: MintColors.scoreCritique)
                  .copyWith(
                fontWeight: FontWeight.w700,
                fontStyle: FontStyle.normal,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsRow(S l10n, int remaining, double monthsRemaining) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            label: l10n.unemploymentCounterRemainingDaysLabel,
            value: '$remaining',
            color: MintColors.info,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatCard(
            label: l10n.unemploymentCounterApproxLabel,
            value: l10n.unemploymentCounterMonthsValue(
              monthsRemaining.toStringAsFixed(1),
            ),
            color: MintColors.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: MintTextStyles.headlineSmall(
              color: color,
            ).copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildAgeTable(S l10n, int activeBenefitDays) {
    final rows = [
      (
        label: l10n.unemploymentCounterBracketUnder25NoChildren,
        days: acJoursMinCotisation,
      ),
      (
        label: l10n.unemploymentCounterBracket12To17Months,
        days: acJoursIntermediaireCotisation,
      ),
      (
        label: l10n.unemploymentCounterBracket18PlusMonths,
        days: acJoursStandard,
      ),
      (
        label: l10n.unemploymentCounterBracketSeniorOrDisability,
        days: acJoursSenior,
      ),
    ];

    return Container(
      decoration: BoxDecoration(
        color: MintColors.appleSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.unemploymentCounterAgeBracketHeader,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ).copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  l10n.unemploymentCounterMaxBenefitsHeader,
                  style: MintTextStyles.labelSmall(
                    color: MintColors.textSecondary,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((row) {
            final isActive = activeBenefitDays == row.days;
            return Container(
              color:
                  isActive ? MintColors.primary.withValues(alpha: 0.07) : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  if (isActive)
                    const Icon(
                      Icons.arrow_right,
                      color: MintColors.primary,
                      size: 16,
                    ),
                  if (!isActive) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      row.label,
                      style: MintTextStyles.bodySmall(
                        color: isActive
                            ? MintColors.primary
                            : MintColors.textPrimary,
                      ).copyWith(
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w400,
                      ),
                    ),
                  ),
                  Text(
                    l10n.unemploymentCounterDaysValue(row.days),
                    style: MintTextStyles.bodySmall(
                      color: isActive
                          ? MintColors.primary
                          : MintColors.textPrimary,
                    ).copyWith(
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildPremierEclairage(S l10n) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MintColors.scoreCritique.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: MintColors.scoreCritique.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('⚠️', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.unemploymentCounterZeroChfTitle,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.scoreCritique,
                  ).copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.unemploymentCounterZeroChfBody,
                  style: MintTextStyles.labelMedium(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDisclaimer(S l10n) {
    return Text(
      l10n.unemploymentCounterDisclaimer,
      style: MintTextStyles.micro(
        color: MintColors.textSecondary,
      ).copyWith(fontStyle: FontStyle.normal),
    );
  }
}
