// Phase 7 — L1.7 Landing v2 "calm promise surface".
//
// NON-NEGOTIABLE invariants (enforced by CI gates in tools/checks/):
//   • No `financial_core` / services / providers / models imports.
//   • No digits anywhere in this file.
//   • No retirement / banned-term vocabulary.
//
// Spec: .planning/phases/07-l1.7-landing-v2/CONTEXT.md §2 D-01..D-13.
// Copy is LOCKED in ARB (landingV2Paragraph/Cta/Privacy/Legal).

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _line1Opacity;
  late final Animation<double> _line2Opacity;
  late final Animation<double> _paragraphOpacity;
  late final Animation<Offset> _paragraphOffset;
  late final Animation<double> _ctaOpacity;
  late final Animation<double> _legalOpacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5000),
    );

    // Line 1 — fade in at 800-1200ms of 5000ms.
    _line1Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.16, 0.24, curve: Curves.easeOutCubic),
    );
    // Line 2 — fade in at 3500-3900ms of 5000ms.
    _line2Opacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.70, 0.78, curve: Curves.easeOutCubic),
    );
    // Promise paragraph — 4000-4400ms.
    _paragraphOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.80, 0.88, curve: Curves.easeOutCubic),
    );
    _paragraphOffset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(_paragraphOpacity);
    // CTA — 4400-4700ms.
    _ctaOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.88, 0.94, curve: Curves.easeOutCubic),
    );
    // Legal footer — 4700-5000ms.
    _legalOpacity = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.94, 1.0, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mq = MediaQuery.of(context);
      if (mq.disableAnimations || mq.accessibleNavigation) {
        _controller.value = 1.0;
      } else {
        _controller.forward();
      }
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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: MintColors.warmWhite,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Spacer(flex: 2),
                  // Wordmark — long-press routes to /auth/login (D-12 hidden affordance).
                  Center(
                    child: Semantics(
                      header: true,
                      label: 'MINT',
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onLongPress: () => context.go('/auth/login'),
                        child: Text(
                          'MINT',
                          style: textTheme.titleMedium?.copyWith(
                            color: MintColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 4,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Line 1 — money taboo
                  FadeTransition(
                    opacity: _line1Opacity,
                    child: Text(
                      l10n.anonymousIntentLine1,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: MintColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Line 2 — even to oneself
                  FadeTransition(
                    opacity: _line2Opacity,
                    child: Text(
                      l10n.anonymousIntentLine2,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 18,
                        fontWeight: FontWeight.w400,
                        color: MintColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Promise — single sentence (POLISH-01).
                  FadeTransition(
                    opacity: _paragraphOpacity,
                    child: SlideTransition(
                      position: _paragraphOffset,
                      child: Semantics(
                        container: true,
                        label: l10n.landingV2PromiseSober,
                        child: Text(
                          l10n.landingV2PromiseSober,
                          textAlign: TextAlign.center,
                          style: textTheme.headlineSmall?.copyWith(
                            color: MintColors.textPrimary,
                            fontWeight: FontWeight.w500,
                            height: 1.45,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(flex: 1),
                  // CTA (POLISH-01 — no privacy subtitle).
                  FadeTransition(
                    opacity: _ctaOpacity,
                    child: Semantics(
                      button: true,
                      label: l10n.landingV2CtaSober,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: MintColors.textPrimary,
                          foregroundColor: MintColors.craie,
                          minimumSize: const Size.fromHeight(56),
                          shape: const StadiumBorder(),
                          textStyle: textTheme.labelLarge,
                        ),
                        onPressed: () => context.go('/coach/chat'),
                        child: Text(l10n.landingV2CtaSober),
                      ),
                    ),
                  ),
                  const Spacer(flex: 2),
                  // Legal footer (D-04).
                  FadeTransition(
                    opacity: _legalOpacity,
                    child: Text(
                      l10n.landingV2Legal,
                      textAlign: TextAlign.center,
                      style: textTheme.bodySmall?.copyWith(
                        color: MintColors.textMutedAaa,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // AUTH-01: Visible login entry point
                  FadeTransition(
                    opacity: _legalOpacity,
                    child: GestureDetector(
                      onTap: () => context.go('/auth/login'),
                      child: Text(
                        l10n.landingV2LoginLink,
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: MintColors.textPrimary,
                          decoration: TextDecoration.underline,
                          decorationColor: MintColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
