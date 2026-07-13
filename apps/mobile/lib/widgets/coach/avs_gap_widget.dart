import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/expat_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Truthful AVS orientation for a declared period abroad.
///
/// Residence history is displayed as a fact to verify. Only gap years
/// documented by an individual-account statement may expose the proportional
/// statutory-scale benchmark, never a personal pension or CHF loss.
class AvsGapWidget extends StatelessWidget {
  const AvsGapWidget({
    super.key,
    required this.scenarioStarted,
    required this.assessment,
    required this.onOpenAvsVerificationGuide,
  });

  final bool scenarioStarted;
  final AvsGapAssessment? assessment;
  final VoidCallback onOpenAvsVerificationGuide;

  @override
  Widget build(BuildContext context) {
    if (!scenarioStarted) {
      return const SizedBox.shrink();
    }
    if (assessment == null) {
      return const SizedBox.shrink();
    }

    final l = S.of(context)!;
    final result = assessment!;
    final hasDocumentedGaps = result.documentedGapYears != null;

    return Semantics(
      identifier: 'expat_avs_scenario_result',
      label: l.expatAvsTruthSemantics,
      child: Container(
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: MintColors.lightBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(MintSpacing.lg),
              decoration: BoxDecoration(
                color: MintColors.warning.withValues(alpha: 0.08),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.expatAvsTruthTitle,
                    style: MintTextStyles.titleMedium(
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Text(
                    l.expatAvsYearsAbroadNotGap,
                    style: MintTextStyles.bodySmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(MintSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TruthCard(
                    key: const Key('expat_avs_declared_years'),
                    icon: Icons.public,
                    title: l.expatAvsYearsAbroadDeclared(
                      result.yearsAbroadDeclared,
                    ),
                    body: l.expatAvsYearsAbroadToVerify,
                    tone: MintColors.info,
                  ),
                  const SizedBox(height: MintSpacing.md),
                  if (hasDocumentedGaps)
                    _TruthCard(
                      key: const Key('expat_avs_gap_documented'),
                      icon: Icons.verified_outlined,
                      title: l.expatAvsDocumentedGaps(
                        result.documentedGapYears!,
                      ),
                      body: l.expatAvsDocumentedMinimumEffect(
                        result.documentedGapYears!,
                        result.conditionalMinimumScaleReductionPercent!
                            .toStringAsFixed(1),
                      ),
                      tone: MintColors.success,
                    )
                  else
                    Semantics(
                      identifier: 'expat_avs_gap_unknown',
                      container: true,
                      child: _TruthCard(
                        key: const Key('expat_avs_gap_unknown'),
                        icon: Icons.help_outline,
                        title: l.expatAvsGapUnknownTitle,
                        body: l.expatAvsGapUnknownBody,
                        tone: MintColors.warning,
                      ),
                    ),
                  const SizedBox(height: MintSpacing.md),
                  _TruthCard(
                    icon: Icons.account_balance_outlined,
                    title: l.expatAvsVoluntaryUnknownTitle,
                    body: l.expatAvsVoluntaryUnknownBody,
                    tone: MintColors.info,
                  ),
                  const SizedBox(height: MintSpacing.md),
                  _TruthCard(
                    icon: Icons.fact_check_outlined,
                    title: l.expatAvsOfficialNextStepTitle,
                    body: l.expatAvsOfficialNextStepBody,
                    tone: MintColors.primary,
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Semantics(
                    identifier: 'expat_avs_verification_guide_cta',
                    container: true,
                    button: true,
                    child: FilledButton.icon(
                      key: const Key('expat_avs_verification_guide_cta'),
                      onPressed: onOpenAvsVerificationGuide,
                      icon: const Icon(Icons.arrow_forward),
                      label: Text(l.expatAvsVerificationGuideCta),
                    ),
                  ),
                  const SizedBox(height: MintSpacing.md),
                  Text(
                    l.expatAvsNoPersonalAmount,
                    style: MintTextStyles.labelSmall(
                      color: MintColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MintSpacing.sm),
                  Text(
                    l.expatAvsTruthDisclaimer,
                    style: MintTextStyles.micro(
                      color: MintColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TruthCard extends StatelessWidget {
  const _TruthCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
    required this.tone,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(MintSpacing.md),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: tone, size: 20),
          const SizedBox(width: MintSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MintSpacing.xs),
                Text(
                  body,
                  style: MintTextStyles.bodySmall(
                    color: MintColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
