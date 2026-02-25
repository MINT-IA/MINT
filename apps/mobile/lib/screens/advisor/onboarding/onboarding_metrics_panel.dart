import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class OnboardingMetricsPanel extends StatelessWidget {
  final Map<String, int> control;
  final Map<String, int> challenge;
  final VoidCallback? onReset;

  const OnboardingMetricsPanel({
    super.key,
    required this.control,
    required this.challenge,
    this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: const Radius.circular(24)),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Onboarding Metrics',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              _buildVariantCard('Control', control),
              const SizedBox(height: 8),
              _buildVariantCard('Challenge', challenge),
              if (onReset != null) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: onReset,
                    child: const Text('Reset metrics'),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVariantCard(String title, Map<String, int> metrics) {
    final started = metrics['started'] ?? 0;
    final completed = metrics['completed'] ?? 0;
    final completion = started > 0
        ? '${((completed / started) * 100).toStringAsFixed(1)}%'
        : '0%';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MintColors.coachBubble,
        borderRadius: const BorderRadius.circular(12),
        border: Border.all(color: MintColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text('Starts: $started', style: GoogleFonts.inter(fontSize: 12)),
          Text('Completion: $completion',
              style: GoogleFonts.inter(fontSize: 12)),
        ],
      ),
    );
  }
}
