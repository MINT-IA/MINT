import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/screens/pulse/pulse_screen.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';

// ────────────────────────────────────────────────────────────
//  CAP CARD — "Cap du jour" widget for Aujourd'hui
// ────────────────────────────────────────────────────────────
//
//  Displays CapEngine output as a single, calm, actionable card.
//  Contract (MINT_UX_GRAAL_MASTERPLAN.md §10):
//  - headline: 4-9 words
//  - why_now: 1 sentence
//  - cta: 3-5 words
//  - expected_impact: 2-8 words
//  - lisible en 3 secondes
//
//  Narrative → action → proof accessible.
//  No badge. No border left. No mini-dashboard feel.
// ────────────────────────────────────────────────────────────

class CapCard extends StatelessWidget {
  final CapDecision cap;

  /// Kept for API compatibility but no longer rendered in the card.
  /// Feedback is shown via a snackbar instead.
  final String? recentActionLabel;

  const CapCard({
    super.key,
    required this.cap,
    this.recentActionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '${cap.headline} — ${cap.whyNow}',
      button: true,
      child: GestureDetector(
        onTap: () => _handleCta(context),
        child: Container(
          padding: const EdgeInsets.all(MintSpacing.lg),
          decoration: BoxDecoration(
            color: MintColors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: MintColors.black.withValues(alpha: 0.04),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Headline
              Text(
                cap.headline,
                style: MintTextStyles.headlineMedium(),
                maxLines: 2,
              ),
              const SizedBox(height: MintSpacing.sm),

              // Why now
              Text(
                cap.whyNow,
                style: MintTextStyles.bodyMedium(),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),

              // Expected impact
              if (cap.expectedImpact != null) ...[
                const SizedBox(height: MintSpacing.sm + 4),
                Row(
                  children: [
                    Icon(
                      Icons.trending_up_rounded,
                      size: 16,
                      color: MintColors.success.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        cap.expectedImpact!,
                        style: MintTextStyles.bodySmall(
                          color: MintColors.success,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: MintSpacing.md + 4),

              // CTA button
              _buildCta(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCta(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Semantics(
        button: true,
        label: cap.ctaLabel,
        child: GestureDetector(
          onTap: () => _handleCta(context),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: MintSpacing.sm + 4),
            decoration: BoxDecoration(
              color: MintColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  cap.ctaLabel,
                  style: MintTextStyles.labelLarge(color: MintColors.white)
                      ,
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: MintColors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleCta(BuildContext context) {
    // Snapshot profile hash BEFORE navigation to detect real changes on return
    final profileBefore = _profileHash(context);

    switch (cap.ctaMode) {
      case CtaMode.route:
        if (cap.ctaRoute != null) {
          context.push<void>(cap.ctaRoute!).then((_) {
            if (!context.mounted) return;
            _resolveCompletionOnReturn(context, profileBefore);
          });
        }
      case CtaMode.coach:
        if (cap.coachPrompt != null && cap.coachPrompt!.isNotEmpty) {
          CapCoachBridge.pendingPrompt = cap.coachPrompt;
        }
        NavigationShellState.switchTab(1);
      case CtaMode.capture:
        final route = switch (cap.captureType) {
          'lpp' => '/scan',
          'avs' => '/scan/avs-guide',
          'profile' => '/onboarding/enrichment',
          _ => '/onboarding/enrichment',
        };
        context.push<void>(route).then((_) {
          if (!context.mounted) return;
          _resolveCompletionOnReturn(context, profileBefore);
        });
    }
  }

  /// Compare profile state before/after navigation. If changed → user did something
  /// meaningful → mark cap completed. If unchanged → mark abandoned.
  void _resolveCompletionOnReturn(BuildContext context, int profileBefore) {
    final profileAfter = _profileHash(context);
    final profileChanged = profileAfter != profileBefore;

    CapMemoryStore.load().then((mem) {
      if (profileChanged) {
        // User changed their profile data during the flow → cap completed
        CapMemoryStore.markCompleted(mem, cap.id, headline: cap.headline);
      } else if (!mem.completedActions.contains(cap.id)) {
        // No profile change and not already completed → abandoned
        CapMemoryStore.markAbandoned(mem, cap.id, frictionContext: 'user_returned');
      }
    });
  }

  /// Quick hash of profile state to detect meaningful changes
  int _profileHash(BuildContext context) {
    try {
      final provider = Provider.of<CoachProfileProvider>(context, listen: false);
      final p = provider.profile;
      if (p == null) return 0;
      return Object.hash(
        p.salaireBrutMensuel, p.prevoyance.avoirLppTotal,
        p.prevoyance.totalEpargne3a, p.canton, p.etatCivil,
        p.employmentStatus, p.prevoyance.anneesContribuees,
      );
    } catch (_) {
      return 0;
    }
  }

}

/// Bridge for passing coach prompt from CapCard to CoachChatScreen.
///
/// CoachChatScreen checks [pendingPrompt] on mount and consumes it.
/// Lightweight alternative to a full Provider just for this handoff.
/// Bridge for passing coach prompt from CapCard to CoachChatScreen.
///
/// CoachChatScreen checks [pendingPrompt] on mount and consumes it.
/// Lightweight alternative to a full Provider just for this handoff.
class CapCoachBridge {
  CapCoachBridge._();
  static String? pendingPrompt;

  /// Consume the pending prompt (returns it and clears).
  static String? consume() {
    final p = pendingPrompt;
    pendingPrompt = null;
    return p;
  }
}
