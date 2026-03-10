import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/models/coach_profile.dart';
import 'package:mint_mobile/providers/coach_profile_provider.dart';
import 'package:mint_mobile/services/visibility_score_service.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/widgets/pulse/visibility_score_card.dart';
import 'package:mint_mobile/widgets/pulse/pulse_action_card.dart';
import 'package:mint_mobile/widgets/pulse/comprendre_section.dart';
import 'package:mint_mobile/widgets/pulse/pulse_disclaimer.dart';

// ────────────────────────────────────────────────────────────
//  PULSE SCREEN — S48 / Phase 0
// ────────────────────────────────────────────────────────────
//
//  Dashboard scannable : l'utilisateur voit sa situation
//  SANS rien taper. Data-first, pas chat-first.
//
//  Contenu :
//  1. Score de visibilite financiere (4 axes, 25/25/25/25)
//  2. Narrative courte (1 phrase)
//  3. Actions prioritaires (max 3 enrichment prompts)
//  4. Section "Comprendre" (liens vers simulateurs)
//  5. Micro-disclaimer inline (toujours visible)
//
//  Le score mesure ce que l'utilisateur SAIT de sa situation,
//  pas la qualite de sa situation. "Visibilite", pas "sante".
//
//  Aucun terme banni (garanti, certain, optimal, meilleur...).
//  CTA educatifs : "Simuler", "Explorer", jamais prescriptif.
// ────────────────────────────────────────────────────────────

class PulseScreen extends StatelessWidget {
  const PulseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final coachProvider = context.watch<CoachProfileProvider>();

    if (!coachProvider.hasProfile) {
      return _buildEmptyState(context);
    }

    final profile = coachProvider.profile!;
    final visibilityScore = VisibilityScoreService.compute(profile);

    return CustomScrollView(
      slivers: [
        // ── SliverAppBar avec gradient ──────────────────────
        _buildAppBar(context, profile),

        // ── Contenu ─────────────────────────────────────────
        SliverToBoxAdapter(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),

              // 1. Score de visibilite
              VisibilityScoreCard(score: visibilityScore),
              const SizedBox(height: 24),

              // 2. Actions prioritaires
              if (visibilityScore.actions.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Tes priorites',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Gagne en visibilite sur ta situation',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    children: visibilityScore.actions
                        .map((a) => PulseActionCard(action: a))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
              ],

              // 3. Section Comprendre
              const ComprendreSection(),
              const SizedBox(height: 24),

              // 4. Disclaimer (toujours visible)
              const PulseDisclaimer(),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ],
    );
  }

  SliverAppBar _buildAppBar(BuildContext context, CoachProfile profile) {
    final firstName = profile.firstName ?? 'toi';

    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: MintColors.primary,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
        title: Text(
          'Bonjour $firstName',
          style: GoogleFonts.outfit(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                MintColors.primary,
                MintColors.primaryLight,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 100,
          floating: false,
          pinned: true,
          backgroundColor: MintColors.primary,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 20, bottom: 14),
            title: Text(
              'Bienvenue sur MINT',
              style: GoogleFonts.outfit(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            background: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MintColors.primary,
                    MintColors.primaryLight,
                  ],
                ),
              ),
            ),
          ),
        ),
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_outlined,
                    size: 64,
                    color: MintColors.textMuted.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Commence par remplir ton profil',
                    style: GoogleFonts.outfit(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Quelques questions suffisent pour obtenir '
                    'ta premiere estimation de visibilite financiere.',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: MintColors.textSecondary,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    onPressed: () {
                      context.push('/onboarding/smart');
                    },
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('Demarrer'),
                    style: FilledButton.styleFrom(
                      backgroundColor: MintColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const PulseDisclaimer(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
