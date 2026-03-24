import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/analytics_events.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';

/// Step 5 of the Smart Onboarding flow — Next Step (completion).
///
/// Offers two paths:
/// 1. "Affiner mon profil" → enrichment flow (more data = better projection)
/// 2. "Voir mon dashboard" → home screen with initial projection
///
/// Design: Material 3, Montserrat headings, Inter body, MintColors.
/// Compliance: educational tone, no banned terms, French informal "tu".
class StepNextStep extends StatelessWidget {
  final double confidenceScore;
  final VoidCallback onEnrich;
  final VoidCallback onDashboard;
  final VoidCallback? onCheckin;

  const StepNextStep({
    super.key,
    required this.confidenceScore,
    required this.onEnrich,
    required this.onDashboard,
    this.onCheckin,
  });

  @override
  Widget build(BuildContext context) {
    final confidencePct = confidenceScore.round();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(flex: 2),

              // ── SUCCESS ICON ────────────────────────────────────────
              MintEntrance(child: Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: MintColors.success.withAlpha(25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    size: 40,
                    color: MintColors.success,
                  ),
                ),
              )),
              const SizedBox(height: 24),

              // ── HEADING ─────────────────────────────────────────────
              MintEntrance(delay: Duration(milliseconds: 100), child: Text(
                'Ton premier bilan est pret',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 12),
              MintEntrance(delay: Duration(milliseconds: 200), child: Text(
                'Precision actuelle : $confidencePct%. '
                'Plus tu completes ton profil, plus les projections '
                'seront fiables.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )),

              const Spacer(flex: 3),

              // ── PRIMARY CTA — enrich ────────────────────────────────
              MintEntrance(delay: Duration(milliseconds: 300), child: Semantics(
                button: true,
                label: 'Affiner mon profil',
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                    AnalyticsService().trackEvent(
                      kEventEnrichmentStarted,
                      category: 'conversion',
                      screenName: 'smart_onboarding_next_step',
                    );
                    onEnrich();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Affiner mon profil',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              )),
              const SizedBox(height: 12),

              // ── SECONDARY CTA — dashboard ───────────────────────────
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    AnalyticsService().trackEvent(
                      kEventOnboardingCompleted,
                      category: 'conversion',
                      screenName: 'smart_onboarding_next_step',
                    );
                    onDashboard();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: MintColors.textPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    side: const BorderSide(
                      color: MintColors.border,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Voir mon dashboard',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (onCheckin != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      AnalyticsService().trackEvent(
                        'first_checkin_from_onboarding',
                        category: 'conversion',
                        screenName: 'smart_onboarding_next_step',
                      );
                      onCheckin!();
                    },
                    icon: const Icon(Icons.receipt_long_rounded, size: 18),
                    label: Text(
                      'Faire mon premier check-in',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: MintColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),

              // ── DISCLAIMER ──────────────────────────────────────────
              MintEntrance(delay: Duration(milliseconds: 400), child: Text(
                'Outil educatif simplifie. Ne constitue pas un conseil '
                'financier (LSFin). '
                'Sources: LAVS art. 34, LPP art. 14-16, OPP3 art. 7.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
