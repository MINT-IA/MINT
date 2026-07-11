import 'package:flutter/material.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

// ────────────────────────────────────────────────────────────
//  P7-C  Compteur de jours — Capital temps (sablier)
//  Charte : L6 (Chiffre-choc) + L7 (Métaphore sablier)
//  Source : LACI art. 27-30
// ────────────────────────────────────────────────────────────

class UnemploymentCounterWidget extends StatelessWidget {
  const UnemploymentCounterWidget({
    super.key,
    required this.age,
    required this.monthlyBenefit,
    this.daysConsumed = 0,
    this.maxDays,
  });

  final int age;
  final double monthlyBenefit;
  final int daysConsumed;
  final int? maxDays;

  /// Durée max indemnités AC par tranche d'âge — cas standard (≥ 22 mois cotisation).
  /// Source : LACI art. 27 al. 2 lit. a-d.
  static int _maxDays(int age) {
    if (age < 25) {
      return acJoursMinCotisation; // 200 j — cotisation typiquement courte
    }
    if (age < acAgeSeuillSenior) {
      return acJoursStandard; // 400 j — LACI art. 27 al. 2 lit. c
    }
    return acJoursSenior; // 520 j — LACI art. 27 al. 2 lit. c
  }

  static String _ageLabel(S l10n, int age) {
    if (age < 25) return '< 25';
    if (age < acAgeSeuillSenior) return '25–54';
    return '≥ 55';
  }

  String _durationHeaderLabel(S l10n, int effectiveMaxDays) {
    if (maxDays != null) {
      return l10n.unemploymentCounterResultLabel(effectiveMaxDays);
    }
    return l10n.unemploymentCounterAgeResultLabel(
      _ageLabel(l10n, age),
      effectiveMaxDays,
    );
  }

  static String _fmt(double v) {
    final n = v.round();
    if (n >= 1000) {
      final t = n ~/ 1000;
      final r = n % 1000;
      return r == 0 ? "$t'000" : "$t'${r.toString().padLeft(3, '0')}";
    }
    return '$n';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final effectiveMaxDays = maxDays ?? _maxDays(age);
    final remaining =
        (effectiveMaxDays - daysConsumed).clamp(0, effectiveMaxDays);
    final progressFraction = daysConsumed / effectiveMaxDays;
    final monthsRemaining = remaining / 21.7;

    return Semantics(
      label: l10n.unemploymentCounterSemanticLabel,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(l10n, effectiveMaxDays),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressBar(
                    l10n,
                    progressFraction,
                    remaining,
                    effectiveMaxDays,
                  ),
                  const SizedBox(height: 20),
                  _buildStatsRow(l10n, remaining, monthsRemaining),
                  const SizedBox(height: 20),
                  _buildDurationTable(l10n, effectiveMaxDays),
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
                  l10n.unemploymentCounterCapitalTitle,
                  style:
                      MintTextStyles.titleMedium(color: MintColors.textPrimary)
                          .copyWith(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _durationHeaderLabel(l10n, maxDays),
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _buildStatChip(
                label: 'CHF ${_fmt(monthlyBenefit)}/mois',
                color: MintColors.primary,
              ),
              const SizedBox(width: 8),
              _buildStatChip(
                label: '≈ ${(maxDays / 21.7).toStringAsFixed(0)} mois',
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
        style: MintTextStyles.labelMedium(color: color)
            .copyWith(fontWeight: FontWeight.w700),
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
              'Restants : $remaining',
              style: MintTextStyles.labelMedium(color: color)
                  .copyWith(fontWeight: FontWeight.w700),
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
              'Jour 0',
              style: MintTextStyles.micro(color: MintColors.textSecondary)
                  .copyWith(fontStyle: FontStyle.normal),
            ),
            Text(
              'Jour $maxDays → 0 CHF',
              style: MintTextStyles.micro(color: MintColors.scoreCritique)
                  .copyWith(
                      fontWeight: FontWeight.w700, fontStyle: FontStyle.normal),
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
          label: 'Jours restants',
          value: '$remaining',
          color: MintColors.info,
        )),
        const SizedBox(width: 12),
        Expanded(
            child: _buildStatCard(
          label: 'Soit environ',
          value: '${monthsRemaining.toStringAsFixed(1)} mois',
          color: MintColors.primary,
        )),
      ],
    );
  }

  Widget _buildStatCard(
      {required String label, required String value, required Color color}) {
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
            style: MintTextStyles.headlineSmall(color: color)
                .copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _buildDurationTable(S l10n, int effectiveMaxDays) {
    final rows = [
      (
        label: '< 25 ans sans devoir d’entretien',
        days: acJoursMinCotisation,
      ),
      (
        label: l10n.unemploymentBracket2,
        days: acJoursIntermediaireCotisation,
      ),
      (
        label: '18–24 mois, cas standard',
        days: acJoursStandard,
      ),
      (
        label: l10n.unemploymentCounterSeniorAiRow,
        days: acJoursSenior,
      ),
      if (effectiveMaxDays > acJoursSenior)
        (
          label: l10n.unemploymentCounterNearAvsRow,
          days: effectiveMaxDays,
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
                    l10n.unemploymentCounterRuleHeader,
                    style: MintTextStyles.labelSmall(
                            color: MintColors.textSecondary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Text(
                  l10n.unemploymentCounterMaxHeader,
                  style:
                      MintTextStyles.labelSmall(color: MintColors.textSecondary)
                          .copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ...rows.map((r) {
            final isActive = effectiveMaxDays == r.days;
            return Container(
              key: Key('unemployment_duration_row_${r.days}'),
              color:
                  isActive ? MintColors.primary.withValues(alpha: 0.07) : null,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              child: Row(
                children: [
                  if (isActive)
                    const Icon(Icons.arrow_right,
                        color: MintColors.primary, size: 16),
                  if (!isActive) const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      r.label,
                      style: MintTextStyles.bodySmall(
                              color: isActive
                                  ? MintColors.primary
                                  : MintColors.textPrimary)
                          .copyWith(
                              fontWeight:
                                  isActive ? FontWeight.w700 : FontWeight.w400),
                    ),
                  ),
                  Text(
                    l10n.unemploymentWaitingDays(r.days),
                    style: MintTextStyles.bodySmall(
                            color: isActive
                                ? MintColors.primary
                                : MintColors.textPrimary)
                        .copyWith(
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w400),
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
        border:
            Border.all(color: MintColors.scoreCritique.withValues(alpha: 0.25)),
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
                  l10n.unemploymentCounterAfterLastDayTitle,
                  style:
                      MintTextStyles.bodySmall(color: MintColors.scoreCritique)
                          .copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.unemploymentCounterNoGraceBody,
                  style: MintTextStyles.labelMedium(
                          color: MintColors.textSecondary)
                      .copyWith(height: 1.5),
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
      style: MintTextStyles.micro(color: MintColors.textSecondary)
          .copyWith(fontStyle: FontStyle.normal),
    );
  }
}
