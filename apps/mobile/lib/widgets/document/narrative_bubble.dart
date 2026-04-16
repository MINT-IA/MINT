// Phase 28-04 — NarrativeBubble
//
// Coach-style commentary surfaced when the backend produced a useful
// human reading of the document but couldn't (or shouldn't) extract
// structured fields — e.g. mobile banking screenshots.
//
// If the backend attached a `commitment` payload (when/where/ifThen/
// actionLabel) we surface it as a single secondary CTA ("Rappelle-moi
// en mai"). Tapping the CTA forwards the parsed payload to
// CommitmentService via the parent screen — this widget never touches
// the network directly.

import 'package:flutter/material.dart';

import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';

class NarrativeBubble extends StatelessWidget {
  /// Coach narrative text (already passed through ComplianceGuard backend-side).
  final String narrative;

  /// Optional commitment payload: {when, where, ifThen, actionLabel}.
  final Map<String, dynamic>? commitment;

  /// Called with parsed (when, where, ifThen, actionLabel) when the user
  /// accepts the commitment CTA.
  final void Function(
    String when,
    String where,
    String ifThen,
    String actionLabel,
  )? onCommitmentAccepted;

  /// Called when the user dismisses the bubble. Optional — may be absent
  /// for pure inline rendering.
  final VoidCallback? onSkip;

  const NarrativeBubble({
    super.key,
    required this.narrative,
    this.commitment,
    this.onCommitmentAccepted,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final hasCommit = commitment != null && onCommitmentAccepted != null;
    return Container(
      key: const Key('narrativeBubble'),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            narrative,
            style: MintTextStyles.bodyMedium(color: MintColors.textPrimary)
                .copyWith(height: 1.5),
          ),
          if (hasCommit) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('narrativeCommitmentCta'),
                icon: const Icon(Icons.notifications_none_outlined,
                    size: 18, color: MintColors.primary),
                style: TextButton.styleFrom(
                  backgroundColor: MintColors.surface,
                  foregroundColor: MintColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: const BorderSide(color: MintColors.lightBorder),
                  ),
                ),
                onPressed: () {
                  final c = commitment!;
                  onCommitmentAccepted!(
                    (c['when'] ?? c['whenText'] ?? '').toString(),
                    (c['where'] ?? c['whereText'] ?? '').toString(),
                    (c['ifThen'] ?? c['ifThenText'] ?? '').toString(),
                    (c['actionLabel'] ?? c['action_label'] ??
                            s.documentBubbleNarrativeRemindLater)
                        .toString(),
                  );
                },
                label: Text(
                  (commitment!['actionLabel'] ?? commitment!['action_label'] ??
                          s.documentBubbleNarrativeRemindLater)
                      .toString(),
                  style: MintTextStyles.bodySmall(color: MintColors.primary)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
