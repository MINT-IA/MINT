import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/models/coach_entry_payload.dart';
import 'package:mint_mobile/providers/coach_entry_payload_provider.dart';
import 'package:mint_mobile/screens/coach/coach_chat_screen.dart';

/// Tab 1 — Mint (Coach)
///
/// Wraps the CoachChatScreen for tab-embedded usage.
/// Consumes pending [CoachEntryPayload] from [CoachEntryPayloadProvider]
/// (set by MintHomeScreen via MainNavigationShell) and forwards it
/// to CoachChatScreen for contextual coaching.
class MintCoachTab extends StatefulWidget {
  const MintCoachTab({super.key});

  @override
  State<MintCoachTab> createState() => _MintCoachTabState();
}

class _MintCoachTabState extends State<MintCoachTab> {
  /// Key used to force CoachChatScreen rebuild when a new payload arrives.
  Key _chatKey = UniqueKey();

  /// The payload currently being consumed by CoachChatScreen.
  CoachEntryPayload? _activePayload;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Check for a pending payload each time dependencies change (tab switch).
    final provider = context.read<CoachEntryPayloadProvider>();
    final pending = provider.consumePayload();
    if (pending != null) {
      setState(() {
        _activePayload = pending;
        _chatKey = UniqueKey(); // Force rebuild to inject new payload
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: S.of(context)!.semanticsCoachTabLabel,
      child: CoachChatScreen(
        key: _chatKey,
        isEmbeddedInTab: true,
        entryPayload: _activePayload,
      ),
    );
  }
}
