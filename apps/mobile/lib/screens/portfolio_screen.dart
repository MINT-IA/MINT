import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mint_mobile/l10n/app_localizations.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/models/profile.dart';
import 'package:mint_mobile/providers/profile_provider.dart';
import 'package:provider/provider.dart';
import 'package:mint_mobile/widgets/common/safe_mode_gate.dart';

class PortfolioScreen extends StatelessWidget {
  const PortfolioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context)!;
    final profile = context.watch<ProfileProvider>().profile;
    final hasDebt = profile?.hasDebt ?? false;

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                s.portfolioTitle,
                style: GoogleFonts.montserrat(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: MintColors.white,
                ),
              ),
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [MintColors.primary, MintColors.primaryLight],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (hasDebt) ...[
                    _buildSafeModeWarning(context),
                    const SizedBox(height: 24),
                  ],
                  _buildWealthSummary(context),
                  const SizedBox(height: 32),
                  _buildReadinessIndex(context, profile),
                  const SizedBox(height: 32),
                  _buildSectionHeader(s.portfolioEnvelopeSection),
                  const SizedBox(height: 12),
                  _buildAccountItem(s.portfolioAccountFree, 'CHF\u00a073\'508.90', icon: Icons.trending_up, color: MintColors.primary),
                  _buildAccountItem(s.portfolioAccountLinked, 'CHF\u00a018\'369.74', icon: Icons.savings_outlined, color: MintColors.success),
                  _buildAccountItem(s.portfolioAccountReserved, 'CHF\u00a010\'800.00', icon: Icons.account_balance_wallet_outlined, color: MintColors.warning),
                  const SizedBox(height: 32),
                  SafeModeGate(
                    hasDebt: hasDebt,
                    lockedTitle: s.portfolioSafeModeLockTitle,
                    lockedMessage: s.portfolioSafeModeLockMessage,
                    child: _buildCoachAdvice(context),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
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
              S.of(context)!.portfolioDebtAlert,
              style: const TextStyle(fontSize: 13, color: MintColors.error, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessIndex(BuildContext context, Profile? profile) {
    final s = S.of(context)!;
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
          Text(s.portfolioReadinessTitle, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _readinessRow(s.portfolioReadinessRetirement, 0.65),
          const SizedBox(height: 12),
          _readinessRow(s.portfolioReadinessProperty, 0.40),
          const SizedBox(height: 12),
          _readinessRow(s.portfolioReadinessFamily, 0.85),
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

  Widget _buildWealthSummary(BuildContext context) {
    final s = S.of(context)!;
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
            s.portfolioTotalNetValue,
            style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          Text(
            'CHF\u00a0102\'678.64',
            style: GoogleFonts.montserrat(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.trending_up, color: MintColors.success, size: 16),
              const SizedBox(width: 4),
              Text(
                s.portfolioTodayChange,
                style: const TextStyle(color: MintColors.success, fontWeight: FontWeight.w600, fontSize: 13),
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
              S.of(context)!.portfolioCoachAdvice,
              style: const TextStyle(fontSize: 14, color: MintColors.textSecondary, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
