import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/providers/subscription_provider.dart';

/// Beautiful bottom sheet displayed when a free user taps a Coach-locked feature.
///
/// Shows the value proposition of MINT Coach (4.90 CHF/mois):
/// - Feature list with checkmarks
/// - 14-day free trial CTA
/// - Restore purchases option
/// - Required LSFin disclaimer
///
/// Usage:
/// ```dart
/// CoachPaywallSheet.show(context);
/// ```
class CoachPaywallSheet extends StatelessWidget {
  const CoachPaywallSheet({super.key});

  /// Show the paywall as a modal bottom sheet.
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ChangeNotifierProvider.value(
        value: context.read<SubscriptionProvider>(),
        child: const CoachPaywallSheet(),
      ),
    );
  }

  static const List<_FeatureItem> _features = [
    _FeatureItem('Dashboard trajectoire', 'Score + projection dans le temps'),
    _FeatureItem('Forecast adaptatif', '3 scenarios : prudent, base, favorable'),
    _FeatureItem('Check-in mensuel', 'Point de situation personnalise'),
    _FeatureItem('Score evolutif', 'Tendance et progression continue'),
    _FeatureItem('Alertes proactives', 'Notifications sur tes finances'),
    _FeatureItem('Historique progression', 'Suivi de ton parcours complet'),
    _FeatureItem('Profil couple', 'Analyse financiere a deux'),
    _FeatureItem('Coach LLM', 'Assistant IA personnel (BYOK)'),
    _FeatureItem('Scenarios "Et si..."', 'Simule tes decisions de vie'),
    _FeatureItem('Export PDF', 'Rapport complet a telecharger'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: MintColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with gradient
          _buildHeader(context),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomPadding + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 20),

                  // Price badge
                  _buildPriceBadge(),

                  const SizedBox(height: 24),

                  // Feature list
                  ..._features.map(_buildFeatureRow),

                  const SizedBox(height: 24),

                  // Trial badge
                  _buildTrialBadge(),

                  const SizedBox(height: 16),

                  // Primary CTA
                  _buildPrimaryCTA(context),

                  const SizedBox(height: 12),

                  // Restore purchases
                  _buildRestoreButton(context),

                  const SizedBox(height: 16),

                  // Disclaimer
                  _buildDisclaimer(),

                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MintColors.primary,
            MintColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle + close button row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Close button
              GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Debloque MINT Coach',
            style: GoogleFonts.montserrat(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Ton coach financier personnel',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w400,
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MintColors.coachAccent.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '4.90 CHF',
            style: GoogleFonts.montserrat(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MintColors.primary,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '/mois',
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: MintColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureRow(_FeatureItem feature) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: const EdgeInsets.only(top: 2),
            child: const Icon(
              Icons.check_circle_rounded,
              color: MintColors.scoreExcellent,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                Text(
                  feature.subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textMuted,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrialBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        color: MintColors.scoreExcellent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.card_giftcard_rounded,
            color: MintColors.scoreExcellent,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            'Essai gratuit 14 jours',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.scoreExcellent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryCTA(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: () async {
          final provider = context.read<SubscriptionProvider>();
          final success = await provider.startTrial();
          if (success && context.mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Essai gratuit active ! Profite de MINT Coach pendant 14 jours.'),
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: MintColors.primary,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: Text(
          'Commencer l\'essai gratuit',
          style: GoogleFonts.montserrat(
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildRestoreButton(BuildContext context) {
    return TextButton(
      onPressed: () async {
        final provider = context.read<SubscriptionProvider>();
        await provider.restore();
        if (context.mounted) {
          final isCoach = provider.isCoach;
          if (isCoach) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Abonnement restaure avec succes !')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Aucun achat precedent trouve.')),
            );
          }
        }
      },
      child: Text(
        'Restaurer un achat',
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: MintColors.textSecondary,
          decoration: TextDecoration.underline,
        ),
      ),
    );
  }

  Widget _buildDisclaimer() {
    return Text(
      'Outil educatif — ne constitue pas un conseil financier. LSFin. '
      'Tu peux annuler a tout moment depuis les reglages de ton compte.',
      textAlign: TextAlign.center,
      style: GoogleFonts.inter(
        fontSize: 11,
        color: MintColors.textMuted,
        height: 1.4,
      ),
    );
  }
}

class _FeatureItem {
  final String title;
  final String subtitle;

  const _FeatureItem(this.title, this.subtitle);
}
