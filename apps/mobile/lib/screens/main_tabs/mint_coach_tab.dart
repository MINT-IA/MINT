import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';

/// Tab 1 — Mint (Coach)
///
/// Wraps the CoachChatScreen for tab-embedded usage.
/// The coach is the main interaction surface: questions, simulations,
/// Response Cards, education — all accessible conversationally.
class MintCoachTab extends StatelessWidget {
  const MintCoachTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context)!.semanticsCoachTabLabel,
      child: const CoachChatScreen(isEmbeddedInTab: true),
    );
  }
}
