import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/constants/social_insurance.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/services/financial_core/avs_calculator.dart';
import 'package:mint_mobile/services/financial_core/lpp_calculator.dart';
import 'package:mint_mobile/services/financial_core/tax_calculator.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Early retirement comparison mini-table for 45-60 age group.
///
/// Shows household replacement rate estimates at ages 63, 64, 65, 67, 70.
/// Includes conjoint AVS+LPP when couple profile is present.
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

    // F3-3: Gender-aware AVS21 reference age for early retirement comparison.
    final ercIsFemale = profile.gender == 'F' ? true : (profile.gender == 'M' ? false : null);

    for (final retAge in ages) {
      if (retAge <= profile.age) continue;

      // ── User AVS (with lacunes + arrivalAge — LAVS art. 29) ──
      double avsUserMonthly = AvsCalculator.computeMonthlyRente(
        currentAge: profile.age,
        retirementAge: retAge,
        grossAnnualSalary: profile.revenuBrutAnnuel,
        lacunes: profile.prevoyance.lacunesAVS ?? 0,
        anneesContribuees: profile.prevoyance.anneesContribuees,
        arrivalAge: profile.arrivalAge,
        isFemale: ercIsFemale,
        birthYear: profile.birthYear,
      );

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

      // ── Conjoint AVS + LPP (if couple) ──
      double avsConjMonthly = 0;
      double lppConjMonthly = 0;
      if (isCouple) {
        final conj = profile.conjoint!;
        final conjAge = conj.age ?? profile.age;
        // Conjoint retires at their own effective age; project at same retAge
        // only if it's above their current age
        if (retAge > conjAge) {
          avsConjMonthly = AvsCalculator.computeMonthlyRente(
            currentAge: conjAge,
            retirementAge: retAge.clamp(conjAge + 1, 70),
            grossAnnualSalary: (conj.salaireBrutMensuel ?? 0) * 12,
            lacunes: conj.prevoyance?.lacunesAVS ?? 0,
            anneesContribuees: conj.prevoyance?.anneesContribuees,
            arrivalAge: conj.arrivalAge,
          );
          final conjLpp = conj.prevoyance?.avoirLppTotal ?? 0;
          if (conjLpp > 0) {
            final conjLppRente = LppCalculator.projectToRetirement(
              currentBalance: conjLpp,
              currentAge: conjAge,
              retirementAge: retAge.clamp(conjAge + 1, 70),
              grossAnnualSalary: (conj.salaireBrutMensuel ?? 0) * 12,
              caisseReturn: conj.prevoyance?.rendementCaisse ?? 0.02,
              conversionRate: conj.prevoyance?.tauxConversion ?? lppTauxConversionMinDecimal,
            );
            lppConjMonthly = conjLppRente / 12;
          }
        }
      }

      // ── Couple AVS cap (LAVS art. 35: married 150% max = 3780 CHF) ──
      if (isCouple && avsConjMonthly > 0) {
        final isMarried = profile.etatCivil == CoachCivilStatus.marie;
        final capped = AvsCalculator.computeCouple(
          avsUser: avsUserMonthly,
          avsConjoint: avsConjMonthly,
          isMarried: isMarried,
        );
        avsUserMonthly = capped.user;
        avsConjMonthly = capped.conjoint;
      }

      final totalMonthly = avsUserMonthly + lppUserMonthly +
          avsConjMonthly + lppConjMonthly +
          baseThreeAMonthly + baseLibreMonthly;

      // Replacement rate on household NET salary
      final userNet = NetIncomeBreakdown.compute(
        grossSalary: profile.revenuBrutAnnuel,
        canton: profile.canton,
        age: profile.age,
      ).monthlyNetPayslip;
      final conjNet = isCouple
          ? NetIncomeBreakdown.compute(
              grossSalary: (profile.conjoint!.salaireBrutMensuel ?? 0) * 12,
              canton: profile.canton,
              age: profile.conjoint!.age ?? profile.age,
            ).monthlyNetPayslip
          : 0.0;
      final householdNet = userNet + conjNet;
      final replacementRate =
          householdNet > 0 ? totalMonthly / householdNet : 0.0;

      rows.add(_ComparisonRow(
        age: retAge,
        totalMonthly: totalMonthly,
        replacementRate: replacementRate,
        isTarget: retAge == profile.effectiveRetirementAge,
      ));
    }

    if (rows.isEmpty) return const SizedBox.shrink();

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
            'Comparaison retraite anticip\u00e9e',
            style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            isCouple
                ? 'Taux de remplacement m\u00e9nage par \u00e2ge de d\u00e9part'
                : 'Estimation du taux de remplacement par \u00e2ge de d\u00e9part',
            style: MintTextStyles.labelSmall(color: MintColors.textSecondary).copyWith(fontSize: 12),
          ),
          const SizedBox(height: 12),
          // Header row
          Row(
            children: [
              SizedBox(
                width: 50,
                child: Text('Age',
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Text('Revenu mensuel',
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
              ),
              SizedBox(
                width: 70,
                child: Text('Taux',
                    textAlign: TextAlign.right,
                    style: MintTextStyles.labelSmall(color: MintColors.textMuted).copyWith(fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const Divider(height: 12),
          ...rows.map((r) => _buildRow(r)),
          const SizedBox(height: 10),
          Semantics(
            label: 'Simuler ta retraite anticipée',
            button: true,
            child: InkWell(
              onTap: () => context.push('/coach/cockpit'),
              child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Simuler ta retraite anticip\u00e9e',
                  style: MintTextStyles.bodySmall(color: MintColors.primary).copyWith(fontWeight: FontWeight.w600),
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
            'Outil \u00e9ducatif \u2014 les taux varient par caisse (LSFin).',
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
                  style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: textWeight),
                ),
                if (r.isTarget)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.star,
                        size: 12, color: MintColors.primary),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Text(
              'CHF ${r.totalMonthly.toStringAsFixed(0)}',
              style: MintTextStyles.bodySmall(color: MintColors.textPrimary).copyWith(fontWeight: textWeight),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text(
              '${(r.replacementRate * 100).toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: MintTextStyles.bodyMedium(color: r.replacementRate >= 0.60
                    ? MintColors.scoreGreen
                    : r.replacementRate >= 0.45
                        ? MintColors.scoreAttention
                        : MintColors.scoreRed).copyWith(fontWeight: textWeight),
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow {
  final int age;
  final double totalMonthly;
  final double replacementRate;
  final bool isTarget;

  const _ComparisonRow({
    required this.age,
    required this.totalMonthly,
    required this.replacementRate,
    required this.isTarget,
  });
}
