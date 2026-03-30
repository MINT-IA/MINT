import 'package:flutter/material.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/theme/mint_text_styles.dart';
import 'package:mint_mobile/theme/mint_spacing.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';
import 'package:mint_mobile/widgets/premium/mint_entrance.dart';
import 'package:mint_mobile/widgets/premium/mint_surface.dart';

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
          S.of(context)!.portfolioAppBarTitle,
          style: MintTextStyles.headlineMedium().copyWith(fontSize: 18),
        ),
        centerTitle: false,
        elevation: 0,
        backgroundColor: MintColors.white,
        surfaceTintColor: MintColors.white,
      ),
      body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (hasDebt) ...[
              _buildSafeModeWarning(context),
              const SizedBox(height: 24),
            ],
            MintEntrance(child: _buildWealthSummary(context)),
            const SizedBox(height: 32),
            MintEntrance(delay: const Duration(milliseconds: 100), child: _buildReadinessIndex(context, profile)),
            const SizedBox(height: 32),
            MintEntrance(delay: const Duration(milliseconds: 200), child: _buildSectionHeader(S.of(context)!.portfolioRepartitionEnveloppe)),
            const SizedBox(height: 12),
            // P2-14: Show "—" to indicate no data, not fake amounts
            MintEntrance(delay: const Duration(milliseconds: 300), child: _buildAccountItem(S.of(context)!.portfolioLibrePlacement, '\u2014', icon: Icons.trending_up, color: MintColors.primary)),
            MintEntrance(delay: const Duration(milliseconds: 400), child: _buildAccountItem(S.of(context)!.portfolioLiePilier3a, '\u2014', icon: Icons.savings_outlined, color: MintColors.success)),
            _buildAccountItem(S.of(context)!.portfolioReserveFondsUrgence, '\u2014', icon: Icons.account_balance_wallet_outlined, color: MintColors.warning),
            const SizedBox(height: 32),
            SafeModeGate(
              hasDebt: hasDebt,
              lockedTitle: S.of(context)!.portfolioSafeModeLocked,
              lockedMessage: S.of(context)!.portfolioSafeModeBody,
              child: _buildCoachAdvice(context),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ))),
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
    // P2-14: No real readiness data available yet — show empty state
    // instead of hardcoded fake percentages (65%, 40%, 85%).
    return MintSurface(
      padding: const EdgeInsets.all(24),
      radius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(S.of(context)!.portfolioReadinessTitle, style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 18, color: MintColors.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Complète ton profil pour débloquer ton indice de préparation.', // TODO: i18n
                  style: MintTextStyles.bodySmall(color: MintColors.textMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWealthSummary(BuildContext context) {
    return MintSurface(
      tone: MintSurfaceTone.porcelaine,
      padding: const EdgeInsets.all(24),
      radius: 24,
      child: Column(
        children: [
          Text(
            S.of(context)!.portfolioValeurTotaleNette,
            style: MintTextStyles.bodyMedium().copyWith(fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: MintSpacing.sm),
          // P2-14: Show empty state instead of fake "CHF —" placeholder
          const Icon(Icons.account_balance_outlined, size: 32, color: MintColors.textMuted),
          const SizedBox(height: MintSpacing.sm),
          Text(
            'Aucune donnée patrimoniale renseignée.', // TODO: i18n
            style: MintTextStyles.bodySmall(color: MintColors.textMuted),
            textAlign: TextAlign.center,
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
    return MintSurface(
      padding: const EdgeInsets.all(16),
      radius: 16,
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
