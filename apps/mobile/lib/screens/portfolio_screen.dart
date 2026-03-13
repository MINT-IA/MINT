import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>().profile;
    final hasDebt = profile?.hasDebt ?? false;

    return Scaffold(
      backgroundColor: MintColors.background,
      appBar: AppBar(
        title: Text(
          'Mon Patrimoine',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700, fontSize: 16, letterSpacing: 1),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: MintColors.background,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasDebt) ...[
              _buildSafeModeWarning(),
              const SizedBox(height: 24),
            ],
            _buildWealthSummary(),
            const SizedBox(height: 32),
            _buildReadinessIndex(profile),
            const SizedBox(height: 32),
            _buildSectionHeader('Répartition par Enveloppe'),
            const SizedBox(height: 12),
            _buildAccountItem('Libre (Compte Placement)', 'CHF 73\'508.90', icon: Icons.trending_up, color: MintColors.primary),
            _buildAccountItem('Lié (Pilier 3a)', 'CHF 18\'369.74', icon: Icons.savings_outlined, color: MintColors.success),
            _buildAccountItem('Réservé (Fonds d\'urgence)', 'CHF 10\'800.00', icon: Icons.account_balance_wallet_outlined, color: MintColors.warning),
            const SizedBox(height: 32),
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: 'Priorite au desendettement',
              lockedMessage:
                  'Les conseils d\'allocation sont desactives en mode protection. '
                  'Ta priorite est de reduire tes dettes avant de reequilibrer ton patrimoine.',
              child: _buildCoachAdvice(),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeModeWarning() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: MintColors.error),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Alerte Dettes : Ta priorité absolue est le désendettement avant tout réinvestissement.',
              style: TextStyle(fontSize: 13, color: MintColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessIndex(Profile? profile) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Readiness Index (Milestones)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _readinessRow('Pérennité Retraite', 0.65),
          const SizedBox(height: 12),
          _readinessRow('Projet Immobilier', 0.40),
          const SizedBox(height: 12),
          _readinessRow('Protection Famille', 0.85),
        ],
      ),
    );
  }

  Widget _readinessRow(String label, double value) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: MintColors.textSecondary)),
            Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: value,
          backgroundColor: MintColors.background,
          valueColor: AlwaysStoppedAnimation<Color>(value < 0.5 ? MintColors.warning : MintColors.success),
          minHeight: 4,
          borderRadius: BorderRadius.circular(2),
        ),
      ],
    );
  }

  Widget _buildWealthSummary() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: MintColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          const Text(
            'Valeur Totale Neté',
            style: TextStyle(fontSize: 14, color: MintColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'CHF 102\'678.64',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.trending_up, color: MintColors.success, size: 16),
              SizedBox(width: 4),
              Text(
                '509.30 (0.50%) aujourd\'hui',
                style: TextStyle(color: MintColors.success, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: MintColors.textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildAccountItem(String title, String balance, {required IconData icon, required Color color}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.border.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
          ),
          Text(
            balance,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachAdvice() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.1)),
      ),
      child: const Row(
        children: [
          Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Ton allocation est saine. Pense à rééquilibrer ton 3a prochainement.',
              style: TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
