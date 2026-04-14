/// CleoLoopIndicator — pill showing current position in the Cleo service loop.
///
/// Phase 17: Living Timeline. Displays one of 5 positions:
/// Insight -> Plan -> Conversation -> Action -> Memory
library;

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/tension_card.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class CleoLoopIndicator extends StatelessWidget {
  final CleoLoopPosition position;

  const CleoLoopIndicator({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    final label = _resolveLabel(l10n);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: MintColors.craie,
        borderRadius: const BorderRadius.all(Radius.circular(100)),
        border: Border.all(
          color: MintColors.textMutedAaa.withValues(alpha: 0.3),
        ),
      ),
      child: Text(
        label,
        style: MintTextStyles.labelSmall(
          color: MintColors.textSecondary,
        ),
      ),
    );
  }

  String _resolveLabel(S l10n) {
    switch (position) {
      case CleoLoopPosition.insight:
        return l10n.cleoLoopInsight;
      case CleoLoopPosition.plan:
        return l10n.cleoLoopPlan;
      case CleoLoopPosition.conversation:
        return l10n.cleoLoopConversation;
      case CleoLoopPosition.action:
        return l10n.cleoLoopAction;
      case CleoLoopPosition.memory:
        return l10n.cleoLoopMemory;
    }
  }
}
