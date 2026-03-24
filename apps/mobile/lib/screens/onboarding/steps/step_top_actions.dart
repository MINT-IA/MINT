import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/services/analytics_events.dart';
import 'package:mint_mobile/services/analytics_service.dart';
import 'package:mint_mobile/services/coaching_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

/// Step 4 of the Smart Onboarding flow — Top 3 Actions.
///
/// Displays the 3 highest-priority coaching tips filtered by the user's
/// stress type (from Step 0) and profile. Tips come from [CoachingService].
///
/// Design: Material 3, Montserrat headings, Inter body, MintColors.
/// Compliance: educational tone, no banned terms, French informal "tu".
class StepTopActions extends StatelessWidget {
  final List<CoachingTip> tips;
  final VoidCallback onNext;
  final VoidCallback onBack;

  const StepTopActions({
    super.key,
    required this.tips,
    required this.onNext,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final top3 = tips.take(3).toList();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),

              // ── HEADER ─────────────────────────────────────────────
              MintEntrance(child: Text(
                'Tes 3 actions prioritaires',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              )),
              const SizedBox(height: 8),
              MintEntrance(delay: const Duration(milliseconds: 100), child: Text(
                'Basees sur ta situation, voici par ou commencer.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                  height: 1.4,
                ),
              )),
              const SizedBox(height: 24),

              // ── ACTION CARDS ───────────────────────────────────────
              Expanded(
                child: MintEntrance(delay: const Duration(milliseconds: 200), child: top3.isEmpty
                    ? Center(
                        child: Text(
                          'Complete ton profil pour recevoir des actions personnalisees.',
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: MintColors.textMuted,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                  itemCount: top3.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final tip = top3[index];
                    return _ActionCard(
                      index: index + 1,
                      tip: tip,
                      onTap: () {
                        AnalyticsService().trackEvent(
                          kEventTopActionTapped,
                          category: 'engagement',
                          data: {
                            'tip_id': tip.id,
                            'position': index,
                          },
                          screenName: 'smart_onboarding_top_actions',
                        );
                      },
                    );
                  },
                ),
              )),

              const SizedBox(height: 16),

              // ── NAVIGATION ──────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: onNext,
                  style: FilledButton.styleFrom(
                    backgroundColor: MintColors.primary,
                    foregroundColor: MintColors.white,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Continuer',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              MintEntrance(delay: const Duration(milliseconds: 300), child: Center(
                child: TextButton(
                  onPressed: onBack,
                  child: Text(
                    'Retour',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
              )),
              const SizedBox(height: 12),

              // ── DISCLAIMER ──────────────────────────────────────────
              MintEntrance(delay: const Duration(milliseconds: 400), child: Text(
                'Suggestions educatives. Ne constitue pas un conseil '
                'financier (LSFin). Consulte un·e specialiste pour un '
                'plan personnalise.',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              )),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final int index;
  final CoachingTip tip;
  final VoidCallback onTap;

  const _ActionCard({
    required this.index,
    required this.tip,
    required this.onTap,
  });

  Color _priorityColor(CoachingPriority priority) {
    return switch (priority) {
      CoachingPriority.haute => MintColors.error,
      CoachingPriority.moyenne => MintColors.warning,
      CoachingPriority.basse => MintColors.info,
    };
  }

  @override
  Widget build(BuildContext context) {
    final color = _priorityColor(tip.priority);

    return Semantics(
      button: true,
      label: tip.title,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: MintSurface(
          padding: const EdgeInsets.all(20),
          radius: 16,
          child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Index badge
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$index',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tip.title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    tip.action,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  if (tip.estimatedImpactChf != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Impact estime : ${CoachingService.formatChf(tip.estimatedImpactChf!)}',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Icon
            Icon(tip.icon, size: 22, color: MintColors.textMuted),
          ],
        ),
      ),
    ),
    );
  }
}
