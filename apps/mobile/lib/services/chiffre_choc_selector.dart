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
  ///
  /// Adapts messaging based on employment status and nationality (archetype).
  static ChiffreChoc select(MinimalProfileResult profile) {
    // Priority 0: Archetype-specific alerts
    final archetypeChoc = _selectByArchetype(profile);
    if (archetypeChoc != null) return archetypeChoc;

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
      final isIndep = profile.employmentStatus == 'independant';
      final plafond = profile.plafond3a;
      final subtitle = isIndep && plafond != null
          ? 'Sans 2e pilier obligatoire, ton ecart de retraite est plus important. '
              'Avec seulement $pct% de remplacement, il te manquerait $gapFormatted/mois. '
              'Le 3e pilier (max CHF\u00A0${_formatChfPlain(plafond)}/an) est ton principal levier.'
          : '\u00c0 la retraite, tu pourrais recevoir environ $pct% de ton revenu actuel. '
              'Il te manquerait $gapFormatted chaque mois. '
              'Decouvre comment reduire cet ecart.';
      return ChiffreChoc(
        type: ChiffreChocType.retirementGap,
        value: '$gapFormatted/mois',
        rawValue: profile.retirementGapMonthly,
        title: 'Ton ecart de retraite',
        subtitle: subtitle,
        iconName: 'trending_down',
        colorKey: 'warning',
      );
    }

    // Priority 3: Tax saving 3a (> 1500 CHF/year — aligned with backend)
    if (profile.existing3a <= 0 && profile.taxSaving3a > 1500) {
      final savingFormatted = _formatChf(profile.taxSaving3a);
      final plafondText = profile.plafond3a != null ? _formatChfPlain(profile.plafond3a!) : '?';
      return ChiffreChoc(
        type: ChiffreChocType.taxSaving3a,
        value: '$savingFormatted/an',
        rawValue: profile.taxSaving3a,
        title: 'Ton economie d\'impot potentielle',
        subtitle: 'En cotisant au 3e pilier (max CHF\u00A0$plafondText/an), '
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

  /// Archetype-specific chiffre choc (highest priority when applicable).
  static ChiffreChoc? _selectByArchetype(MinimalProfileResult profile) {
    // Independent without LPP: massive retirement gap alert
    if (profile.employmentStatus == 'independant' &&
        profile.lppMonthlyRente <= 0 &&
        profile.grossMonthlySalary > 0) {
      final gapFormatted = _formatChf(profile.retirementGapMonthly);
      final plafondStr = profile.plafond3a != null
          ? _formatChfPlain(profile.plafond3a!)
          : '?';
      return ChiffreChoc(
        type: ChiffreChocType.retirementGap,
        value: '$gapFormatted/mois',
        rawValue: profile.retirementGapMonthly,
        title: 'Sans 2e pilier, ton gap de retraite',
        subtitle:
            'En tant qu\'independant\u00b7e sans LPP, seule l\'AVS te couvre. '
            'Il te manquerait $gapFormatted chaque mois a la retraite. '
            'Le 3e pilier (max CHF\u00A0$plafondStr/an) et '
            'une LPP facultative peuvent combler cet ecart.',
        iconName: 'warning_amber',
        colorKey: 'error',
      );
    }

    // Non-Swiss expat: AVS gap warning (only when nationality is known)
    if (profile.nationalityGroup != null && profile.nationalityGroup != 'CH' && profile.avsMonthlyRente < 1500) {
      final avsFormatted = _formatChf(profile.avsMonthlyRente);
      final subtitle = profile.nationalityGroup == 'EU'
          ? 'Tes annees de cotisation en Europe comptent aussi grace aux '
              'accords bilateraux. Avec $avsFormatted/mois d\'AVS estime, '
              'verifie ta rente avec ton releve de compte individuel (CI).'
          : 'Avec $avsFormatted/mois d\'AVS estime, ta rente pourrait etre '
              'reduite par des lacunes de cotisation. Demande ton releve CI '
              'a ta caisse de compensation.';
      return ChiffreChoc(
        type: ChiffreChocType.retirementGap,
        value: '$avsFormatted/mois',
        rawValue: profile.avsMonthlyRente,
        title: 'Ta rente AVS estimee',
        subtitle: subtitle,
        iconName: 'public',
        colorKey: 'warning',
      );
    }

    return null;
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

  /// Format a number as plain CHF amount (no prefix) for inline use.
  static String _formatChfPlain(double value) {
    final intVal = value.round();
    final str = intVal.abs().toString();
    final buffer = StringBuffer();
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write("'");
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
