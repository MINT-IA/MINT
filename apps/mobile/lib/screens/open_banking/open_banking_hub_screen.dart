import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:mint_mobile/theme/colors.dart';
import 'package:mint_mobile/services/open_banking_service.dart';
import 'package:mint_mobile/l10n/app_localizations.dart' show S;

// ────────────────────────────────────────────────────────────
//  OPEN BANKING HUB SCREEN — Sprint S14
// ────────────────────────────────────────────────────────────
//
// Main entry point for the Open Banking feature.
// Fully built but behind a FINMA consultation gate.
// All data is mock/demo — no real API calls.
//
// Compliance: FINMA gate banner, nLPD, read-only,
// no banned terms, disclaimer on every screen.
// ────────────────────────────────────────────────────────────

class OpenBankingHubScreen extends StatelessWidget {
  const OpenBankingHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = S.of(context)!;
    final accounts = OpenBankingService.getMockAccounts();
    final totalBalance = OpenBankingService.getTotalBalance();
    final summary = OpenBankingService.getMonthlySummary();
    final categories = OpenBankingService.computeCategoryBreakdown();

    return Scaffold(
      backgroundColor: MintColors.background,
      body: CustomScrollView(
        slivers: [
          _buildAppBar(context, l),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildFinmaGateBanner(l),
                const SizedBox(height: 12),
                _buildDemoModeBadge(l),
                const SizedBox(height: 16),
                _buildHeader(l),
                const SizedBox(height: 24),

                // Connected accounts
                _buildSectionTitle(l.openBankingHubSectionAccounts, Icons.account_balance),
                const SizedBox(height: 12),
                ...accounts.map((acc) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAccountCard(acc, l),
                    )),
                _buildAddBankButton(l),
                const SizedBox(height: 28),

                // Financial overview
                _buildSectionTitle(l.openBankingHubSectionOverview, Icons.insights),
                const SizedBox(height: 12),
                _buildTotalBalanceCard(totalBalance, l),
                const SizedBox(height: 12),
                _buildIncomeExpenseBar(summary, l),
                const SizedBox(height: 12),
                _buildTopCategories(categories, l),
                const SizedBox(height: 28),

                // Quick links
                _buildSectionTitle(l.openBankingHubSectionNavigation, Icons.link),
                const SizedBox(height: 12),
                _buildQuickLinkTile(
                  context,
                  icon: Icons.receipt_long,
                  title: l.openBankingHubViewTransactions,
                  subtitle: l.openBankingHubTransactionsSubtitle,
                  route: '/open-banking/transactions',
                ),
                const SizedBox(height: 10),
                _buildQuickLinkTile(
                  context,
                  icon: Icons.privacy_tip_outlined,
                  title: l.openBankingHubManageConsents,
                  subtitle: l.openBankingHubConsentsSubtitle,
                  route: '/open-banking/consents',
                ),
                const SizedBox(height: 28),

                // bLink badge
                _buildBlinkBadge(l),
                const SizedBox(height: 16),

                // Disclaimer
                _buildDisclaimer(l),
                const SizedBox(height: 100),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── App Bar ────────────────────────────────────────────────

  Widget _buildAppBar(BuildContext context, S l) {
    return SliverAppBar(
      pinned: true,
      backgroundColor: MintColors.background,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: MintColors.textPrimary),
        onPressed: () => context.pop(),
      ),
      title: Text(
        l.openBankingHubTitle,
        style: GoogleFonts.montserrat(
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 1.5,
          color: MintColors.textMuted,
        ),
      ),
    );
  }

  // ── FINMA Gate Banner ──────────────────────────────────────

  Widget _buildFinmaGateBanner(S l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.disclaimerBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.amberWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline, color: MintColors.amberDark, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.openBankingHubFinmaTitle,
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: MintColors.amberDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l.openBankingHubFinmaBody,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.amberDark,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Demo mode badge ──────────────────────────────────────

  Widget _buildDemoModeBadge(S l) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: MintColors.neutralBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MintColors.neutralBg),
        ),
        child: Text(
          l.openBankingHubDemoMode,
          style: GoogleFonts.montserrat(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: MintColors.blueDark,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────

  Widget _buildHeader(S l) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: MintColors.accentPastel,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.account_balance,
            color: MintColors.tealLight,
            size: 28,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open Banking',
                style: GoogleFonts.montserrat(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l.openBankingHubSubtitle,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: MintColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Section title ──────────────────────────────────────────

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MintColors.textMuted),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: MintColors.textMuted,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }

  // ── Account Card ───────────────────────────────────────────

  Widget _buildAccountCard(BankAccount account, S l) {
    final avatarColor = _bankColor(account.bankId);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: MintColors.primary.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
        border:
            Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Row(
        children: [
          // Bank avatar
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                OpenBankingService.getBankInitials(account.bankName),
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: avatarColor,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          // Account details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${account.bankName} \u2022 ${account.accountName}',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account.maskedIban,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: MintColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          // Balance
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                OpenBankingService.formatChf(account.balance),
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: MintColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatSyncTime(account.lastSync, l),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: MintColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatSyncTime(DateTime lastSync, S l) {
    final diff = DateTime.now().difference(lastSync);
    if (diff.inMinutes < 60) return l.openBankingHubSyncMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return l.openBankingHubSyncHoursAgo(diff.inHours);
    return l.openBankingHubSyncDaysAgo(diff.inDays);
  }

  Color _bankColor(String bankId) {
    switch (bankId) {
      case 'ubs':
        return MintColors.redMedium;
      case 'postfinance':
        return MintColors.warningText;
      case 'raiffeisen':
        return MintColors.warning;
      case 'credit_suisse':
        return MintColors.blueMaterial900;
      case 'bcv':
        return MintColors.greenDark;
      case 'bcge':
        return MintColors.tealLight;
      case 'zkb':
        return MintColors.categoryBlue;
      case 'neon':
        return MintColors.cyan;
      case 'yuh':
        return MintColors.categoryPurple;
      default:
        return MintColors.textMuted;
    }
  }

  // ── Add Bank Button (disabled) ─────────────────────────────

  Widget _buildAddBankButton(S l) {
    return Tooltip(
      message: l.openBankingHubFinmaTooltip,
      child: Opacity(
        opacity: 0.5,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: MintColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: MintColors.border.withOpacity(0.4), width: 0.8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.add_circle_outline,
                  color: MintColors.textMuted, size: 20),
              const SizedBox(width: 10),
              Text(
                l.openBankingHubAddBank,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: MintColors.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Icon(Icons.lock_outline,
                  color: MintColors.warningText, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Total Balance Card ─────────────────────────────────────

  Widget _buildTotalBalanceCard(double total, S l) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            MintColors.primary.withOpacity(0.06),
            MintColors.appleSurface.withOpacity(0.3),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border:
            Border.all(color: MintColors.border.withOpacity(0.4), width: 0.8),
      ),
      child: Column(
        children: [
          Text(
            l.openBankingHubTotalBalance,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: MintColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            OpenBankingService.formatChf(total),
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l.openBankingHubAccountsConnected,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: MintColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }

  // ── Income / Expense Bar ───────────────────────────────────

  Widget _buildIncomeExpenseBar(Map<String, double> summary, S l) {
    final income = summary['income'] ?? 0;
    final expenses = summary['expenses'] ?? 0;
    final maxVal = income > expenses ? income : expenses;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        children: [
          // Income
          _buildBarRow(
            label: l.openBankingHubIncome,
            value: income,
            maxValue: maxVal,
            color: MintColors.success,
          ),
          const SizedBox(height: 12),
          // Expenses
          _buildBarRow(
            label: l.openBankingHubExpenses,
            value: expenses,
            maxValue: maxVal,
            color: MintColors.error,
          ),
          const SizedBox(height: 12),
          const Divider(height: 1),
          const SizedBox(height: 12),
          // Net
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                l.openBankingHubNetSavings,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: MintColors.textPrimary,
                ),
              ),
              Text(
                OpenBankingService.formatChf(summary['net'] ?? 0),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: (summary['net'] ?? 0) >= 0
                      ? MintColors.success
                      : MintColors.error,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBarRow({
    required String label,
    required double value,
    required double maxValue,
    required Color color,
  }) {
    final fraction = maxValue > 0 ? (value / maxValue).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.textSecondary,
              ),
            ),
            Text(
              OpenBankingService.formatChf(value),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            backgroundColor: MintColors.surface,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ── Top Categories ─────────────────────────────────────────

  Widget _buildTopCategories(List<CategoryBreakdown> categories, S l) {
    final top3 = categories.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.white,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: MintColors.border.withOpacity(0.6), width: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l.openBankingHubTopExpenses,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: MintColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          for (final cat in top3) ...[
            Row(
              children: [
                _categoryIcon(cat.category),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _categoryLabel(cat.category, l),
                    style: GoogleFonts.inter(
                        fontSize: 13, color: MintColors.textPrimary),
                  ),
                ),
                Text(
                  OpenBankingService.formatChf(cat.totalAmount),
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: MintColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: MintColors.surface,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${cat.percentage.toStringAsFixed(0)}\u00a0%',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textMuted,
                    ),
                  ),
                ),
              ],
            ),
            if (cat != top3.last) const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  // ── Quick Link Tile ────────────────────────────────────────

  Widget _buildQuickLinkTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return InkWell(
      onTap: () => context.push(route),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: MintColors.white,
          borderRadius: BorderRadius.circular(16),
          border:
              Border.all(color: MintColors.border.withOpacity(0.5), width: 0.8),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MintColors.accentPastel,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: MintColors.tealLight, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.montserrat(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: MintColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: MintColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: MintColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // ── bLink Badge ────────────────────────────────────────────

  Widget _buildBlinkBadge(S l) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: MintColors.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          l.openBankingHubPoweredByBlink,
          style: GoogleFonts.inter(
            fontSize: 11,
            color: MintColors.textMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── Disclaimer ─────────────────────────────────────────────

  Widget _buildDisclaimer(S l) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: MintColors.warningBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MintColors.orangeRetroWarm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: MintColors.warning, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              l.openBankingHubDisclaimer,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: MintColors.deepOrange,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Category Helpers ───────────────────────────────────────

  Widget _categoryIcon(String category) {
    final (IconData iconData, Color color) = switch (category) {
      'alimentation' => (Icons.shopping_cart, MintColors.warning),
      'transport' => (Icons.directions_bus, MintColors.blueDark),
      'logement' => (Icons.home, MintColors.brownWarm),
      'telecom' => (Icons.phone_android, MintColors.indigoDeep),
      'assurances' => (Icons.health_and_safety, MintColors.tealLight),
      'energie' => (Icons.bolt, MintColors.warningText),
      'sante' => (Icons.local_pharmacy, MintColors.redMedium),
      'loisirs' => (Icons.movie, MintColors.categoryPurple),
      'impots' => (Icons.receipt_long, MintColors.greyDark),
      'epargne' => (Icons.savings, MintColors.success),
      'revenu' => (Icons.account_balance_wallet, MintColors.success),
      _ => (Icons.receipt, MintColors.textMuted),
    };

    return Icon(iconData, size: 18, color: color);
  }

  String _categoryLabel(String category, S l) {
    switch (category) {
      case 'alimentation':
        return l.openBankingHubCatFood;
      case 'transport':
        return l.openBankingHubCatTransport;
      case 'logement':
        return l.openBankingHubCatHousing;
      case 'telecom':
        return l.openBankingHubCatTelecom;
      case 'assurances':
        return l.openBankingHubCatInsurance;
      case 'energie':
        return l.openBankingHubCatEnergy;
      case 'sante':
        return l.openBankingHubCatHealth;
      case 'loisirs':
        return l.openBankingHubCatLeisure;
      case 'impots':
        return l.openBankingHubCatTaxes;
      case 'epargne':
        return l.openBankingHubCatSavings;
      case 'revenu':
        return l.openBankingHubCatIncome;
      default:
        return l.openBankingHubCatOther;
    }
  }
}
