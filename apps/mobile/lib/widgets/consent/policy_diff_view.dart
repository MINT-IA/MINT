// PolicyDiffView — minimal red-line diff between two privacy policy versions.
//
// v2.7 Phase 29 / PRIV-01.
//
// Server could return structured diff chunks later; for now this widget
// accepts `added` / `removed` line lists and renders with red-line styling.
import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class PolicyDiffView extends StatelessWidget {
  final String fromVersion;
  final String toVersion;
  final List<String> added;
  final List<String> removed;
  final VoidCallback onAcceptDelta;

  const PolicyDiffView({
    super.key,
    required this.fromVersion,
    required this.toVersion,
    required this.added,
    required this.removed,
    required this.onAcceptDelta,
  });

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l.policyDiffTitle,
            style: MintTextStyles.headlineSmall(color: MintColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            '$fromVersion → $toVersion',
            style: MintTextStyles.bodySmall(color: MintColors.textSecondary),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                for (final line in removed) _DiffLine(text: line, added: false),
                for (final line in added) _DiffLine(text: line, added: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onAcceptDelta,
            style: FilledButton.styleFrom(
              backgroundColor: MintColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(l.policyDiffAcceptDelta),
          ),
        ],
      ),
    );
  }
}

class _DiffLine extends StatelessWidget {
  final String text;
  final bool added;

  const _DiffLine({required this.text, required this.added});

  @override
  Widget build(BuildContext context) {
    final color = added ? MintColors.successBg : MintColors.urgentBg;
    final prefix = added ? '+ ' : '- ';
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$prefix$text',
        style: MintTextStyles.bodySmall(color: MintColors.textPrimary),
      ),
    );
  }
}
