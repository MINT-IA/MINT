import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/services/precision/precision_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

/// Card prompting the user to provide a more precise value
/// for a specific field, shown contextually when precision matters.
///
/// Displays:
/// - Document-scan icon + prompt text
/// - "Preciser" button
/// - "Continuer avec l'estimation" button
/// - Impact text: "Resultat +/-X % plus precis"
///
/// Usage:
/// ```dart
/// PrecisionPromptCard(
///   prompt: PrecisionPrompt(
///     trigger: 'rente_vs_capital',
///     fieldNeeded: 'lpp_obligatoire',
///     promptText: '...',
///     impactText: '...',
///   ),
///   onPrecise: () => navigateToFieldEntry(),
///   onSkip: () => continueWithEstimate(),
/// )
/// ```
class PrecisionPromptCard extends StatelessWidget {
  final PrecisionPrompt prompt;

  /// Called when the user taps "Preciser".
  final VoidCallback? onPrecise;

  /// Called when the user taps "Continuer avec l'estimation".
  final VoidCallback? onSkip;

  const PrecisionPromptCard({
    super.key,
    required this.prompt,
    this.onPrecise,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.info.withAlpha(18),
            MintColors.info.withAlpha(8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.info.withAlpha(40)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: icon + title
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: MintColors.info.withAlpha(25),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.description_outlined,
                    size: 20,
                    color: MintColors.info,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    s.precisionPromptTitle,
                    style: MintTextStyles.titleMedium(color: MintColors.textPrimary).copyWith(fontSize: 15),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Prompt text
            Text(
              prompt.promptText,
              style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(height: 1.5),
            ),

            const SizedBox(height: 10),

            // Impact badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: MintColors.info.withAlpha(20),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.trending_up,
                    size: 14,
                    color: MintColors.info,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      prompt.impactText,
                      style: MintTextStyles.bodySmall(color: MintColors.info).copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // Action buttons
            Row(
              children: [
                // Primary: Preciser
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onPrecise,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: Text(
                      s.precisionPromptPreciser,
                      style: MintTextStyles.bodySmall(color: MintColors.white).copyWith(fontWeight: FontWeight.w600),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.info,
                      foregroundColor: MintColors.white,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Secondary: Continue with estimation
                Expanded(
                  child: OutlinedButton(
                    onPressed: onSkip,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: MintColors.textSecondary,
                      side: const BorderSide(
                        color: MintColors.border,
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: Text(
                      s.precisionPromptContinuer,
                      style: MintTextStyles.bodySmall(color: MintColors.textSecondary).copyWith(fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Convenience widget: renders all precision prompts for the given
/// [context] + [profile] from [PrecisionService.getPrecisionPrompts].
class PrecisionPromptList extends StatelessWidget {
  final String promptContext;
  final Map<String, dynamic> profile;
  final void Function(PrecisionPrompt prompt)? onPrecise;
  final VoidCallback? onSkipAll;

  const PrecisionPromptList({
    super.key,
    required this.promptContext,
    required this.profile,
    this.onPrecise,
    this.onSkipAll,
  });

  @override
  Widget build(BuildContext context) {
    final prompts = PrecisionService.getPrecisionPrompts(
      context: promptContext,
      profile: profile,
    );
    if (prompts.isEmpty) return const SizedBox.shrink();

    return Column(
      children: prompts
          .map(
            (p) => PrecisionPromptCard(
              prompt: p,
              onPrecise: onPrecise != null ? () => onPrecise!(p) : null,
              onSkip: onSkipAll,
            ),
          )
          .toList(),
    );
  }
}
