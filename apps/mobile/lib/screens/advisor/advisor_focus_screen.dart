import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';

class AdvisorSessionFocusScreen extends StatelessWidget {
  const AdvisorSessionFocusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back),
                padding: EdgeInsets.zero,
                alignment: Alignment.centerLeft,
              ),
              const SizedBox(height: 32),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: MintColors.appleSurface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'AUJOURD\'HUI',
                  style: GoogleFonts.montserrat(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: MintColors.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Nos objectifs de session',
                style: GoogleFonts.montserrat(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sur la base de ton profil, nous allons nous concentrer sur ces 3 axes pour maximiser ton impact.',
                style: TextStyle(
                    fontSize: 16, color: MintColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 40),
              _buildFocusTile(Icons.trending_up, 'Optimisation fiscale 3a',
                  'Comment réduire ta charge fiscale annuelle.'),
              _buildFocusTile(Icons.account_balance, 'Intérêts composés',
                  'L\'effet de levier sur ton épargne long terme.'),
              _buildFocusTile(Icons.shield_outlined, 'Prévention & Risques',
                  'Solidifier tes bases financières.'),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => context.push('/advisor'),
                  child: const Text('C\'est parti'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFocusTile(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: MintColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: MintColors.border),
            ),
            child: Icon(icon, color: MintColors.primary, size: 24),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: MintColors.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 14, color: MintColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
