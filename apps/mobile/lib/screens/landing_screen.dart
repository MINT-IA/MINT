// Phase 7 — L1.7 Landing v2 "calm promise surface".
// Phase 73 — Landing v3 éditorial (2-pers panel locked, PANEL-VERDICT.md).
//
// NON-NEGOTIABLE invariants (enforced by CI gates in tools/checks/):
//   • No `financial_core` / services / providers / models imports.
//   • No digits anywhere in this file.
//   • No retirement / banned-term vocabulary.
//
// Spec: .planning/phases/07-l1.7-landing-v2/CONTEXT.md §2 D-01..D-13
//       .planning/phases/73-landing-v3-editorial/PANEL-VERDICT.md §1-§4 (locked).
// Copy is LOCKED in ARB (landingV3Hero, landingV2CtaSober, landingV2LoginLink, landingV2Legal).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/widgets/beta/beta_program_disclosure_sheet.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _line1Opacity;
  late final Animation<double> _paragraphOpacity;
  late final Animation<Offset> _paragraphOffset;
  late final Animation<double> _ctaOpacity;
  late final Animation<double> _legalOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );

    // Line 1 opener — 500-900ms.
    _line1Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.28, curve: Curves.easeOutCubic),
    );
    // Promise — 1400-1900ms (arrives as the opener settles).
    _paragraphOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.44, 0.60, curve: Curves.easeOutCubic),
    );
    _paragraphOffset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_paragraphOpacity);
    // CTA — 2500-2800ms.
    _ctaOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.78, 0.88, curve: Curves.easeOutCubic),
    );
    // Legal footer — 2900-3200ms.
    _legalOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.90, 1.0, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mq = MediaQuery.of(context);
      if (mq.disableAnimations || mq.accessibleNavigation) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
      // First-launch beta disclosure (Apple TestFlight beta review +
      // FINMA fintech sandbox). One-shot per device install.
      // No-op when SharedPreferences flag is already set.
      BetaProgramDisclosureSheet.maybeShow(context);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context)!;
    void openOnboarding() => context.go('/onb');

    Widget ctaReveal(Widget child) {
      return AnimatedBuilder(
        animation: _ctaOpacity,
        child: child,
        builder: (context, child) {
          final isActive = _ctaOpacity.isCompleted;
          return IgnorePointer(
            ignoring: !isActive,
            child: ExcludeSemantics(
              excluding: !isActive,
              child: FadeTransition(
                opacity: _ctaOpacity,
                child: child,
              ),
            ),
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            // Phase 73 PANEL-VERDICT §3: maxWidth 480 (descendu de 560).
            constraints: const BoxConstraints(maxWidth: 480),
            child: Padding(
              // Phase 73 PANEL-VERDICT §3: padding horizontal 28, vertical 24.
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Wordmark — Align(centerLeft), letterSpacing 2 (pas 4),
                  // inkPrimary. Long-press → /auth/login (D-12 hidden affordance).
                  FadeTransition(
                    opacity: _line1Opacity,
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Semantics(
                        header: true,
                        label: 'MINT',
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onLongPress: () => context.go('/auth/login'),
                          child: Text(
                            'MINT',
                            style: MintTextStyles.brandLogo(
                              color: MintColors.inkPrimary,
                            ).copyWith(letterSpacing: 2),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 2. Spacer flex 3.
                  const Spacer(flex: 3),
                  // 3. Hero phrase — l10n.landingV3Hero, Gambarino italic 40pt
                  // w400, height 1.2, letterSpacing -0.4, inkPrimary, center.
                  // Phase 92-03 (FONT-05/07): swapped from GoogleFonts.fraunces
                  // to bundled MintTextStyles.displayGambarinoItalic40 (Plan
                  // 92-01 .otf + Plan 92-02 helper). Italic is synthesized at
                  // render time — see displayGambarinoItalic40 dartdoc.
                  FadeTransition(
                    opacity: _paragraphOpacity,
                    child: SlideTransition(
                      position: _paragraphOffset,
                      child: Semantics(
                        container: true,
                        label: l10n.landingV3Hero,
                        child: Text(
                          l10n.landingV3Hero,
                          textAlign: TextAlign.center,
                          style: MintTextStyles.displayGambarinoItalic40(
                            color: MintColors.inkPrimary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 4. Spacer flex 4.
                  const Spacer(flex: 4),
                  // 5. CTA primaire — FilledButton, RoundedRectangleBorder(14)
                  // (PAS StadiumBorder), 54pt, ink/porcelaine.
                  ctaReveal(
                    Semantics(
                      key: const Key('landing_talk_to_mint_cta'),
                      identifier: 'landing_talk_to_mint_cta',
                      container: true,
                      excludeSemantics: true,
                      button: true,
                      label: l10n.landingV2CtaSober,
                      onTap: openOnboarding,
                      child: FilledButton(
                        // lint-ignore: prefer_mint_cta
                        style: FilledButton.styleFrom(
                          backgroundColor: MintColors.inkPrimary,
                          foregroundColor: MintColors.porcelaineHero,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: MintTextStyles.titleMedium(
                            color: MintColors.porcelaineHero,
                          ),
                        ),
                        onPressed: openOnboarding,
                        child: Text(l10n.landingV2CtaSober),
                      ),
                    ),
                  ),
                  // 6. SizedBox 16.
                  const SizedBox(height: 16),
                  // 7. Login link — bodySmall(textSecondaryAaa), no underline.
                  ctaReveal(
                    Semantics(
                      button: true,
                      label: l10n.landingV2LoginLink,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.go('/auth/login'),
                        child: Text(
                          l10n.landingV2LoginLink,
                          textAlign: TextAlign.center,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondaryAaa,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 7-bis. SizedBox 12 + anonymous local-mode link. Keep this
                  // on /start so the router owns the first-run rollout switch.
                  const SizedBox(height: 12),
                  ctaReveal(
                    Semantics(
                      button: true,
                      label: l10n.landingV3AnonymousHomeLink,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => context.go('/start'),
                        child: Text(
                          l10n.landingV3AnonymousHomeLink,
                          textAlign: TextAlign.center,
                          style: MintTextStyles.bodySmall(
                            color: MintColors.textSecondaryAaa,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // 8. Spacer flex 1.
                  const Spacer(flex: 1),
                  // 9. Legal footer — labelSmall(textMutedAaa), center.
                  FadeTransition(
                    opacity: _legalOpacity,
                    child: Text(
                      l10n.landingV2Legal,
                      textAlign: TextAlign.center,
                      style: MintTextStyles.labelSmall(
                        color: MintColors.textMutedAaa,
                      ),
                    ),
                  ),
                  // 10. SizedBox 8.
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
