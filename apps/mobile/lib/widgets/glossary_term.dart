import 'package:flutter/material.dart';
import 'package:mint_mobile/services/glossary_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

/// A widget that wraps a Swiss financial term with a dotted underline.
///
/// On tap, shows a bottom sheet with a plain-language explanation.
/// After the user has looked up the same term 3 times, the underline
/// disappears — indicating the user "knows" the concept.
///
/// Usage:
/// ```dart
/// GlossaryTerm(term: 'LPP')
/// GlossaryTerm(term: 'AVS', style: MintTextStyles.titleMedium())
/// ```
class GlossaryTerm extends StatelessWidget {
  const GlossaryTerm({
    super.key,
    required this.term,
    this.style,
  });

  /// The financial term key (must match a key in [GlossaryService.explain]).
  final String term;

  /// Optional text style override.
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: GlossaryService.userKnowsTerm(term),
      builder: (context, snapshot) {
        final known = snapshot.data ?? false;
        if (known) return Text(term, style: style);

        return GestureDetector(
          onTap: () => _showExplanation(context),
          child: Text(
            term,
            style: (style ?? MintTextStyles.bodyMedium()).copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: MintColors.primary.withValues(alpha: 0.5),
              color: MintColors.primary,
            ),
          ),
        );
      },
    );
  }

  void _showExplanation(BuildContext context) {
    GlossaryService.trackLookup(term);
    final explanation = GlossaryService.explain(context, term);
    if (explanation == null) return;

    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(MintSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(term, style: MintTextStyles.titleMedium()),
            const SizedBox(height: MintSpacing.md),
            Text(explanation, style: MintTextStyles.bodyMedium()),
            const SizedBox(height: MintSpacing.lg),
          ],
        ),
      ),
    );
  }
}
