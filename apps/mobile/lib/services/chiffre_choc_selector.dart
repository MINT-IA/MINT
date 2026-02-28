import 'package:mint_mobile/models/minimal_profile_models.dart';

/// Selects the most impactful "chiffre choc" to show the user.
///
/// Sprint S31 — Onboarding Redesign.
///
/// Priority order:
/// 1. Liquidity alert (< 2 months reserves) — most urgent
/// 2. Retirement gap (replacement rate < 55%) — most common concern
/// 3. Tax saving 3a (> 500 CHF/year potential) — actionable
/// 4. Retirement income (fallback — always available)
class ChiffreChocSelector {
  ChiffreChocSelector._();

  /// Select the most impactful chiffre choc for the given profile.
  static ChiffreChoc select(MinimalProfileResult profile) {
    // Priority 1: Liquidity alert — reserves < 2 months of expenses
    if (profile.liquidityMonths < 2 && profile.currentSavings >= 0) {
      return ChiffreChoc(
        type: ChiffreChocType.liquidityAlert,
        value: '${profile.liquidityMonths.toStringAsFixed(1)} mois',
        rawValue: profile.liquidityMonths,
        title: 'Ta reserve de liquidite',
        subtitle: profile.liquidityMonths < 1
            ? 'Moins d\'un mois de reserves. '
                'Les experts recommandent 3 a 6 mois de depenses en epargne de securite.'
            : '${profile.liquidityMonths.toStringAsFixed(1)} mois de reserves. '
                'Les experts recommandent 3 a 6 mois de depenses en epargne de securite.',
        iconName: 'warning_amber',
        colorKey: 'error',
      );
    }

    // Priority 2: Retirement gap — replacement rate < 55%
    if (profile.replacementRate < 0.55 && profile.grossMonthlySalary > 0) {
      final gapFormatted = _formatChf(profile.retirementGapMonthly);
      final pct = (profile.replacementRate * 100).round();
      return ChiffreChoc(
        type: ChiffreChocType.retirementGap,
        value: '$gapFormatted/mois',
        rawValue: profile.retirementGapMonthly,
        title: 'Ton écart de retraite',
        subtitle:
            'À la retraite, tu pourrais recevoir environ $pct% de ton revenu actuel. '
            'Il te manquerait $gapFormatted chaque mois. '
            'Découvre comment réduire cet écart.',
        iconName: 'trending_down',
        colorKey: 'warning',
      );
    }

    // Priority 3: Tax saving 3a (> 1500 CHF/year — aligned with backend)
    if (profile.existing3a <= 0 && profile.taxSaving3a > 1500) {
      final savingFormatted = _formatChf(profile.taxSaving3a);
      return ChiffreChoc(
        type: ChiffreChocType.taxSaving3a,
        value: '$savingFormatted/an',
        rawValue: profile.taxSaving3a,
        title: 'Ton economie d\'impot potentielle',
        subtitle: 'En cotisant au 3e pilier (max CHF\u00A07\'258/an), '
            'tu pourrais economiser environ $savingFormatted d\'impots chaque annee. '
            'Et tu prepares ta retraite en meme temps.',
        iconName: 'savings',
        colorKey: 'success',
      );
    }

    // Fallback: Retirement income projection
    final retirementFormatted = _formatChf(profile.totalMonthlyRetirement);
    final pct = (profile.replacementRate * 100).round();
    return ChiffreChoc(
      type: ChiffreChocType.retirementIncome,
      value: '$retirementFormatted/mois',
      rawValue: profile.totalMonthlyRetirement,
      title: 'Ton revenu estime a la retraite',
      subtitle: 'Avec l\'AVS et la LPP, tu pourrais recevoir environ '
          '$retirementFormatted par mois, soit $pct% de ton salaire actuel.',
      iconName: 'account_balance',
      colorKey: 'info',
    );
  }

  /// Format a number as CHF with Swiss apostrophe separators.
  static String _formatChf(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return 'CHF\u00A0${intVal < 0 ? '-' : ''}${buffer.toString()}';
  }
}
