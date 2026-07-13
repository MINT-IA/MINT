import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/utils/chf_formatter.dart';

/// Early retirement comparison mini-table for 45-60 age group.
///
/// Shows partial non-AVS retirement-income estimates at ages 63, 64, 65, 67,
/// and 70. Includes the conjoint's LPP when the couple profile is present.
/// Only displayed for users aged 45+.
class EarlyRetirementComparison extends StatelessWidget {
  final CoachProfile profile;
  final double baseThreeAMonthly;
  final double baseLibreMonthly;

  const EarlyRetirementComparison({
    super.key,
    required this.profile,
    this.baseThreeAMonthly = 0,
    this.baseLibreMonthly = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (profile.age < 45) return const SizedBox.shrink();

    final grossMonthlySalary = profile.revenuBrutAnnuel / 12;
    if (grossMonthlySalary <= 0) return const SizedBox.shrink();

    final isCouple = profile.isCouple &&
        profile.conjoint?.birthYear != null &&
        (profile.conjoint?.salaireBrutMensuel ?? 0) > 0;

    final ages = [63, 64, 65, 67, 70];
    final rows = <_ComparisonRow>[];

    for (final retAge in ages) {
      if (retAge <= profile.age) continue;

      // ── User LPP ──
      final lppBalance = profile.prevoyance.avoirLppTotal ?? 0;
      final lppRente = LppCalculator.projectToRetirement(
        currentBalance: lppBalance,
        currentAge: profile.age,
        retirementAge: retAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
        caisseReturn: profile.prevoyance.rendementCaisse,
        conversionRate: profile.prevoyance.tauxConversion,
      );
      final lppUserMonthly = lppRente / 12;

      // ── Conjoint LPP (if couple) ──
      double lppConjMonthly = 0;
      if (isCouple) {
        final conj = profile.conjoint!;
        final conjAge = conj.age ?? profile.age;
        // Conjoint retires at their own effective age; project at same retAge
        // only if it's above their current age
        if (retAge > conjAge) {
          final conjLpp = conj.prevoyance?.avoirLppTotal ?? 0;
          if (conjLpp > 0) {
            final conjLppRente = LppCalculator.projectToRetirement(
              currentBalance: conjLpp,
              currentAge: conjAge,
              retirementAge: retAge.clamp(conjAge + 1, 70),
              grossAnnualSalary: (conj.salaireBrutMensuel ?? 0) * 12,
              caisseReturn: conj.prevoyance?.rendementCaisse ?? 0.02,
              conversionRate: conj.prevoyance?.tauxConversion ??
                  lppTauxConversionMinDecimal,
            );
            lppConjMonthly = conjLppRente / 12;
          }
        }
      }

      final nonAvsMonthly = lppUserMonthly +
          lppConjMonthly +
          baseThreeAMonthly +
          baseLibreMonthly;

      rows.add(_ComparisonRow(
        age: retAge,
        nonAvsMonthly: nonAvsMonthly,
        isTarget: retAge == profile.effectiveRetirementAge,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();
    final l10n = S.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.earlyRetirementComparisonTitle,
            style: MintTextStyles.labelLarge(color: MintColors.textPrimary)
                .copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            isCouple
                ? l10n.earlyRetirementComparisonScopeHouseholdNonAvs
                : l10n.earlyRetirementComparisonScopeIndividualNonAvs,
            style: MintTextStyles.labelMedium(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 12),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text(l10n.earlyRetirementComparisonAgeHeader,
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted)
                            .copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text(l10n.earlyRetirementComparisonMonthlyIncomeNonAvs,
                    style:
                        MintTextStyles.labelSmall(color: MintColors.textMuted)
                            .copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Divider(height: 12),
          ...rows.map((r) => _buildRow(r)),
          const SizedBox(height: 10),
          Semantics(
            label: l10n.earlyRetirementComparisonCta,
            button: true,
            child: InkWell(
              onTap: () => context.push('/coach/cockpit'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    l10n.earlyRetirementComparisonCta,
                    style: MintTextStyles.bodySmall(color: MintColors.primary)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_forward,
                      size: 16, color: MintColors.primary),
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.earlyRetirementComparisonPartialDisclaimer,
            style: MintTextStyles.micro(color: MintColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(_ComparisonRow r) {
    final bgColor = r.isTarget
        ? MintColors.primary.withValues(alpha: 0.08)
        : MintColors.transparent;
    final textWeight = r.isTarget ? FontWeight.w700 : FontWeight.w500;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Row(
              children: [
                Text(
                  '${r.age}',
                  style:
                      MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                          .copyWith(fontWeight: textWeight),
                ),
                if (r.isTarget)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child:
                        Icon(Icons.star, size: 12, color: MintColors.primary),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              formatChfWithPrefix(r.nonAvsMonthly),
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary)
                  .copyWith(fontWeight: textWeight),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow {
  final int age;
  final double nonAvsMonthly;
  final bool isTarget;

  const _ComparisonRow({
    required this.age,
    required this.nonAvsMonthly,
    required this.isTarget,
  });
}
