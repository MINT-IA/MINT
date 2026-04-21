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
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'package:mint_mobile/models/cap_decision.dart';
import 'package:mint_mobile/providers/mint_state_provider.dart';
import 'package:mint_mobile/theme/colors.dart';

class CapDuJourBanner extends StatelessWidget {
  const CapDuJourBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<MintStateProvider>().state;
    final cap = state?.currentCap;

    if (cap == null) {
      return const _CapBannerFallback();
    }
    return _CapBannerCard(cap: cap);
  }
}

class _CapBannerCard extends StatelessWidget {
  const _CapBannerCard({required this.cap});
  final CapDecision cap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
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
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  cap.whyNow,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        cap.ctaLabel,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MintColors.success,
                        ),
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

  void _onTap(BuildContext context, CapDecision cap) {
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
        path == '/argent';
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
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Dis-moi quelques mots sur ta situation, et je te montrerai '
                  'ce qui mérite ton attention aujourd’hui.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: MintColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'Ouvrir le coach',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: MintColors.success,
                        ),
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
