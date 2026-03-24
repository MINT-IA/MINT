import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
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
          'Mon patrimoine',
          style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasDebt) ...[
              _buildSafeModeWarning(context),
              const SizedBox(height: 24),
            ],
            _buildWealthSummary(),
            const SizedBox(height: 32),
            _buildReadinessIndex(context, profile),
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
              child: _buildCoachAdvice(context),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildSafeModeWarning(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.error.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: MintColors.error),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              S.of(context)!.portfolioAlerteDettes,
              style: MintTextStyles.bodySmall(color: MintColors.error).copyWith(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessIndex(BuildContext context, Profile? profile) {
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
          Text(S.of(context)!.portfolioReadinessTitle, style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _readinessRow(S.of(context)!.portfolioPerennite, 0.65),
          const SizedBox(height: 12),
          _readinessRow(S.of(context)!.portfolioProjetImmo, 0.40),
          const SizedBox(height: 12),
          _readinessRow(S.of(context)!.portfolioProtectionFamille, 0.85),
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
            Text(label, style: MintTextStyles.bodySmall()),
            Text('${(value * 100).toInt()}%', style: MintTextStyles.bodySmall().copyWith(fontWeight: FontWeight.bold)),
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
          Text(
            'Valeur Totale Neté',
            style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: MintSpacing.sm),
          Semantics(
            label: 'CHF 102\'678.64',
            child: Text(
              'CHF 102\'678.64',
              style: MintTextStyles.displayMedium(),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, color: MintColors.success, size: 16),
              const SizedBox(width: 4),
              Text(
                '509.30 (0.50%) aujourd\'hui',
                style: MintTextStyles.bodySmall(color: MintColors.success).copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: MintTextStyles.bodyMedium(color: MintColors.textPrimary).copyWith(fontWeight: FontWeight.w600),
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
              style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
            ),
          ),
          Text(
            balance,
            style: MintTextStyles.titleMedium().copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }

  Widget _buildCoachAdvice(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: MintColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: MintColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.auto_awesome_outlined, color: MintColors.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              S.of(context)!.portfolioAllocationSaine,
              style: MintTextStyles.bodyMedium(),
            ),
          ),
        ],
      ),
    );
  }
}
