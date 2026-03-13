import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

/// Simple web landing / home screen.
///
/// Displays a welcome message and quick-links to the main sections
/// (simulators, education, tools).
class WebHomeScreen extends StatelessWidget {
  const WebHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bienvenue sur Mint',
              style: GoogleFonts.outfit(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: MintColors.textPrimary,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Ta bo\u00eete \u00e0 outils pour comprendre tes finances en Suisse.',
              style: TextStyle(
                fontSize: 16,
                color: MintColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            _QuickLinkCard(
              icon: Icons.calculate_outlined,
              title: 'Simulateurs',
              subtitle: 'Tous les calculateurs\u00a0: 3a, leasing, hypoth\u00e8que, etc.',
              onTap: () => context.go('/tools'),
            ),
            const SizedBox(height: 16),
            _QuickLinkCard(
              icon: Icons.shield_outlined,
              title: 'Pr\u00e9voyance',
              subtitle: 'Tableau de bord retraite, projections, arbitrages.',
              onTap: () => context.go('/coach/dashboard'),
            ),
            const SizedBox(height: 16),
            _QuickLinkCard(
              icon: Icons.school_outlined,
              title: '\u00c9ducation',
              subtitle: 'Comprendre le syst\u00e8me suisse\u00a0: AVS, LPP, imp\u00f4ts.',
              onTap: () => context.go('/education/hub'),
            ),
            const SizedBox(height: 16),
            _QuickLinkCard(
              icon: Icons.person_outlined,
              title: 'Profil',
              subtitle: 'Ton profil financier et tes param\u00e8tres.',
              onTap: () => context.go('/profile'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickLinkCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _QuickLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MintColors.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: MintColors.lightBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: MintColors.primary, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: MintColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 14,
                        color: MintColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: MintColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
