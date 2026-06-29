/// CapDuJourBanner — top-of-home "cap du jour" card.
///
/// Wave B-minimal B1 (2026-04-18). Surfaces the single highest-priority
/// [CapDecision] from [MintStateProvider.state.currentCap] in a compact,
/// tappable card at the top of [AujourdhuiScreen]. When the state has
/// no cap yet (profile empty or recompute in flight), shows a calm
/// fallback that invites the user to tell MINT more about themselves.
///
/// Source of truth: [CapEngine.compute] (13 priority-ordered rules) is
/// re-run by [MintStateProvider] via the proxy provider wired in
/// `app.dart`, so this widget only needs to READ the cached state.
///
/// Refs:
/// - .planning/wave-b-home-orchestrateur/PLAN.md (B1)
/// - Panel daily-loop 2026-04-18: CapEngine had zero home consumer.
/// - Panel archi A2: MintStateProvider proxy guarantees cap freshness.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/models/coach_profile.dart'
    show FinancialArchetypeBackendName;
import 'package:mint_mobile/models/serialized_card_context.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/services/cap_memory_store.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/mint_card_action_bar.dart';
import 'package:mint_mobile/widgets/mint_chat_overlay.dart';

/// Stable card identifier for Maestro reachability + SerializedCardContext.
/// Locked per PHASE97_AUJOURDHUI_CARD_INVENTORY.md row 2 (W5 reachability).
const String _kCardId = 'cap_du_jour';

class CapDuJourBanner extends StatelessWidget {
  const CapDuJourBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MintStateProvider>().state;
    final cap = state?.currentCap;

    // Phase 97 W7 iter#3 (S001 fix) — Karpathy #2 simplicity-first :
    // wrap the existing populated/fallback content in a Column with
    // Key('card_cap_du_jour') and append MintCardActionBar. Zero new
    // state management. The action bar is `expanded: true` (always
    // visible) because the banner itself does not own a press-state
    // (Phase 96 W1 punted persistent press-state to a later iteration).
    final Widget body =
        cap == null ? const _CapBannerFallback() : _CapBannerCard(cap: cap);

    return Semantics(
      identifier: 'card_$_kCardId',
      container: true,
      child: Container(
        key: const Key('card_$_kCardId'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            body,
            MintCardActionBar(
              // Phase 97 W7 — Key allows Maestro `assertVisible: { id }` to
              // resolve the action-bar surface from cold-launch reachability
              // flows (bug__S001__cap_du_jour_action_bar_reachable.yaml).
              key: const Key('mint_card_action_bar'),
              sourceCard: _buildCardContext(context, cap),
              expanded: true,
              onExplain: () => MintChatOverlay.show(
                context,
                sourceCard: _buildCardContext(context, cap),
                intent: 'explain',
              ),
              onSimulate: () async {
                await _recordCapAcknowledgement(context, cap);
                if (!context.mounted) return;
                context.go('/explore?simulate=$_kCardId');
              },
              onReassure: () => MintChatOverlay.show(
                context,
                sourceCard: _buildCardContext(context, cap),
                intent: 'reassure',
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Phase 97 W7 — Karpathy #3 surgical : build the SerializedCardContext
  /// from financial_core values only (priorityScore + life event when the
  /// cap is populated). NO PII per CLAUDE.md never #8 + Phase 96 D-12
  /// (frozen+forbid backend mirror).
  SerializedCardContext _buildCardContext(
      BuildContext context, CapDecision? cap) {
    final profile = context.read<CoachProfileProvider>().profile;
    final Map<String, dynamic> facts = <String, dynamic>{};
    if (cap != null) {
      facts['cap_priority'] = cap.priorityScore;
      facts['cap_kind'] = cap.kind.name;
    }
    return SerializedCardContext(
      cardId: _kCardId,
      cardType: 'actionable',
      computedFacts: facts,
      groundingKeys: const <String>[],
      lifeEvent: cap?.kind.name ?? 'general',
      canton: profile?.canton,
      archetype: profile?.archetype.backendName,
    );
  }
}

Future<void> _recordCapAcknowledgement(
  BuildContext context,
  CapDecision? cap,
) async {
  if (cap == null) return;

  final memory = await CapMemoryStore.load();
  await CapMemoryStore.markServed(memory, cap.id);

  if (!context.mounted) return;
  final mintStateProvider = context.read<MintStateProvider>();
  final profile = context.read<CoachProfileProvider>().profile ??
      mintStateProvider.state?.profile;
  if (profile == null) return;
  await mintStateProvider.forceRecompute(profile);
}

class _CapBannerCard extends StatelessWidget {
  const _CapBannerCard({required this.cap});
  final CapDecision cap;

  static Key _capSemanticsKey(String capId) {
    switch (capId) {
      case 'rc_pillar_3a_2026':
        return const Key('cap_du_jour_rc_pillar_3a_2026');
      case 'rc_tax_optimization':
        return const Key('cap_du_jour_rc_tax_optimization');
      default:
        return Key('cap_du_jour_$capId');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: _capSemanticsKey(cap.id),
      identifier: 'cap_du_jour_${cap.id}',
      container: true,
      label: 'Cap du jour : ${cap.headline}',
      button: cap.ctaMode == CtaMode.route || cap.ctaMode == CtaMode.capture,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _onTap(context, cap),
          child: Ink(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.craie,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MintColors.success.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cap.headline,
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cap.whyNow,
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cap.ctaLabel,
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.success,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: MintColors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onTap(BuildContext context, CapDecision cap) async {
    await _recordCapAcknowledgement(context, cap);
    if (!context.mounted) return;

    switch (cap.ctaMode) {
      case CtaMode.route:
        final route = cap.ctaRoute;
        if (route == null || route.isEmpty) return;
        // Tab-root routes (Coach, Mon argent, Aujourd'hui, Explorer)
        // MUST use `go` so the StatefulShellRoute switches branch.
        // `push` would stack the screen on the current tab and break
        // the shell invariant (cf. Wave 1 RSoD fix, MEMORY.md
        // "12 context.push('/coach/chat') → .go()"). For simulator /
        // leaf routes (`/rachat-lpp`, `/rente-vs-capital`, etc.) push
        // remains the right call.
        if (_isTabRootRoute(route)) {
          context.go(route);
        } else {
          context.push(route);
        }
      case CtaMode.coach:
        final prompt = cap.coachPrompt ?? '';
        final target = prompt.isNotEmpty
            ? '/coach/chat?topic=${Uri.encodeComponent(prompt)}'
            : '/coach/chat';
        context.go(target);
      case CtaMode.capture:
        // /scan is a full screen outside the shell — push is correct.
        context.push('/scan');
    }
  }

  bool _isTabRootRoute(String route) {
    final path = route.split('?').first;
    return path == '/coach/chat' ||
        path == '/home' ||
        path == '/explore' ||
        path == '/mon-argent';
  }
}

class _CapBannerFallback extends StatelessWidget {
  const _CapBannerFallback();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      // Semantics(button: true) so screen readers announce a tappable
      // surface; GestureDetector instead of InkWell so the tap fires
      // without needing a Material ancestor (AujourdhuiScreen uses a
      // Scaffold but when embedded in the empty-state Column the ink
      // feedback was suppressed and users perceived the card as inert).
      child: Semantics(
        container: true,
        button: true,
        label: 'Parle-moi de toi, ouvre le coach',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/coach/chat'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MintColors.craie.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: MintColors.success.withValues(alpha: 0.18),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Parle-moi de toi',
                  style: MintTextStyles.titleMedium(
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dis-moi quelques mots sur ta situation, et je te montrerai '
                  'ce qui mérite ton attention aujourd’hui.',
                  style: MintTextStyles.bodyMedium(
                    color: MintColors.textSecondary,
                  ).copyWith(height: 1.4),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Ouvrir le coach',
                        style: MintTextStyles.bodyMedium(
                          color: MintColors.success,
                        ).copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: MintColors.success,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
